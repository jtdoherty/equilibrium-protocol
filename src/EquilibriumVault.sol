// src/core/EquilibriumVault.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {m_ybBTC} from "./m_ybBTC.sol";
import {IYieldBasisStaking} from "./interfaces/external/IYieldBasisStaking.sol";

/**
 * @title EquilibriumVault
 * @author Equilibrium Protocol
 * @notice The core vault for user deposits of ybBTC. It handles minting/burning of m_ybBTC
 * based on a share price and executes strategy changes commanded by the StrategyManager.
 */
contract EquilibriumVault is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    IERC20 public immutable YB_BTC;
    m_ybBTC public immutable M_YB_BTC;
    IYieldBasisStaking public immutable YB_STAKING_POOL;
    
    address public strategyManager;
    bool public isStaked;

    // --- Events ---
    event Deposited(address indexed user, uint256 ybBtcAmount, uint256 mYbBtcShares);
    event Withdrawn(address indexed user, uint256 ybBtcAmount, uint256 mYbBtcShares);
    event StrategyChanged(bool isStaked);

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
        // The total value is the liquid ybBTC in this contract plus any staked in YieldBasis
        uint256 liquidAssets = YB_BTC.balanceOf(address(this));
        uint256 stakedAssets = YB_STAKING_POOL.balanceOf(address(this));
        return liquidAssets + stakedAssets;
    }

    // --- User-Facing Functions ---
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Vault: Cannot deposit 0");
        uint256 currentTotalAssets = totalAssets();
        uint256 currentTotalShares = M_YB_BTC.totalSupply();
        
        uint256 sharesToMint;
        if (currentTotalShares == 0) {
            sharesToMint = _amount;
        } else {
            sharesToMint = (_amount * currentTotalShares) / currentTotalAssets;
        }

        YB_BTC.safeTransferFrom(msg.sender, address(this), _amount);
        // If the vault is staked, immediately stake the new deposit to match strategy
        if (isStaked) {
            YB_BTC.approve(address(YB_STAKING_POOL), _amount);
            YB_STAKING_POOL.stake(_amount);
        }

        M_YB_BTC.mint(msg.sender, sharesToMint);
        emit Deposited(msg.sender, _amount, sharesToMint);
    }

    function withdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0, "Vault: Cannot withdraw 0");
        uint256 currentTotalAssets = totalAssets();
        uint256 currentTotalShares = M_YB_BTC.totalSupply();

        uint256 amountToWithdraw = (_shares * currentTotalAssets) / currentTotalShares;
        require(amountToWithdraw > 0, "Vault: Amount to withdraw is 0");

        // Burn the user's shares. Requires m_ybBTC to have a burnFrom function.
        // M_YB_BTC.burnFrom(msg.sender, _shares); 

        // Unstake if necessary to fulfill the withdrawal
        if (YB_BTC.balanceOf(address(this)) < amountToWithdraw) {
            uint256 needed = amountToWithdraw - YB_BTC.balanceOf(address(this));
            YB_STAKING_POOL.withdraw(needed);
        }

        YB_BTC.safeTransfer(msg.sender, amountToWithdraw);
        emit Withdrawn(msg.sender, amountToWithdraw, _shares);
    }

    // --- Strategy Functions (Manager Only) ---
    function executeStrategyChange(bool _shouldBeStaked) external {
        require(msg.sender == strategyManager, "Vault: Not the Strategy Manager");
        if (_shouldBeStaked == isStaked) return; // No change needed

        if (_shouldBeStaked) {
            uint256 balance = YB_BTC.balanceOf(address(this));
            if (balance > 0) {
                YB_BTC.approve(address(YB_STAKING_POOL), balance);
                YB_STAKING_POOL.stake(balance);
            }
        } else {
            uint256 stakedBalance = YB_STAKING_POOL.balanceOf(address(this));
            if (stakedBalance > 0) {
                YB_STAKING_POOL.withdraw(stakedBalance);
            }
        }
        isStaked = _shouldBeStaked;
        emit StrategyChanged(isStaked);
    }
    
    // --- Admin Functions ---
    function setManager(address _manager) external onlyOwner {
        strategyManager = _manager;
    }
    
    // Keeper calls this to add compounded fees from unstaked strategy
    function compound(uint256 _amount) external {
        require(msg.sender == owner(), "Vault: Not the owner (keeper)");
        YB_BTC.safeTransferFrom(msg.sender, address(this), _amount);
    }
}