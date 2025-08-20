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

contract EquilibriumVault is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable YB_BTC;
    m_ybBTC public immutable M_YB_BTC;
    address public ybStakingPool;
    address public strategyManager;
    bool public isStaked;

    event Deposit(address indexed user, uint256 ybbtcAmount, uint256 mybbtcAmount);
    event Withdraw(address indexed user, uint256 ybbtcAmount, uint256 mybbtcAmount);
    event StrategyChanged(bool isStaked);
    event StrategyManagerUpdated(address indexed newManager);
    event StakingPoolUpdated(address indexed newPool);

    error NotStrategyManager();
    error ZeroAmount();
    error AlreadyInState();
    error NotInState();
    error StakingPoolNotSet();

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
        if (totalShares == 0 || totalVaultAssets == 0) { sharesToMint = amount; }
        else { sharesToMint = (amount * totalShares) / totalVaultAssets; }
        if (sharesToMint == 0) revert ZeroAmount();
        YB_BTC.safeTransferFrom(msg.sender, address(this), amount);
        M_YB_BTC.mint(msg.sender, sharesToMint);
        emit Deposit(msg.sender, amount, sharesToMint);
    }

    function withdraw(uint256 mybbtcAmount) external {
        require(!isStaked, "Vault is staked; use DEX for exit");
        if (mybbtcAmount == 0) revert ZeroAmount();
        uint256 totalShares = M_YB_BTC.totalSupply();
        uint256 totalVaultAssets = totalAssets();
        uint256 assetsToReturn = (mybbtcAmount * totalVaultAssets) / totalShares;
        if (assetsToReturn == 0) revert ZeroAmount();
        M_YB_BTC.burnFrom(msg.sender, mybbtcAmount);
        YB_BTC.safeTransfer(msg.sender, assetsToReturn);
        emit Withdraw(msg.sender, assetsToReturn, mybbtcAmount);
    }

    function _stakePool() external onlyStrategyManager {
        if (isStaked) revert AlreadyInState();
        if (ybStakingPool == address(0)) revert StakingPoolNotSet();

        uint256 balance = YB_BTC.balanceOf(address(this));
        if (balance > 0) {
            YB_BTC.approve(ybStakingPool, 0);
            YB_BTC.approve(ybStakingPool, balance);
            IStakingPool(ybStakingPool).stake(balance);
        }

        isStaked = true;
        emit StrategyChanged(true);
    }

    function _unstakePool() external onlyStrategyManager {
        if (!isStaked) revert NotInState();
        if (ybStakingPool == address(0)) revert StakingPoolNotSet();

        uint256 stakedBalance = IStakingPool(ybStakingPool).balanceOf(address(this));
        if (stakedBalance > 0) {
            IStakingPool(ybStakingPool).withdraw(stakedBalance);
        }

        isStaked = false;
        emit StrategyChanged(false);
    }

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