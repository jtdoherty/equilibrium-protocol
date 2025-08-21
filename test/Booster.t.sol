// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Booster} from "../src/Booster.sol";
import {EQM} from "../src/EQM.sol";
import {MockERC20} from "./EquilibriumVault.t.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract BoosterTest is Test {
    Booster public booster;
    EQM public eqmToken;
    MockERC20 public mYBTC;
    MockERC20 public externalToken;

    address public owner = address(0x1);
    address public user1 = address(0x10);
    address public user2 = address(0x20);

    function setUp() public {
        vm.startPrank(owner);
        eqmToken = new EQM();
        mYBTC = new MockERC20("Mock Maximized ybBTC", "mYBTC");
        booster = new Booster(address(eqmToken), address(mYBTC));
        eqmToken.grantRole(eqmToken.MINTER_ROLE(), owner);
        vm.stopPrank();

        mYBTC.mint(user1, 1000 ether);
        mYBTC.mint(user2, 1000 ether);
        externalToken = new MockERC20("External Token", "EXT");
    }

    // --- Helper Functions ---
    function _stake(address _user, uint256 _amount) internal {
        vm.startPrank(_user);
        mYBTC.approve(address(booster), _amount);
        booster.stake(_amount);
        vm.stopPrank();
    }

    function _claim(address _user) internal {
        vm.startPrank(_user);
        booster.claimReward();
        vm.stopPrank();
    }
    
    // --- Staking and Unstaking Tests (Restored) ---
    function test_Stake_SingleUser() public {
        _stake(user1, 100 ether);
        assertEq(booster.totalStaked(), 100 ether);
        assertEq(booster.stakedBalances(user1), 100 ether);
    }

    function test_Stake_MultipleUsers() public {
        _stake(user1, 100 ether);
        _stake(user2, 50 ether);
        assertEq(booster.totalStaked(), 150 ether);
        assertEq(booster.stakedBalances(user1), 100 ether);
        assertEq(booster.stakedBalances(user2), 50 ether);
    }

    function test_Stake_RevertsZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert(Booster.NoAmountToStake.selector);
        booster.stake(0);
        vm.stopPrank();
    }

    function test_Unstake_FullAmount() public {
        _stake(user1, 100 ether);
        vm.startPrank(user1);
        booster.unstake(100 ether);
        vm.stopPrank();
        assertEq(booster.totalStaked(), 0);
        assertEq(booster.stakedBalances(user1), 0);
    }
    
    function test_Unstake_RevertsNotEnoughStaked() public {
        _stake(user1, 100 ether);
        vm.startPrank(user1);
        vm.expectRevert(Booster.NotEnoughStaked.selector);
        booster.unstake(101 ether);
        vm.stopPrank();
    }

    // --- Reward Tests (Corrected) ---
    function test_Reward_SingleUser_SimpleClaim() public {
        _stake(user1, 100 ether);
        
        vm.startPrank(owner);
        eqmToken.mint(address(booster), 100 ether);
        booster.notifyRewardAmount(100 ether, 100 seconds);
        vm.stopPrank();

        vm.warp(block.timestamp + 100);

        _claim(user1);
        assertApproxEqAbs(eqmToken.balanceOf(user1), 100 ether, 1, "User1 should receive ~100 EQM");
    }

    function test_Reward_MultipleUsers_ProportionalClaim() public {
        _stake(user1, 100 ether);
        
        vm.startPrank(owner);
        eqmToken.mint(address(booster), 100 ether);
        booster.notifyRewardAmount(100 ether, 100 seconds);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 50);
        _stake(user2, 100 ether);
        
        vm.warp(block.timestamp + 50);

        _claim(user1);
        assertApproxEqAbs(eqmToken.balanceOf(user1), 75 ether, 1, "User1 should receive ~75 EQM");

        _claim(user2);
        assertApproxEqAbs(eqmToken.balanceOf(user2), 25 ether, 1, "User2 should receive ~25 EQM");
    }

    function test_Reward_RevertsNoRewardsToClaim() public {
        _stake(user1, 100 ether);
        vm.startPrank(user1);
        vm.expectRevert(Booster.NoRewardsToClaim.selector);
        booster.claimReward();
        vm.stopPrank();
    }

    // --- Admin Tests (Restored) ---
    function test_Admin_CanRecoverERC20() public {
        uint256 lostAmount = 50 ether;
        externalToken.mint(address(booster), lostAmount);

        vm.startPrank(owner);
        booster.recoverErc20(address(externalToken), lostAmount);
        vm.stopPrank();

        assertEq(externalToken.balanceOf(owner), lostAmount);
        assertEq(externalToken.balanceOf(address(booster)), 0);
    }

    function test_Admin_RevertsRecoverERC20_IfStakingToken() public {
        mYBTC.mint(address(booster), 10 ether);
        vm.startPrank(owner);
        vm.expectRevert("Cannot recover staking token");
        booster.recoverErc20(address(mYBTC), 10 ether);
        vm.stopPrank();
    }

    function test_Admin_RevertsRecoverERC20_IfEQMToken() public {
        vm.startPrank(owner);
        eqmToken.mint(address(booster), 10 ether);
        vm.expectRevert("Cannot recover EQM token");
        booster.recoverErc20(address(eqmToken), 10 ether);
        vm.stopPrank();
    }
    
    function test_Admin_RevertsRecoverERC20_IfNotOwner() public {
        externalToken.mint(address(booster), 10 ether);
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        booster.recoverErc20(address(externalToken), 10 ether);
        vm.stopPrank();
    }
}