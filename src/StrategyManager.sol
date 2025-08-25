// src/control/StrategyManager.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IEquilibriumVault} from "./interfaces/IProtocol.sol";
import {IYieldBasisStaking} from "./interfaces/external/IYieldBasisStaking.sol";
import {IYieldBasisGauge} from "./interfaces/external/IYieldBasis.sol";
import {IChainlinkPriceFeed} from "./interfaces/external/IChainlink.sol";

/**
 * @title StrategyManager
 * @author Equilibrium Protocol
 * @notice The "brain" of the protocol. It calculates the optimal capital allocation
 * between staking and fee accrual and commands the EquilibriumVault to rebalance.
 */
contract StrategyManager is Ownable {
    // --- State Variables ---
    IEquilibriumVault public immutable VAULT;
    IYieldBasisStaking public immutable YB_STAKING_POOL;
    IYieldBasisGauge public immutable YB_GAUGE;
    IChainlinkPriceFeed public immutable YB_PRICE_FEED;

    // A rolling window of the last 7 days of unstaked fee revenue
    uint256[7] public dailyFeeRevenue;
    uint256 public feeDataIndex;

    // Configurable parameters for tuning the strategy
    uint256 public rebalanceThreshold = 500; // 5% change required to rebalance (scaled by 10000)
    uint256 public constant ONE_YEAR_IN_SECONDS = 31536000;

    // --- Events ---
    event StrategyRebalanced(uint256 newStakedAllocation);
    event FeeDataUpdated(uint256 newFeeAmount);

    constructor(
        address _vault,
        address _ybStakingPool,
        address _ybGauge,
        address _ybPriceFeed
    ) Ownable(msg.sender) {
        VAULT = IEquilibriumVault(_vault);
        YB_STAKING_POOL = IYieldBasisStaking(_ybStakingPool);
        YB_GAUGE = IYieldBasisGauge(_ybGauge);
        YB_PRICE_FEED = IChainlinkPriceFeed(_ybPriceFeed);
    }

    // --- Core Logic ---

    /**
     * @notice Main function called by the HarvestKeeper.
     * It calculates the optimal allocation and rebalances the vault if necessary.
     */
    function switchStrategy() external onlyOwner {
        (uint256 currentStaked, uint256 currentUnstaked) = VAULT.getAssetBalances(); // Assumes Vault has this new function
        uint256 totalAssets = currentStaked + currentUnstaked;
        if (totalAssets == 0) return;

        uint256 currentAllocation = (currentStaked * 10000) / totalAssets;
        uint256 optimalAllocation = findOptimalAllocation(totalAssets);

        // Check if the change is significant enough to warrant a rebalance
        if ((optimalAllocation > currentAllocation && optimalAllocation - currentAllocation > rebalanceThreshold) ||
            (currentAllocation > optimalAllocation && currentAllocation - optimalAllocation > rebalanceThreshold)) {
            
            VAULT.rebalance(int256(optimalAllocation) - int256(currentAllocation)); // Assumes Vault has a rebalance function
            emit StrategyRebalanced(optimalAllocation);
        }
    }

    /**
     * @notice Calculates the ideal percentage of assets that should be staked.
     */
    function findOptimalAllocation(uint256 _totalAssets) public view returns (uint256) {
        // This is a simplified search. A production version might use a more advanced algorithm.
        // We find the point where the marginal APY of staking equals the APY of not staking.
        uint256 unstakedApy = getUnstakedAPY();
        uint256 totalStakedByOthers = YB_STAKING_POOL.totalSupply() - VAULT.stakedBalance();

        // Iteratively find the equilibrium point (binary search would be more gas efficient)
        for (uint256 i = 0; i <= 100; i++) {
            uint256 ourStake = (_totalAssets * i) / 100;
            uint256 totalHypotheticalStake = totalStakedByOthers + ourStake;
            uint256 stakedApy = getStakedAPY(totalHypotheticalStake);
            if (stakedApy <= unstakedApy) {
                return i * 100; // Return percentage scaled by 10000
            }
        }
        return 10000; // If staking is always better, stake 100%
    }

    // --- APY Calculation Helpers ---

    function getStakedAPY(uint256 _totalStakedAssets) public view returns (uint256) {
        if (_totalStakedAssets == 0) return type(uint256).max;

        // 1. Get YB emission rate from the gauge
        uint256 emissionsPerSecond = YB_GAUGE.inflation_rate();
        uint256 emissionsPerYear = emissionsPerSecond * ONE_YEAR_IN_SECONDS;

        // 2. Get the price of YB from Chainlink
        (, int256 price, , , ) = YB_PRICE_FEED.latestRoundData();
        // Assume price feed has 8 decimals, convert to 18
        uint256 ybPrice = uint256(price) * 1e10; 

        // 3. Calculate total value of yearly emissions
        uint256 yearlyRewardValue = (emissionsPerYear * ybPrice) / 1e18;
        
        // APY = (Yearly Reward Value / Total Value Staked) * 100
        // Assume ybBTC has a price of 1 USD for simplicity
        return (yearlyRewardValue * 100) / _totalStakedAssets;
    }

    function getUnstakedAPY() public view returns (uint256) {
        uint256 totalWeeklyFees = 0;
        for (uint i = 0; i < 7; i++) {
            totalWeeklyFees += dailyFeeRevenue[i];
        }
        uint256 yearlyFees = totalWeeklyFees * 52;
        uint256 totalAssets = VAULT.totalAssets();
        if (totalAssets == 0) return 0;
        // APY = (Yearly Fees / Total Assets) * 100
        return (yearlyFees * 100) / totalAssets;
    }

    // --- Admin Functions ---

    /**
     * @notice Called by the keeper to update the daily fee revenue data.
     */
    function updateFeeData(uint256 _newFeeAmount) external onlyOwner {
        dailyFeeRevenue[feeDataIndex] = _newFeeAmount;
        feeDataIndex = (feeDataIndex + 1) % 7; // Move to the next day, wrapping around
        emit FeeDataUpdated(_newFeeAmount);
    }

    function setRebalanceThreshold(uint256 _newThreshold) external onlyOwner {
        rebalanceThreshold = _newThreshold;
    }
}