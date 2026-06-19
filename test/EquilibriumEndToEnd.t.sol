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

    // Mint YB into the gauge and mark it claimable by the keeper, simulating a
    // period's worth of emissions. performUpkeep requires claimedYB > 0, so this
    // must be called before each upkeep cycle.
    function _seedGaugeYB(uint256 amount) internal {
        vm.startPrank(deployer);
        YB_mock.mint(address(ybStakingGauge_mock), amount);
        ybStakingGauge_mock.setRewards(address(harvestKeeper), amount);
        vm.stopPrank();
    }

    // Move time just past the keeper's interval so the next performUpkeep runs.
    // Derived from lastUpdateTime so it is robust to whatever the current timestamp is.
    function _advancePastInterval() internal {
        vm.warp(harvestKeeper.lastUpdateTime() + harvestKeeper.interval() + 1);
    }

    // --- Start of End-to-End Test Cases ---

    function testUserDepositAndWithdraw() public {
        vm.startPrank(alice);
        ybBTC_mock.approve(address(equilibriumVault), INITIAL_YB_BTC_DEPOSIT);
        equilibriumVault.deposit(INITIAL_YB_BTC_DEPOSIT);
        vm.stopPrank();

        uint256 minLiquidity = equilibriumVault.MINIMUM_LIQUIDITY();
        uint256 aliceShares = m_ybBTC_token.balanceOf(alice);
        assertEq(ybBTC_mock.balanceOf(address(equilibriumVault)), INITIAL_YB_BTC_DEPOSIT, "Vault should hold ybBTC");
        assertEq(aliceShares, INITIAL_YB_BTC_DEPOSIT - minLiquidity, "Alice should receive m_ybBTC minus locked minimum");
        assertEq(equilibriumVault.totalAssets(), INITIAL_YB_BTC_DEPOSIT, "Vault total assets incorrect after deposit");

        vm.startPrank(alice);
        m_ybBTC_token.approve(address(equilibriumVault), aliceShares); // Approve burn
        equilibriumVault.withdraw(aliceShares);
        vm.stopPrank();

        // Alice gets back her deposit minus the permanently-locked minimum, which stays in the vault.
        assertEq(ybBTC_mock.balanceOf(alice), INITIAL_YB_BTC_DEPOSIT - minLiquidity, "Alice should have ybBTC back");
        assertEq(m_ybBTC_token.balanceOf(alice), 0, "Alice should have 0 m_ybBTC");
        assertEq(ybBTC_mock.balanceOf(address(equilibriumVault)), minLiquidity, "Vault retains the locked minimum backing");
        assertEq(equilibriumVault.totalAssets(), minLiquidity, "Vault total assets should equal the locked minimum");
    }

    function testFullHarvestAndStrategySwitch() public {
        // 1. User deposits; vault starts fully unstaked.
        vm.startPrank(alice);
        ybBTC_mock.approve(address(equilibriumVault), INITIAL_YB_BTC_DEPOSIT);
        equilibriumVault.deposit(INITIAL_YB_BTC_DEPOSIT);
        vm.stopPrank();
        assertEq(equilibriumVault.stakedAllocation(), 0, "Vault should start with 0% staked");

        // Low threshold so any change in the optimal allocation triggers a rebalance.
        // The HarvestKeeper owns the StrategyManager, so it is the privileged caller.
        vm.prank(address(harvestKeeper));
        strategyManager.setRebalanceThreshold(1);

        // --- Scenario 1: staking is clearly more profitable -> vault should stake ---
        // Drive the staked-APY inputs (emission rate + YB price) up. No fee data is set, so
        // getUnstakedAPY is 0 and staking wins.
        vm.prank(address(harvestKeeper));
        strategyManager.setYbEmissionRatePerSecond(5_000 ether);
        ybPriceFeed_mock.updateAnswer(2e8); // YB at $2

        _seedGaugeYB(50 ether);
        _advancePastInterval();
        vm.prank(address(harvestKeeper));
        harvestKeeper.performUpkeep("");

        assertGt(equilibriumVault.stakedAllocation(), 0, "Vault should have staked when staking APY dominates");
        assertEq(uint256(equilibriumVault.currentStrategy()), uint256(EquilibriumVault.Strategy.Staked), "Vault strategy should be Staked");

        // --- Scenario 2: trading fees now dominate -> vault should unstake ---
        // Set the staked-APY emission rate to 0 and pump the trailing fee revenue
        // (3 entries of the circular buffer) so getUnstakedAPY is high.
        vm.startPrank(address(harvestKeeper));
        strategyManager.setYbEmissionRatePerSecond(0);
        strategyManager.updateFeeData(1_000 ether);
        strategyManager.updateFeeData(1_000 ether);
        strategyManager.updateFeeData(1_000 ether);
        vm.stopPrank();

        uint256 stakedBefore = equilibriumVault.stakedAllocation();
        _seedGaugeYB(50 ether);
        _advancePastInterval();
        vm.prank(address(harvestKeeper));
        harvestKeeper.performUpkeep("");

        assertLt(equilibriumVault.stakedAllocation(), stakedBefore, "Vault should have unstaked when fee APY dominates");
        assertEq(uint256(equilibriumVault.currentStrategy()), uint256(EquilibriumVault.Strategy.Unstaked), "Vault strategy should be Unstaked");
    }
    function testUpkeepRunsWithNoEmissions() public {
        // Deposit so the vault has assets, but do NOT seed any claimable YB in the gauge.
        vm.startPrank(alice);
        ybBTC_mock.approve(address(equilibriumVault), INITIAL_YB_BTC_DEPOSIT);
        equilibriumVault.deposit(INITIAL_YB_BTC_DEPOSIT);
        vm.stopPrank();

        uint256 initialEQMBooster = EQM_token.balanceOf(address(booster));

        // A period with zero emissions must still run the full cycle, not revert.
        _advancePastInterval();
        vm.prank(address(harvestKeeper));
        harvestKeeper.performUpkeep("");

        // EQM incentives are still distributed even though no YB was claimable.
        assertGt(EQM_token.balanceOf(address(booster)), initialEQMBooster, "Upkeep should still distribute EQM with no emissions");
    }

    function testHarvestKeeperLocksYBAndDistributesEQM() public {
        uint256 simulatedYBEmission = 500 ether;

        // Deposit so the vault has assets (avoids StrategyManager's ZeroTotalAssets() revert).
        vm.startPrank(alice);
        ybBTC_mock.approve(address(equilibriumVault), INITIAL_YB_BTC_DEPOSIT);
        equilibriumVault.deposit(INITIAL_YB_BTC_DEPOSIT);
        vm.stopPrank();

        _seedGaugeYB(simulatedYBEmission);

        uint256 initialEQMBooster = EQM_token.balanceOf(address(booster));

        vm.warp(block.timestamp + KEEPER_INTERVAL + 1);
        vm.prank(address(harvestKeeper));
        harvestKeeper.performUpkeep("");

        // The keeper claimed the YB and forwarded all of it to the YBLocker, which locked it
        // into the VotingEscrow (so neither the keeper nor the locker still holds raw YB).
        assertEq(YB_mock.balanceOf(address(harvestKeeper)), 0, "Keeper should have forwarded all YB");
        assertEq(YB_mock.balanceOf(address(ybLocker)), 0, "YBLocker should have locked, not held, the YB");
        assertEq(ybVotingEscrow_mock.balanceOf(address(ybLocker)), simulatedYBEmission, "VotingEscrow should hold the locked YB");

        // Locking mints liquid m_YB to the locker's owner, the HarvestKeeper.
        assertEq(m_YB_token.balanceOf(address(harvestKeeper)), simulatedYBEmission, "Keeper should hold the minted m_YB");

        // The keeper distributed EQM incentives to the Booster via the RewardDistributor.
        assertGt(EQM_token.balanceOf(address(booster)), initialEQMBooster, "Booster should have received EQM rewards");
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
