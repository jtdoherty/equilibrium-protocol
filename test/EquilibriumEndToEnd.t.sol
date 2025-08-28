// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";
import {MockChainlinkAggregator} from "src/mocks/MockChainlinkAggregator.sol";
import {MockVotingEscrow} from "src/mocks/MockVotingEscrow.sol";
import {MockGaugeController} from "src/mocks/MockGaugeController.sol";
import {MockLiquidityGauge} from "src/mocks/MockLiquidityGauge.sol";

import {m_ybBTC} from "src/m_ybBTC.sol";
import {m_YB} from "src/m_YB.sol";
import {EQM} from "src/EQM.sol";
import {EquilibriumVault} from "src/EquilibriumVault.sol";
import {YBLocker} from "src/YBLocker.sol";
import {RewardDistributor} from "src/RewardDistributor.sol";
import {Booster} from "src/Booster.sol";
import {StrategyManager} from "src/StrategyManager.sol";
import {HarvestKeeper} from "src/HarvestKeeper.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol"; // Added this import

contract EquilibriumEndToEndTest is Test {
    // --- User and Keeper Addresses ---
    address public deployer;
    address public alice; // Regular user
    address public bob;   // Another regular user

    // --- Mock Contracts ---
    MockERC20 public ybBTC_mock;
    MockERC20 public YB_mock;
    MockChainlinkAggregator public ybPriceFeed_mock;
    MockVotingEscrow public ybVotingEscrow_mock;
    MockGaugeController public ybGaugeController_mock;
    MockLiquidityGauge public ybStakingGauge_mock;

    // --- Equilibrium Protocol Contracts ---
    m_ybBTC public m_ybBTC_token;
    m_YB public m_YB_token;
    EQM public EQM_token;
    EquilibriumVault public equilibriumVault;
    YBLocker public ybLocker;
    RewardDistributor public rewardDistributor;
    Booster public booster;
    StrategyManager public strategyManager;
    HarvestKeeper public harvestKeeper;

    // --- Constants ---
    uint256 public constant INITIAL_YB_BTC_DEPOSIT = 1_000 ether; // 1,000 ybBTC
    uint256 public constant KEEPER_INTERVAL = 1 hours;           // HarvestKeeper interval

    function setUp() public {
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.startPrank(deployer);

        // 1. Deploy Mock Contracts
        ybBTC_mock = new MockERC20("YieldBasis BTC", "ybBTC");
        YB_mock = new MockERC20("YieldBasis Token", "YB");
        ybPriceFeed_mock = new MockChainlinkAggregator(8, 10 * 1e8); 

        ybVotingEscrow_mock = new MockVotingEscrow(address(YB_mock));
        ybGaugeController_mock = new MockGaugeController(address(YB_mock));
        ybStakingGauge_mock = new MockLiquidityGauge(address(ybBTC_mock), address(YB_mock));

        // 2. Deploy Equilibrium Tokens (with deployer as initial owner, ownership will be transferred later)
        m_ybBTC_token = new m_ybBTC(deployer);
        m_YB_token = new m_YB(deployer);
        EQM_token = new EQM(deployer); 

        // 3. Deploy Core Equilibrium Contracts with deployer as initial owner
        rewardDistributor = new RewardDistributor(address(EQM_token));
        ybLocker = new YBLocker(address(YB_mock), address(ybVotingEscrow_mock), address(m_YB_token));
        booster = new Booster(address(m_ybBTC_token), address(EQM_token));
        equilibriumVault = new EquilibriumVault(address(ybBTC_mock), address(m_ybBTC_token), address(ybStakingGauge_mock));
        strategyManager = new StrategyManager(
            address(equilibriumVault),
            address(ybStakingGauge_mock),
            address(ybGaugeController_mock),
            address(ybPriceFeed_mock)
        );

        // 4. Deploy HarvestKeeper (this contract will own many others)
        harvestKeeper = new HarvestKeeper(
            address(YB_mock),
            address(ybBTC_mock),
            address(ybStakingGauge_mock),
            address(equilibriumVault),
            address(ybLocker),
            address(rewardDistributor),
            address(strategyManager),
            KEEPER_INTERVAL
        );

        // --- Post-Deployment Configuration & Ownership Transfers ---
        // Transfer ownership of m_ybBTC to EquilibriumVault so it can mint
        m_ybBTC_token.transferOwnership(address(equilibriumVault));
        // Transfer ownership of m_YB to YBLocker so it can mint
        m_YB_token.transferOwnership(address(ybLocker));
        // Transfer ownership of EQM_token to RewardDistributor so it can mint
        EQM_token.transferOwnership(address(rewardDistributor));

        // Transfer ownership of relevant contracts to HarvestKeeper
        equilibriumVault.transferOwnership(address(harvestKeeper));
        ybLocker.transferOwnership(address(harvestKeeper));
        rewardDistributor.transferOwnership(address(harvestKeeper));
        strategyManager.transferOwnership(address(harvestKeeper));
        // Booster owned by RewardDistributor as it calls notifyRewardAmount
        booster.transferOwnership(address(rewardDistributor)); 

        // Now, deployer is done with mass transfers. Stop prank and let HarvestKeeper or RewardDistributor act.
        vm.stopPrank();

        // HarvestKeeper sets its owned contracts' configurations
        vm.startPrank(address(harvestKeeper));
        equilibriumVault.setManager(address(strategyManager));
        rewardDistributor.setBooster(address(booster));
        vm.stopPrank();

        // Fund users with ybBTC
        vm.startPrank(deployer); 
        ybBTC_mock.mint(alice, INITIAL_YB_BTC_DEPOSIT);
        ybBTC_mock.mint(bob, INITIAL_YB_BTC_DEPOSIT);
        vm.stopPrank();
    }

    // --- Start of End-to-End Test Cases ---

    function testUserDepositAndWithdraw() public {
        vm.startPrank(alice);
        ybBTC_mock.approve(address(equilibriumVault), INITIAL_YB_BTC_DEPOSIT);
        equilibriumVault.deposit(INITIAL_YB_BTC_DEPOSIT);
        vm.stopPrank();

        assertEq(ybBTC_mock.balanceOf(address(equilibriumVault)), INITIAL_YB_BTC_DEPOSIT, "Vault should hold ybBTC");
        assertEq(m_ybBTC_token.balanceOf(alice), INITIAL_YB_BTC_DEPOSIT, "Alice should receive m_ybBTC");
        assertEq(equilibriumVault.totalAssets(), INITIAL_YB_BTC_DEPOSIT, "Vault total assets incorrect after deposit");

        vm.startPrank(alice);
        m_ybBTC_token.approve(address(equilibriumVault), INITIAL_YB_BTC_DEPOSIT); // Approve burn
        equilibriumVault.withdraw(INITIAL_YB_BTC_DEPOSIT);
        vm.stopPrank();

        assertEq(ybBTC_mock.balanceOf(alice), INITIAL_YB_BTC_DEPOSIT, "Alice should have ybBTC back");
        assertEq(m_ybBTC_token.balanceOf(alice), 0, "Alice should have 0 m_ybBTC");
        assertEq(ybBTC_mock.balanceOf(address(equilibriumVault)), 0, "Vault should have 0 ybBTC");
        assertEq(equilibriumVault.totalAssets(), 0, "Vault total assets incorrect after withdrawal");
    }

    function testFullHarvestAndStrategySwitch() public {
        // 1. User Deposits
        vm.startPrank(alice);
        ybBTC_mock.approve(address(equilibriumVault), INITIAL_YB_BTC_DEPOSIT);
        equilibriumVault.deposit(INITIAL_YB_BTC_DEPOSIT);
        vm.stopPrank();

        // Ensure vault is initially unstaked (default)
        assertEq(equilibriumVault.stakedAllocation(), 0, "Vault should start with 0% staked");

        // Simulate some initial unstaked yield data
        uint256 simulatedDailyFee = 100 ether;
        vm.startPrank(deployer);
        ybBTC_mock.mint(deployer, simulatedDailyFee); 
        ybBTC_mock.approve(address(harvestKeeper), simulatedDailyFee); 
        harvestKeeper.addHarvestableBtcFees(simulatedDailyFee); 
        vm.stopPrank();
        
        // Ensure YB is available in the gauge for HarvestKeeper to claim
        uint256 simulatedYBEmissionForGauge = 50 ether; // YB for the gauge
        vm.startPrank(deployer);
        YB_mock.mint(address(ybStakingGauge_mock), simulatedYBEmissionForGauge); // Mint YB to the gauge itself
        ybStakingGauge_mock.setRewards(address(harvestKeeper), simulatedYBEmissionForGauge); // Set rewards for HarvestKeeper
        vm.stopPrank();


        vm.warp(block.timestamp + 1 days); // Advance time for fee data
        vm.prank(address(harvestKeeper));
        harvestKeeper.performUpkeep(""); // This will call updateFeeData and claim YB

        // Strategy 1: Staking APY is lower, expect to remain unstaked or less staked
        uint256 unstakedAPY_scenario1 = 10_000; // 10%
        uint256 stakedAPY_scenario1 = 5_000;    // 5%

        vm.mockCall(address(strategyManager), abi.encodeWithSelector(strategyManager.getUnstakedAPY.selector), abi.encode(unstakedAPY_scenario1));
        vm.mockCall(address(strategyManager), abi.encodeWithSelector(strategyManager.getStakedAPY.selector), abi.encode(stakedAPY_scenario1));

        uint256 currentStakedAllocationBefore1 = equilibriumVault.stakedAllocation();
        vm.warp(block.timestamp + KEEPER_INTERVAL + 1); 
        vm.prank(address(harvestKeeper));
        harvestKeeper.performUpkeep(""); // Should not switch to staked or only minimally

        // Assert that staked allocation does not increase significantly or stays the same
        assertLe(equilibriumVault.stakedAllocation(), currentStakedAllocationBefore1, "Vault should not have staked more if unstaked APY is higher");

        // Strategy 2: Staking APY is higher, expect a switch to staked
        uint256 unstakedAPY_scenario2 = 5_000;   // 5%
        uint256 stakedAPY_scenario2 = 10_000;   // 10%

        vm.mockCall(address(strategyManager), abi.encodeWithSelector(strategyManager.getUnstakedAPY.selector), abi.encode(unstakedAPY_scenario2));
        vm.mockCall(address(strategyManager), abi.encodeWithSelector(strategyManager.getStakedAPY.selector), abi.encode(stakedAPY_scenario2));

        uint256 currentStakedAllocationBefore2 = equilibriumVault.stakedAllocation();
        vm.warp(block.timestamp + KEEPER_INTERVAL + 1); 
        vm.prank(address(harvestKeeper));
        harvestKeeper.performUpkeep(""); // Should switch to staked

        // Assert that the strategy has switched to stake some assets
        assertGt(equilibriumVault.stakedAllocation(), currentStakedAllocationBefore2, "Vault should have rebalanced to stake more assets");
        assertEq(uint256(equilibriumVault.currentStrategy()), uint256(EquilibriumVault.Strategy.Staked), "Vault strategy should be Staked");

        // Strategy 3: Staking APY is lower again, expect a switch back to unstaked
        uint256 unstakedAPY_scenario3 = 12_000; // 12%
        uint256 stakedAPY_scenario3 = 8_000;    // 8%

        vm.mockCall(address(strategyManager), abi.encodeWithSelector(strategyManager.getUnstakedAPY.selector), abi.encode(unstakedAPY_scenario3));
        vm.mockCall(address(strategyManager), abi.encodeWithSelector(strategyManager.getStakedAPY.selector), abi.encode(stakedAPY_scenario3));

        uint256 currentStakedAllocationBefore3 = equilibriumVault.stakedAllocation();
        vm.warp(block.timestamp + KEEPER_INTERVAL + 1); 
        vm.prank(address(harvestKeeper));
        harvestKeeper.performUpkeep(""); // Should switch back to unstaked (or reduce staked allocation)

        // Assert that the strategy has switched back to unstaked or reduced staked allocation
        assertLe(equilibriumVault.stakedAllocation(), currentStakedAllocationBefore3, "Vault should have rebalanced to unstake assets");
        assertEq(uint256(equilibriumVault.currentStrategy()), uint256(EquilibriumVault.Strategy.Unstaked), "Vault strategy should be Unstaked");
    }
    function testHarvestKeeperSendsMYBToRewardDistributor() public {
        uint256 simulatedYBEmission = 500 ether; // More YB for clearer testing

        // Add user deposit to ensure the vault has assets, avoiding ZeroTotalAssets() revert
        vm.startPrank(alice);
        ybBTC_mock.approve(address(equilibriumVault), INITIAL_YB_BTC_DEPOSIT);
        equilibriumVault.deposit(INITIAL_YB_BTC_DEPOSIT);
        vm.stopPrank();

        // Ensure YB is available in the gauge for HarvestKeeper to claim
        vm.startPrank(deployer);
        YB_mock.mint(address(ybStakingGauge_mock), simulatedYBEmission); // Mint YB to the gauge
        ybStakingGauge_mock.setRewards(address(harvestKeeper), simulatedYBEmission); // Set rewards for HarvestKeeper to claim
        vm.stopPrank();

        uint256 initialMYBRewardDistributor = m_YB_token.balanceOf(address(rewardDistributor));
        uint256 initialEQMBooster = EQM_token.balanceOf(address(booster));

        vm.warp(block.timestamp + KEEPER_INTERVAL + 1); // Advance time for upkeep

        vm.prank(address(harvestKeeper));
        harvestKeeper.performUpkeep("");

        // Assert YB is transferred from HarvestKeeper to YBLocker
        assertEq(YB_mock.balanceOf(address(harvestKeeper)), 0, "HarvestKeeper should have transferred YB");
        assertEq(YB_mock.balanceOf(address(ybLocker)), simulatedYBEmission, "YBLocker should have received YB");

        // Assert YB is locked in VotingEscrow
        assertGt(ybVotingEscrow_mock.balanceOf(address(ybLocker)), 0, "YB Locker should have locked YB in VotingEscrow");

        // Assert m_YB is minted to HarvestKeeper then sent to RewardDistributor
        assertEq(m_YB_token.balanceOf(address(harvestKeeper)), 0, "HarvestKeeper should have transferred m_YB");
        assertEq(m_YB_token.balanceOf(address(rewardDistributor)), initialMYBRewardDistributor + simulatedYBEmission, "RewardDistributor should have received m_YB");

        // Assert RewardDistributor mints EQM to Booster
        assertGt(EQM_token.balanceOf(address(booster)), initialEQMBooster, "Booster should have received EQM rewards from RewardDistributor");
    }

    function testHarvestKeeperAccessControl() public {
        // These functions should only be callable by the owner (deployer initially, then HarvestKeeper itself)
        // After setUp, HarvestKeeper owns many contracts, so it will be the privileged caller.
        // We'll test direct calls from an unauthorized user.

        address unauthorized = alice; 

        // Test setBooster in RewardDistributor (owned by HarvestKeeper)
        vm.startPrank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        rewardDistributor.setBooster(address(bob));
        vm.stopPrank();

        // Test setManager in EquilibriumVault (owned by HarvestKeeper)
        vm.startPrank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        equilibriumVault.setManager(address(bob));
        vm.stopPrank();

        // Test setBooster in Booster (owned by RewardDistributor, which is owned by HarvestKeeper) - this is a nested ownership scenario
        // In setup, booster.transferOwnership(address(rewardDistributor)); 
        // So unauthorized should not be able to call notifyRewardAmount from Booster
        vm.startPrank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        booster.notifyRewardAmount(1 ether, 7 days); // Using dummy values for testing unauthorized access
        vm.stopPrank();

        // Test transferOwnership on m_ybBTC (owned by EquilibriumVault, which is owned by HarvestKeeper)
        vm.startPrank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        m_ybBTC_token.transferOwnership(address(bob));
        vm.stopPrank();

        // Test transferOwnership on YBLocker (owned by HarvestKeeper)
        vm.startPrank(unauthorized);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, unauthorized));
        ybLocker.transferOwnership(address(bob));
        vm.stopPrank();

        // Verify HarvestKeeper can call its own functions that require ownership
        vm.startPrank(address(harvestKeeper));
        rewardDistributor.setBooster(address(booster)); // This should succeed
        equilibriumVault.setManager(address(strategyManager)); // This should succeed
        // Assuming there's a setter for KEEPER_INTERVAL or similar in HarvestKeeper itself
        // For example: harvestKeeper.setKeeperInterval(2 hours); // Should succeed
        vm.stopPrank();
    }
}
