// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// --- REMOVED --- No longer need KeeperCompatibleInterface

// --- INTERFACES (Unchanged) ---
interface IEquilibriumVault {
    function _stake(uint256 amount) external;
    function _unstake(uint256 amount) external;
    function ybStakingPool() external view returns (address);
    function totalAssets() external view returns (uint256);
}

interface IYieldBasisStakingPool {
    function totalAssets() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IYieldBasisRewards {
    function totalYearlyRewards() external view returns (uint256); 
}


contract StrategyManager is Ownable {
    // --- STATE VARIABLES ---
    IEquilibriumVault public vault;
    address public rewardsDataProvider;
    address public keeper; // NEW: Address of the authorized Chainlink contract

    // --- REMOVED --- interval and lastTimeStamp are no longer needed on-chain

    // --- EVENTS ---
    event RebalancePerformed(int256 amountShifted);
    event KeeperUpdated(address indexed newKeeper);

    // --- MODIFIER for Security ---
    modifier onlyKeeper() {
        require(msg.sender == keeper, "StrategyManager: Caller is not the keeper");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor(address _vaultAddress, address _rewardsDataProvider) Ownable(msg.sender) {
        vault = IEquilibriumVault(_vaultAddress);
        rewardsDataProvider = _rewardsDataProvider;
    }

    // --- NEW PUBLIC KEEPER FUNCTION ---

    /**
     * @notice This is the public function that Chainlink Automation will call once per day.
     * It calculates the optimal asset allocation and executes the rebalance.
     * It is protected so only the authorized keeper address can call it.
     */
    function rebalance() external onlyKeeper {
        int256 shiftAmount = _calculateEquilibriumShiftAmount();

        if (shiftAmount > 0) {
            vault._stake(uint256(shiftAmount));
        } else if (shiftAmount < 0) {
            vault._unstake(uint256(-shiftAmount));
        }
        
        emit RebalancePerformed(shiftAmount);
    }
    
    // --- CORE LOGIC (Unchanged from before) ---

    function _calculateEquilibriumShiftAmount() internal view returns (int256) {
        address stakingPoolAddress = vault.ybStakingPool();
        IYieldBasisStakingPool stakingPool = IYieldBasisStakingPool(stakingPoolAddress);
        
        uint256 totalPoolStaked = stakingPool.totalAssets();
        uint256 yearlyRewards = IYieldBasisRewards(rewardsDataProvider).totalYearlyRewards();

        uint256 unstakedApr = getCurrentUnstakedApr();
        if (unstakedApr == 0) {
            uint256 vaultLiquidAssets = vault.totalAssets() - stakingPool.balanceOf(address(vault));
            return int256(vaultLiquidAssets);
        }

        uint256 targetTotalStaked = (yearlyRewards * 10000) / unstakedApr;
        int256 poolDelta = int256(targetTotalStaked) - int256(totalPoolStaked);

        if (poolDelta > 0) {
            uint256 vaultLiquidAssets = vault.totalAssets() - stakingPool.balanceOf(address(vault));
            return uint256(poolDelta) > vaultLiquidAssets ? int256(vaultLiquidAssets) : poolDelta;
        } else {
            uint256 vaultStakedBalance = stakingPool.balanceOf(address(vault));
            return uint256(-poolDelta) > vaultStakedBalance ? -int256(vaultStakedBalance) : poolDelta;
        }
    }

    // --- APR CALCULATION (Unchanged) ---

    function getCurrentStakedApr() public view returns (uint256) {
        // ... implementation remains the same
    }

    function getCurrentUnstakedApr() public view returns (uint256) {
        // ... implementation remains the same
    }

    // --- OWNER FUNCTION to set the keeper ---

    /**
     * @notice Sets the authorized address that can call the rebalance function.
     * @param _newKeeper The address of the Chainlink CronUpkeep contract.
     */
    function setKeeper(address _newKeeper) external onlyOwner {
        keeper = _newKeeper;
        emit KeeperUpdated(_newKeeper);
    }
}