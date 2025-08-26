// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {m_ybBTC} from ".//m_ybBTC.sol";
import {ILiquidityGauge} from "./interfaces/external/ILiquidityGauge.sol"; // Use the correct interface

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
    ILiquidityGauge public immutable YB_STAKING_GAUGE; // Renamed to GAUGES for clarity
    
    address public strategyManager;
    uint256 public stakedAllocation; // Current percentage of total assets staked (0-10000)

    // --- Events ---
    event Deposited(address indexed user, uint256 ybBtcAmount, uint256 mYbBtcShares);
    event Withdrawn(address indexed user, uint256 ybBtcAmount, uint256 mYbBtcShares);
    event Rebalanced(uint256 newStakedAllocation);

    constructor(
        address _ybBtcAddress, 
        address _mYbbBtcAddress, 
        address _ybStakingGaugeAddress
    ) Ownable(msg.sender) {
        YB_BTC = IERC20(_ybBtcAddress);
        M_YB_BTC = m_ybBTC(_mYbbBtcAddress);
        YB_STAKING_GAUGE = ILiquidityGauge(_ybStakingGaugeAddress);
    }

    // --- View Functions ---
    function totalAssets() public view returns (uint256) {
        // Total value is liquid ybBTC in this contract + staked in YieldBasis gauge
        uint256 liquidAssets = YB_BTC.balanceOf(address(this));
        uint256 stakedAssets = YB_STAKING_GAUGE.balanceOf(address(this));
        return liquidAssets + stakedAssets;
    }

    function getAssetBalances() public view returns (uint256 staked, uint256 unstaked) {
        staked = YB_STAKING_GAUGE.balanceOf(address(this));
        unstaked = YB_BTC.balanceOf(address(this));
    }

    // --- User-Facing Functions ---
    function deposit(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Vault: Cannot deposit 0");
        uint256 currentTotalAssets = totalAssets();
        uint256 currentTotalShares = M_YB_BTC.totalSupply();
        
        uint256 sharesToMint;
        if (currentTotalShares == 0) {
            sharesToMint = _amount; // First deposit, 1:1
        } else {
            // Mint shares based on current NAV
            sharesToMint = (_amount * currentTotalShares) / currentTotalAssets;
        }

        YB_BTC.safeTransferFrom(msg.sender, address(this), _amount);
        
        // Stake new deposits to match current allocation, if any
        uint256 stakeAmount = (_amount * stakedAllocation) / 10000;
        if (stakeAmount > 0) {
            YB_BTC.approve(address(YB_STAKING_GAUGE), stakeAmount);
            YB_STAKING_GAUGE.deposit(stakeAmount, address(this)); // Deposit to gauge
        }

        M_YB_BTC.mint(msg.sender, sharesToMint);
        emit Deposited(msg.sender, _amount, sharesToMint);
    }

    function withdraw(uint256 _shares) external nonReentrant {
        require(_shares > 0, "Vault: Cannot withdraw 0 shares");
        require(M_YB_BTC.balanceOf(msg.sender) >= _shares, "Vault: Insufficient m_ybBTC shares");

        uint256 currentTotalAssets = totalAssets();
        uint256 currentTotalShares = M_YB_BTC.totalSupply();

        uint256 amountToWithdraw = (_shares * currentTotalAssets) / currentTotalShares;
        require(amountToWithdraw > 0, "Vault: Amount to withdraw is 0");

        // Burn the user's shares. (Requires m_ybBTC to have a burn function in production).
        // For now, we'll just transfer and rely on total supply being reduced by burning.
        M_YB_BTC.transferFrom(msg.sender, address(this), _shares); // Placeholder for burn

        // Fulfill withdrawal by unstaking from gauge if liquid balance is insufficient
        if (YB_BTC.balanceOf(address(this)) < amountToWithdraw) {
            uint256 needed = amountToWithdraw - YB_BTC.balanceOf(address(this));
            YB_STAKING_GAUGE.withdraw(needed, address(this), address(this)); // Withdraw from gauge
        }

        YB_BTC.safeTransfer(msg.sender, amountToWithdraw);
        emit Withdrawn(msg.sender, amountToWithdraw, _shares);
    }

    // --- Strategy Functions (Manager Only) ---
    /**
     * @notice Rebalances the vault's assets between staked and unstaked positions.
     * @dev Only callable by the StrategyManager.
     * @param _percentageChange A signed integer representing the desired change in staked allocation.
     *                          e.g., +500 means increase staked by 5%, -200 means decrease by 2%.
     *                          Scaled by 10000 (100% = 10000).
     */
    function rebalance(int256 _percentageChange) external {
        require(msg.sender == strategyManager, "Vault: Not Strategy Manager");

        int256 newStakedAllocationInt = int256(stakedAllocation) + _percentageChange;
        require(newStakedAllocationInt >= 0 && newStakedAllocationInt <= 10000, "Vault: Invalid allocation");
        
        uint256 newStakedAllocation = uint256(newStakedAllocationInt);
        
        uint256 currentStaked = YB_STAKING_GAUGE.balanceOf(address(this));
        uint256 currentUnstaked = YB_BTC.balanceOf(address(this));
        uint256 total = currentStaked + currentUnstaked;

        uint256 targetStakedAmount = (total * newStakedAllocation) / 10000;

        if (targetStakedAmount > currentStaked) {
            // Need to stake more
            uint256 amountToStake = targetStakedAmount - currentStaked;
            require(currentUnstaked >= amountToStake, "Vault: Not enough liquid to stake");
            YB_BTC.approve(address(YB_STAKING_GAUGE), amountToStake);
            YB_STAKING_GAUGE.deposit(amountToStake, address(this));
        } else if (targetStakedAmount < currentStaked) {
            // Need to unstake some
            uint256 amountToUnstake = currentStaked - targetStakedAmount;
            YB_STAKING_GAUGE.withdraw(amountToUnstake, address(this), address(this)); // Withdraw from gauge
        }

        stakedAllocation = newStakedAllocation;
        emit Rebalanced(newStakedAllocation);
    }
    
    // --- Admin Functions ---
    /**
     * @notice Sets the address of the StrategyManager.
     * @dev Only callable by the owner (the HarvestKeeper).
     */
    function setManager(address _manager) external onlyOwner {
        strategyManager = _manager;
    }
    
    /**
     * @notice Called by the HarvestKeeper to deposit compounded fees from the unstaked strategy.
     * @dev The HarvestKeeper is the owner of this vault.
     * @param _amount The amount of ybBTC fees to compound into the vault.
     */
    function compound(uint256 _amount) external {
        require(msg.sender == owner(), "Vault: Not the owner (keeper)");
        YB_BTC.safeTransferFrom(msg.sender, address(this), _amount);
    }
}