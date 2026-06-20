// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IEquilibriumVault, IStrategyManager} from "./interfaces/IProtocol.sol"; // Import IStrategyManager for self-reference
import {ILiquidityGauge} from "./interfaces/external/ILiquidityGauge.sol"; // Renamed from IYieldBasisStaking
import {IGaugeController} from "./interfaces/external/IGaugeController.sol"; // Renamed from IYieldBasis
import {IChainlinkPriceFeed} from "./interfaces/external/IChainlink.sol";

/**
 * @title StrategyManager
 * @author Equilibrium Protocol
 * @notice The "brain" of the protocol. It calculates the optimal capital allocation
 * between staking (YieldBasis Gauge) and fee accrual (liquid ybBTC) and commands
 * the EquilibriumVault to rebalance accordingly.
 * It accounts for reflexivity by considering its own stake in APY calculations.
 */
contract StrategyManager is Ownable {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    IEquilibriumVault public immutable VAULT;
    ILiquidityGauge public immutable YB_STAKING_GAUGE;
    IGaugeController public immutable YB_GAUGE_CONTROLLER;
    IChainlinkPriceFeed public immutable YB_PRICE_FEED; // For YB token price

    // Data for unstaked fee revenue (e.g., last 7 days)
    uint256[7] public dailyUnstakedFeeRevenue;
    uint256 public feeDataIndex; // Pointer to the current day in the circular buffer
    uint256 public lastFeeDataUpdateTimestamp; // To track when the last daily update was

    // Configurable parameters for tuning the strategy
    uint256 public rebalanceThreshold = 500; // 5% change required to rebalance (scaled by 10000, 1% = 100)
    uint256 public constant ONE_YEAR_IN_SECONDS = 31536000;
    uint256 public constant FEE_HISTORY_WINDOW_DAYS = 7; // Number of days for trailing average

    // Current target allocation set by the manager (0-10000, e.g., 7500 = 75%)
    uint256 public currentStakedAllocation = 0;

    // Honest, owner-set inputs for the staked-APY estimate. These stand in for data that
    // would come from a real YieldBasis integration; until then they are explicit parameters
    // rather than misleading on-chain reads.
    uint256 public ybEmissionRatePerSecond; // YB emitted to this gauge per second
    uint256 public externalGaugeStake; // ybBTC staked in the gauge by everyone except this vault

    // --- Events ---
    event StrategyRebalanced(uint256 newStakedAllocation);
    event FeeDataUpdated(uint256 newFeeAmount);
    event OptimalAllocationFound(uint256 optimalAllocation, uint256 currentStakedApy, uint256 currentUnstakedApy);

    // --- Errors ---
    error InvalidAllocation(int256 newAllocation);
    error ZeroTotalAssets();

    constructor(address _vault, address _ybStakingGauge, address _ybGaugeController, address _ybPriceFeed)
        Ownable(msg.sender)
    {
        VAULT = IEquilibriumVault(_vault);
        YB_STAKING_GAUGE = ILiquidityGauge(_ybStakingGauge);
        YB_GAUGE_CONTROLLER = IGaugeController(_ybGaugeController);
        YB_PRICE_FEED = IChainlinkPriceFeed(_ybPriceFeed);
        lastFeeDataUpdateTimestamp = block.timestamp; // Initialize
    }

    // --- Core Logic ---

    /**
     * @notice Main function called by the HarvestKeeper.
     * It calculates the optimal allocation and rebalances the vault if necessary.
     */
    function switchStrategy() external onlyOwner {
        uint256 totalAssets = VAULT.totalAssets();
        if (totalAssets == 0) revert ZeroTotalAssets();

        // Calculate the optimal allocation based on current market data and reflexivity
        uint256 optimalAllocation = findOptimalAllocation(totalAssets);

        // Get the APYs to include in the event log
        uint256 unstakedApy = getUnstakedAPY();
        uint256 stakedApyAtOptimal = getStakedAPY(externalGaugeStake + (totalAssets * optimalAllocation) / 10000);

        // Check if the change is significant enough to warrant a rebalance
        // currentStakedAllocation is scaled by 10000 (100% = 10000)
        if (
            (optimalAllocation > currentStakedAllocation
                    && optimalAllocation - currentStakedAllocation > rebalanceThreshold)
                || (currentStakedAllocation > optimalAllocation
                    && currentStakedAllocation - optimalAllocation > rebalanceThreshold)
        ) {
            // Calculate the percentage change needed by the vault
            int256 percentageChange = int256(optimalAllocation) - int256(currentStakedAllocation);
            VAULT.rebalance(percentageChange);
            currentStakedAllocation = optimalAllocation; // Update manager's state

            emit StrategyRebalanced(optimalAllocation);
        }

        // Emit the OptimalAllocationFound event here, where it is safe
        emit OptimalAllocationFound(optimalAllocation, stakedApyAtOptimal, unstakedApy);
    }

    /**
     * @notice Calculates the ideal percentage of assets that should be staked to maximize overall APY.
     * This involves an iterative search to find the point where marginal staked APY equals unstaked APY.
     * @param _totalVaultAssets Total ybBTC held by the EquilibriumVault.
     * @return The optimal percentage of assets to stake, scaled by 10000 (e.g., 7500 for 75%).
     */
    function findOptimalAllocation(uint256 _totalVaultAssets) public view returns (uint256) {
        if (_totalVaultAssets == 0) return 0;

        uint256 unstakedApy = getUnstakedAPY();
        // Total staked in the YieldBasis gauge by everyone else *before* our potential stake.
        uint256 totalStakedInGaugeByOthers = externalGaugeStake;

        // Hoist the loop-invariant reads (emission rate + price) out of the loop: getStakedAPY
        // would otherwise re-read the price feed on all 101 iterations. The staked APY for a
        // given total stake is then just yearlyRewardValue * 1e18 / totalStaked.
        uint256 yearlyRewardValue = _yearlyRewardValue();

        uint256 bestAllocation = 0;
        uint256 maxAPY = 0; // Or a very low value

        // Iterate through possible allocations (0% to 100% in 1% increments)
        // A binary search could be more gas efficient for fine-grained search.
        for (uint256 i = 0; i <= 100; i++) {
            uint256 ourHypotheticalStake = (_totalVaultAssets * i) / 100;
            uint256 totalHypotheticalStakeInGauge = totalStakedInGaugeByOthers + ourHypotheticalStake;

            uint256 stakedApy =
                totalHypotheticalStakeInGauge == 0 ? 0 : (yearlyRewardValue * 1e18) / totalHypotheticalStakeInGauge;

            // Calculate the blended APY for the vault's total assets
            uint256 blendedApy =
                ((ourHypotheticalStake * stakedApy) + ((_totalVaultAssets - ourHypotheticalStake) * unstakedApy))
                    / _totalVaultAssets;

            if (blendedApy > maxAPY) {
                maxAPY = blendedApy;
                bestAllocation = i * 100; // Store as 0-10000 scale
            }
        }
        return bestAllocation;
    }

    // --- APY Calculation Helpers ---

    /**
     * @notice Calculates the approximate Annual Percentage Yield (APY) for staking in the YieldBasis gauge.
     * @dev Accounts for dilution by considering the total hypothetical amount staked in the gauge.
     * @param _totalStakedAssets The total amount of ybBTC hypothetically staked in the gauge (including Equilibrium's share).
     * @return The estimated Staked APY, scaled by 1e18 (for precision).
     */
    function getStakedAPY(uint256 _totalStakedAssets) public view returns (uint256) {
        if (_totalStakedAssets == 0) return 0; // Or handle as an error if this state is impossible
        // APY = (Yearly Reward Value / Total Value Staked), scaled by 1e18.
        // ybBTC is assumed to be priced at 1 USD as the APY base.
        return (_yearlyRewardValue() * 1e18) / _totalStakedAssets;
    }

    /// @dev USD value of one year of YB emissions to this gauge, scaled to 1e18.
    /// Reads the owner-set emission rate and the Chainlink YB price exactly once.
    function _yearlyRewardValue() internal view returns (uint256) {
        uint256 emissionsPerYear = ybEmissionRatePerSecond * ONE_YEAR_IN_SECONDS;

        (, int256 price,,,) = YB_PRICE_FEED.latestRoundData();
        require(price > 0, "Strategy: YB Price must be positive");
        uint256 ybPrice = uint256(price) * 1e10; // Chainlink 8 decimals -> 18

        return (emissionsPerYear * ybPrice) / 1e18;
    }

    /**
     * @notice Calculates the approximate Annual Percentage Yield (APY) for holding unstaked ybBTC (from trading fees).
     * @return The estimated Unstaked APY, scaled by 1e18 (for precision).
     */
    function getUnstakedAPY() public view returns (uint256) {
        uint256 totalFeeRevenueInWindow = 0;
        for (uint256 i = 0; i < FEE_HISTORY_WINDOW_DAYS; i++) {
            totalFeeRevenueInWindow += dailyUnstakedFeeRevenue[i];
        }

        // If the fee data is stale, extrapolate or use zero
        // For simplicity, let's just use the current average rate if not updated daily.
        uint256 totalAssets = VAULT.totalAssets();
        if (totalAssets == 0 || totalFeeRevenueInWindow == 0) return 0;

        uint256 averageDailyFees = totalFeeRevenueInWindow / FEE_HISTORY_WINDOW_DAYS;
        uint256 yearlyFees = averageDailyFees * 365;

        // APY = (Yearly Fees / Total Assets) * 100 (scaled by 1e18)
        return (yearlyFees * 1e18) / totalAssets; // Return scaled APY
    }

    // --- Admin Functions ---

    /**
     * @notice Called by the HarvestKeeper to provide new daily fee revenue data for unstaked ybBTC.
     * This is crucial for calculating the unstaked APY.
     * @param _newFeeAmount The amount of ybBTC earned as fees in the last day/period.
     */
    function updateFeeData(uint256 _newFeeAmount) external onlyOwner {
        // Ensure this is called roughly daily
        // require(block.timestamp >= lastFeeDataUpdateTimestamp + 1 days, "Strategy: Not yet time to update fee data");
        dailyUnstakedFeeRevenue[feeDataIndex] = _newFeeAmount;
        feeDataIndex = (feeDataIndex + 1) % FEE_HISTORY_WINDOW_DAYS; // Move to the next day in the circular buffer
        lastFeeDataUpdateTimestamp = block.timestamp;
        emit FeeDataUpdated(_newFeeAmount);
    }

    /**
     * @notice Sets the threshold for how much the optimal allocation must change to trigger a rebalance.
     * @param _newThreshold The new threshold, scaled by 10000 (e.g., 100 = 1%).
     */
    function setRebalanceThreshold(uint256 _newThreshold) external onlyOwner {
        require(_newThreshold <= 10000, "Strategy: Threshold cannot exceed 100%");
        rebalanceThreshold = _newThreshold;
    }

    /// @notice Sets the YB emission rate (per second) used to estimate the staked APY.
    /// @dev Manual input until a real YieldBasis gauge-emissions feed is integrated.
    function setYbEmissionRatePerSecond(uint256 _ratePerSecond) external onlyOwner {
        ybEmissionRatePerSecond = _ratePerSecond;
    }

    /// @notice Sets the amount of ybBTC staked in the gauge by parties other than this vault.
    /// @dev Used to account for reward dilution; manual input until read from the real gauge.
    function setExternalGaugeStake(uint256 _externalStake) external onlyOwner {
        externalGaugeStake = _externalStake;
    }
}
