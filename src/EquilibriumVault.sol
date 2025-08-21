// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {m_ybBTC} from "./m_ybBTC.sol";

interface IStakingPool {
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

// THIS VAULT IS NOW DEPOSIT-ONLY. USERS EXIT VIA A SECONDARY LIQUIDITY POOL.
contract EquilibriumVault is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable YB_BTC;
    m_ybBTC public immutable M_YB_BTC;
    address public ybStakingPool;
    address public strategyManager;

    event Deposit(address indexed user, uint256 ybbtcAmount, uint256 mybbtcAmount);
    // --- REMOVED --- event Withdraw(...)
    event StrategyManagerUpdated(address indexed newManager);
    event StakingPoolUpdated(address indexed newPool);
    event Staked(uint256 amount);
    event Unstaked(uint256 amount);

    error NotStrategyManager();
    error ZeroAmount();
    error StakingPoolNotSet();
    // --- REMOVED --- error InsufficientLiquidAssets()

    modifier onlyStrategyManager() {
        if (msg.sender != strategyManager) revert NotStrategyManager();
        _;
    }

    constructor(address ybBtcAddress, address mYbBtcAddress) Ownable(msg.sender) {
        YB_BTC = IERC20(ybBtcAddress);
        M_YB_BTC = m_ybBTC(mYbBtcAddress);
    }

    function totalAssets() public view returns (uint256) {
        uint256 stakedBalance = 0;
        if (ybStakingPool != address(0)) {
            stakedBalance = IStakingPool(ybStakingPool).balanceOf(address(this));
        }
        return YB_BTC.balanceOf(address(this)) + stakedBalance;
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        
        uint256 totalShares = M_YB_BTC.totalSupply();
        uint256 totalVaultAssets = totalAssets();
        uint256 sharesToMint;

        if (totalShares == 0 || totalVaultAssets == 0) {
            sharesToMint = amount;
        } else {
            // As the vault accrues yield, totalVaultAssets will grow larger than totalShares,
            // making each share worth more and thus minting fewer shares for the same deposit amount.
            sharesToMint = (amount * totalShares) / totalVaultAssets;
        }

        if (sharesToMint == 0) revert ZeroAmount(); // Protect against minting 0 shares for tiny deposits
        
        YB_BTC.safeTransferFrom(msg.sender, address(this), amount);
        M_YB_BTC.mint(msg.sender, sharesToMint);
        emit Deposit(msg.sender, amount, sharesToMint);
    }

    // --- REMOVED --- The entire `withdraw` function is gone.
    /*
    function withdraw(uint256 mybbtcAmount) external {
        ...
    }
    */

    // --- STRATEGY MANAGER FUNCTIONS (Unchanged) ---
    // These are still required for the StrategyManager to rebalance assets.

    function _stake(uint256 amount) external onlyStrategyManager {
        if (amount == 0) revert ZeroAmount();
        if (ybStakingPool == address(0)) revert StakingPoolNotSet();
        
        YB_BTC.approve(ybStakingPool, 0);
        YB_BTC.approve(ybStakingPool, amount);
        IStakingPool(ybStakingPool).stake(amount);
        
        emit Staked(amount);
    }

    function _unstake(uint256 amount) external onlyStrategyManager {
        if (amount == 0) revert ZeroAmount();
        if (ybStakingPool == address(0)) revert StakingPoolNotSet();
        
        IStakingPool(ybStakingPool).withdraw(amount);

        emit Unstaked(amount);
    }

    // --- CONFIG FUNCTIONS (Unchanged) ---

    function setStrategyManager(address newManager) external onlyOwner {
        require(newManager != address(0), "Cannot set zero address");
        strategyManager = newManager;
        emit StrategyManagerUpdated(newManager);
    }

    function setStakingPool(address newPool) external onlyOwner {
        require(newPool != address(0), "Cannot set zero address");
        ybStakingPool = newPool;
        emit StakingPoolUpdated(newPool);
    }
}