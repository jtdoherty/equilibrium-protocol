// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {Booster} from "../src/Booster.sol";
import {EQM} from "../src/EQM.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {RewardDistributor} from "../src/RewardDistributor.sol";

contract BoosterTest is Test {
    MockERC20 public ybBTC; // Underlying asset for m_ybBTC
    m_ybBTC public mYBBTC;
    EQM public eqmToken;
    Booster public booster;
    RewardDistributor public rewardDistributor;

    address public deployer; // Owner of EQM, RewardDistributor initially, and mYBBTC for minting
    address public user;     // User staking mYBBTC

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");

        // Deploy Mock ybBTC (not directly used by Booster, but useful for context)
        ybBTC = new MockERC20("YieldBasis BTC", "ybBTC");

        // Deploy m_ybBTC (stake token for Booster)
        // deployer remains owner to mint mYBBTC to user later in this test
        mYBBTC = new m_ybBTC(deployer);

        // Deploy EQM token (reward token for Booster)
        // deployer is initial owner, then transfers to RewardDistributor
        eqmToken = new EQM(deployer);

        // Deploy RewardDistributor (owner by deployer)
        vm.startPrank(deployer);
        rewardDistributor = new RewardDistributor(address(eqmToken));
        vm.stopPrank();

        // Deploy Booster (owned by RewardDistributor, which is owned by deployer)
        // Prank with RewardDistributor to set it as owner (if Booster's constructor took an owner)
        // However, Booster's constructor just uses msg.sender. So, deployer deploys it, then transfers ownership.
        vm.startPrank(deployer);
        booster = new Booster(address(mYBBTC), address(eqmToken));
        // Transfer Booster ownership to RewardDistributor
        booster.transferOwnership(address(rewardDistributor));
        vm.stopPrank();

        // Configure ownerships
        vm.startPrank(deployer); // Deployer, as initial owner of EQM and RewardDistributor's owner, configures
        // Transfer EQM ownership (minting rights) to RewardDistributor
        eqmToken.transferOwnership(address(rewardDistributor));
        // Deployer (as owner of RewardDistributor) sets Booster in RewardDistributor
        rewardDistributor.setBooster(address(booster));
        vm.stopPrank();

        // Mint mYBBTC to user for staking (deployer is owner of mYBBTC)
        vm.startPrank(deployer);
        mYBBTC.mint(user, 1000e18);
        vm.stopPrank();
    }

    function testStakeMybBTC() public {
        uint256 stakeAmount = 100e18;

        vm.startPrank(user);
        mYBBTC.approve(address(booster), stakeAmount);
        booster.stake(stakeAmount);
        vm.stopPrank();

        assertEq(booster.balanceOf(user), stakeAmount, "User should have staked mYBBTC");
        assertEq(booster.totalSupply(), stakeAmount, "Booster total supply should be stake amount");
        assertEq(mYBBTC.balanceOf(user), 900e18, "User mYBBTC balance should decrease");
        assertEq(mYBBTC.balanceOf(address(booster)), stakeAmount, "Booster should hold mYBBTC");
    }

    function testEarnedRewardsBeforeNotify() public {
        uint256 stakeAmount = 100e18;

        vm.startPrank(user);
        mYBBTC.approve(address(booster), stakeAmount);
        booster.stake(stakeAmount);
        vm.stopPrank();

        // Skip some time without notifying rewards
        skip(10 days);

        // Should be 0 as no rewards have been notified yet
        assertEq(booster.earned(user), 0, "Earned rewards should be 0 before notifyRewardAmount");
    }

    function testNotifyRewardAmountAndEarned() public {
        uint256 stakeAmount = 100e18; // Corrected to use rewardAmount instead of hardcoded 1000e18 if that was the intent. No, it's just stake amount
        uint256 rewardAmount = 1000e18; // 1000 EQM rewards
        uint256 rewardDuration = 7 days;

        vm.startPrank(user);
        mYBBTC.approve(address(booster), stakeAmount);
        booster.stake(stakeAmount);
        vm.stopPrank();

        // Deployer, as owner of RewardDistributor, triggers reward distribution
        vm.startPrank(deployer); 
        rewardDistributor.distributeRewards(rewardAmount); // This will cause RewardDistributor to mint EQM to Booster
        vm.stopPrank();

        // Skip half of the reward duration
        skip(3.5 days);

        // Calculate expected earned rewards
        uint256 expectedEarned = (rewardAmount * (3.5 days)) / rewardDuration; 
        assertApproxEqAbs(booster.earned(user), expectedEarned, 1e16, "Earned rewards after partial duration incorrect");

        skip(3.5 days); // Skip remaining duration
        assertApproxEqAbs(booster.earned(user), rewardAmount, 1e16, "Earned rewards after full duration incorrect");
    }

    function testClaimRewards() public {
        uint256 stakeAmount = 100e18;
        uint256 rewardAmount = 1000e18;
        uint256 rewardDuration = 7 days;

        vm.startPrank(user);
        mYBBTC.approve(address(booster), stakeAmount);
        booster.stake(stakeAmount);
        vm.stopPrank();

        // Deployer, as owner of RewardDistributor, triggers reward distribution
        vm.startPrank(deployer); 
        rewardDistributor.distributeRewards(rewardAmount);
        vm.stopPrank();

        skip(7 days); // Skip full duration

        // User claims rewards
        vm.startPrank(user);
        uint256 initialEQMBalance = eqmToken.balanceOf(user);
        booster.getReward();
        uint256 finalEQMBalance = eqmToken.balanceOf(user);
        vm.stopPrank();

        assertApproxEqAbs(finalEQMBalance - initialEQMBalance, rewardAmount, 1e16, "Claimed EQM amount incorrect");
        assertEq(booster.earned(user), 0, "Earned rewards should be 0 after claiming");
    }

    function testWithdrawMybBTC() public {
        uint256 stakeAmount = 100e18;
        uint256 withdrawAmount = 50e18;

        vm.startPrank(user);
        mYBBTC.approve(address(booster), stakeAmount);
        booster.stake(stakeAmount);
        vm.stopPrank();

        // Assert initial state after stake
        assertEq(booster.balanceOf(user), stakeAmount, "User should have staked mYBBTC");
        assertEq(mYBBTC.balanceOf(user), 900e18, "User mYBBTC balance correct after stake");
        assertEq(mYBBTC.balanceOf(address(booster)), stakeAmount, "Booster should hold mYBBTC");

        // Withdraw a portion
        vm.startPrank(user);
        booster.withdraw(withdrawAmount);
        vm.stopPrank();

        // Check balances after withdrawal
        assertEq(booster.balanceOf(user), stakeAmount - withdrawAmount, "User staked balance should decrease");
        assertEq(booster.totalSupply(), stakeAmount - withdrawAmount, "Booster total supply should decrease");
        assertEq(mYBBTC.balanceOf(user), 900e18 + withdrawAmount, "User mYBBTC balance should increase");
        assertEq(mYBBTC.balanceOf(address(booster)), stakeAmount - withdrawAmount, "Booster mYBBTC balance should decrease");
    }
}
