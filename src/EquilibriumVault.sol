// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {m_ybBTC} from "../token/m_ybBTC.sol";

// Create this interface based on the REAL YieldBasis staking contract
interface IYieldBasisStaking {
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
}

contract EquilibriumVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable YB_BTC;
    m_ybBTC public immutable M_YB_BTC;
    IYieldBasisStaking public immutable YB_STAKING_POOL;
    address public strategyManager;
    bool public isStaked;

    event Deposited(address indexed user, uint256 amount, uint256 shares);
    event Withdrawn(address indexed user, uint256 amount, uint256 shares);

    constructor(
        address _ybBtcAddress, 
        address _mYbbBtcAddress, 
        address _ybStakingPoolAddress
    ) Ownable(msg.sender) {
        YB_BTC = IERC20(_ybBtcAddress);
        M_YB_BTC = m_ybBTC(_mYbbBtcAddress);
        YB_STAKING_POOL = IYieldBasisStaking(_ybStakingPoolAddress);
    }

    // --- View Functions ---
    function totalAssets() public view returns (uint256) {
        return YB_BTC.balanceOf(address(this));
    }

    // --- User-Facing Functions ---
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot deposit 0");
        uint256 shares;
        if (M_YB_BTC.totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * M_YB_BTC.totalSupply()) / totalAssets();
        }
        YB_BTC.safeTransferFrom(msg.sender, address(this), _amount);
        M_YB_BTC.mint(msg.sender, shares);
        emit Deposited(msg.sender, _amount, shares);
    }

    function withdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0, "Cannot withdraw 0");
        uint256 amount = (_shares * totalAssets()) / M_YB_BTC.totalSupply();
        // This is a simplified withdraw; a real one needs to burn the shares.
        // For now, this demonstrates the share calculation.
        M_YB_BTC.transferFrom(msg.sender, address(this), _shares); // Placeholder for burn
        YB_BTC.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount, _shares);
    }

    // --- Strategy Functions (Manager Only) ---
    function _stakePool() internal {
        uint256 balance = totalAssets();
        if (balance > 0) {
            YB_BTC.approve(address(YB_STAKING_POOL), balance);
            YB_STAKING_POOL.stake(balance);
            isStaked = true;
        }
    }

    function _unstakePool() internal {
        // You'll need to find the function in YieldBasis that returns the staked balance
        uint256 stakedBalance = 0; // Replace with call to YieldBasis contract
        if (stakedBalance > 0) {
            YB_STAKING_POOL.withdraw(stakedBalance);
            isStaked = false;
        }
    }

    // --- Admin Functions ---
    function setManager(address _manager) external onlyOwner {
        strategyManager = _manager;
    }
    
    // Keeper calls this to add compounded fees
    function compound(uint256 _amount) external {
        require(msg.sender == owner(), "Only owner"); // Owner is the keeper
        YB_BTC.safeTransferFrom(msg.sender, address(this), _amount);
    }
}