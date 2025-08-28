// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol"; // Import console for logging
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockLiquidityGauge} from "../src/mocks/MockLiquidityGauge.sol";
import {MockChainlinkAggregator} from "../src/mocks/MockChainlinkAggregator.sol";
import {MockGaugeController} from "../src/mocks/MockGaugeController.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {StrategyManager} from "../src/StrategyManager.sol";
import {IEquilibriumVault} from "../src/interfaces/IProtocol.sol";
import {ILiquidityGauge} from "../src/interfaces/external/ILiquidityGauge.sol";
import {IChainlinkPriceFeed} from "../src/interfaces/external/IChainlink.sol";

contract StrategyManagerTest is Test {
    MockERC20 public ybBTC;
    MockERC20 public YB_TOKEN; // Mock for YB token
    m_ybBTC public mYBBTC; // Not directly used by StrategyManager, but needed for Vault mock
    MockLiquidityGauge public ybStakingGauge;
    MockChainlinkAggregator public ybPriceFeed;
    MockGaugeController public ybGaugeController; // Declared MockGaugeController
    StrategyManager public strategyManager;
    // Using the real EquilibriumVault here to simplify testing, but we'll need to mock its behavior
    // or carefully control its state for StrategyManager interactions.
    EquilibriumVault public vault;

    address public deployer;
    address public user;

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");

        // Deploy Mock tokens
        ybBTC = new MockERC20("YieldBasis BTC", "ybBTC");
        YB_TOKEN = new MockERC20("YieldBasis Token", "YB");
        
        // Deploy Mock Liquidity Gauge (stakingToken: ybBTC, rewardToken: YB_TOKEN)
        ybStakingGauge = new MockLiquidityGauge(address(ybBTC), address(YB_TOKEN));

        // Deploy m_ybBTC token with deployer as initial owner
        mYBBTC = new m_ybBTC(deployer);

        // Deploy Mock Chainlink Aggregator (YB Price Feed)
        ybPriceFeed = new MockChainlinkAggregator(8, 1e8); // 8 decimals, initial price 1 USD (1e8)

        // Deploy Mock Gauge Controller
        ybGaugeController = new MockGaugeController(address(YB_TOKEN));

        // Set deployer as the sender for deploying vault and setting manager
        vm.startPrank(deployer);

        // Deploy the vault
        vault = new EquilibriumVault(address(ybBTC), address(mYBBTC), address(ybStakingGauge));

        // Deploy StrategyManager
        strategyManager = new StrategyManager(
            address(vault),
            address(ybStakingGauge),
            address(ybGaugeController),
            address(ybPriceFeed)
        );

        // Transfer ownership of mYBBTC to the vault
        mYBBTC.transferOwnership(address(vault));
        // Set the StrategyManager in the Vault
        vault.setManager(address(strategyManager));
        // Make deployer the owner of StrategyManager initially for testing admin functions
        strategyManager.transferOwnership(address(deployer));
        vm.stopPrank();

        // Mint some ybBTC for the user for deposits
        ybBTC.mint(user, 1000e18);

        // Mint some YB tokens to the gauge so it can distribute rewards (for staked APY calc)
        YB_TOKEN.mint(address(ybStakingGauge), 1000e18);
    }

    function testGetUnstakedAPY() public {
        // Simulate fee data updates over a few days
        uint256 fee1 = 10e18; // 10 ybBTC fees
        uint256 fee2 = 15e18;
        uint256 fee3 = 20e18;

        // Deposit some funds into the vault to have totalAssets > 0
        vm.startPrank(user);
        ybBTC.approve(address(vault), 100e18);
        vault.deposit(100e18);
        vm.stopPrank();

        vm.startPrank(deployer); // StrategyManager owner
        strategyManager.updateFeeData(fee1);
        skip(1 days); // Simulate day passing
        strategyManager.updateFeeData(fee2);
        skip(1 days);
        strategyManager.updateFeeData(fee3);
        skip(1 days);
        vm.stopPrank();

        // Corrected calculation for expected average daily fees:
        // Sum of fees collected / FEE_HISTORY_WINDOW_DAYS (which is 7 in StrategyManager)
        uint256 totalFeeRevenueProvided = fee1 + fee2 + fee3;
        uint256 expectedAverageDailyFees = totalFeeRevenueProvided / strategyManager.FEE_HISTORY_WINDOW_DAYS();
        uint256 expectedYearlyFees = expectedAverageDailyFees * 365;
        uint256 totalVaultAssets = vault.totalAssets();

        uint256 expectedUnstakedAPY = (expectedYearlyFees * 1e18) / totalVaultAssets;

        uint256 actualUnstakedAPY = strategyManager.getUnstakedAPY();

        // Allow for some minor deviation due to integer division, if necessary
        assertApproxEqAbs(actualUnstakedAPY, expectedUnstakedAPY, 1e16, "Unstaked APY incorrect");
    }

    function testGetStakedAPY() public {
        // Need to set up state for Staked APY calculation
        
        // 1. Mock YB emissions from YB_GAUGE_CONTROLLER (YB_TOKEN balance within it)
        // The StrategyManager uses YB_GAUGE_CONTROLLER.TOKEN().balanceOf(address(YB_GAUGE_CONTROLLER))
        // as a placeholder for global YB inflation rate. So mint YB to ybGaugeController.
        uint256 globalYBInflationRate = 1000e18; // Mock value for YB emissions per second
        YB_TOKEN.mint(address(ybGaugeController), globalYBInflationRate); // Mint YB to gauge controller

        // 2. YB Price Feed is already set up in setUp
        // YB_PRICE_FEED has price of 1e8 (1 USD with 8 decimals)

        // 3. Simulate total staked assets in gauge
        uint256 hypotheticalStakedAssets = 500e18; // 500 ybBTC staked
        
        // Deposit some funds into the vault to have totalAssets > 0
        vm.startPrank(user);
        ybBTC.approve(address(vault), 100e18);
        vault.deposit(100e18);
        vm.stopPrank();

        // Calculate expected staked APY
        // emissionsPerYear = globalYBInflationRate * ONE_YEAR_IN_SECONDS (31536000)
        // ybPrice = 1e8 (from MockChainlinkAggregator) converted to 1e18 for calculations (1e10 multiplier in contract)
        // yearlyRewardValue = (emissionsPerYear * ybPrice) / 1e18
        // APY = (yearlyRewardValue * 1e18) / hypotheticalStakedAssets

        uint256 ONE_YEAR_IN_SECONDS = 31536000;
        uint256 emissionsPerYear = globalYBInflationRate * ONE_YEAR_IN_SECONDS;
        uint256 ybPriceScaled = 1e8 * 1e10; // 1 USD with 18 decimals
        uint256 yearlyRewardValue = (emissionsPerYear * ybPriceScaled) / 1e18;

        uint256 expectedStakedAPY = (yearlyRewardValue * 1e18) / hypotheticalStakedAssets;

        uint256 actualStakedAPY = strategyManager.getStakedAPY(hypotheticalStakedAssets);

        assertApproxEqAbs(actualStakedAPY, expectedStakedAPY, 1e16, "Staked APY incorrect");
    }

    function testSwitchStrategyRebalance() public {
        // Initialize vault with some assets
        vm.startPrank(user);
        ybBTC.approve(address(vault), 100e18);
        vault.deposit(100e18);
        vm.stopPrank();

        // Set a low rebalance threshold to easily trigger a rebalance
        vm.startPrank(deployer); // StrategyManager owner
        strategyManager.setRebalanceThreshold(1); // 0.01% threshold

        // Manipulate APYs to force a strategy switch
        // Make unstaked APY very high initially
        strategyManager.updateFeeData(1000e18); // High fees for unstaked
        skip(1 days);
        strategyManager.updateFeeData(1000e18);
        skip(1 days);
        strategyManager.updateFeeData(1000e18);
        skip(1 days);

        // Set YB emissions high for staked APY
        uint256 globalYBInflationRate = 5000e18; 
        YB_TOKEN.mint(address(ybGaugeController), globalYBInflationRate); // Mock gauge controller token balance
        ybPriceFeed.updateAnswer(2e8); // YB price to 2 USD

        // Console logs for debugging
        console.log("Initial currentStakedAllocation:", strategyManager.currentStakedAllocation());
        console.log("Rebalance Threshold:", strategyManager.rebalanceThreshold());

        uint256 currentTotalAssets = vault.totalAssets();
        uint256 optimalAllocation = strategyManager.findOptimalAllocation(currentTotalAssets);
        console.log("Calculated Optimal Allocation:", optimalAllocation);
        console.log("Unstaked APY:", strategyManager.getUnstakedAPY());
        console.log("Staked APY (at optimal):", strategyManager.getStakedAPY(currentTotalAssets * optimalAllocation / 10000));

        // Calculate the expected percentageChange that StrategyManager will pass to vault.rebalance
        int256 expectedPercentageChange = int256(optimalAllocation) - int256(strategyManager.currentStakedAllocation());

        // Expect a call to rebalance on the vault with the exact calculated argument
        vm.expectCall(
            address(vault),
            abi.encodeWithSelector(IEquilibriumVault.rebalance.selector, expectedPercentageChange)
        );
        strategyManager.switchStrategy();

        // Assert that the staked allocation has changed
        assertEq(strategyManager.currentStakedAllocation(), optimalAllocation, "StrategyManager's staked allocation should match optimal");
        vm.stopPrank();
    }
}
