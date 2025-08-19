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

    address public owner = address(0x1);
    address public user1 = address(0x10);
    address public user2 = address(0x20);

    function setUp() public {
        vm.startPrank(owner);
        eqmToken = new EQM();
        mYBTC = new MockERC20();
        booster = new Booster(address(eqmToken), address(mYBTC));
        // Grant MINTER_ROLE on EQM to the owner/deployer for testing
        eqmToken.grantRole(eqmToken.MINTER_ROLE(), owner);
        vm.stopPrank();

        mYBTC.mint(user1, 1000 ether);
        mYBTC.mint(user2, 1000 ether);
    }

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
    
    // ... (Keep all your other non-reward tests like test_Stake_SingleUser, etc.)

    function test_Reward_SingleUser_SimpleClaim() public {
        _stake(user1, 100 ether);
        
        vm.startPrank(owner);
        eqmToken.approve(address(booster), 100 ether); // Owner approves the booster
        eqmToken.mint(address(booster), 100 ether); // Mints directly to booster for simplicity
        booster.notifyRewardAmount(100 ether, 100 seconds); // Starts the reward period
        vm.stopPrank();

        vm.warp(block.timestamp + 100); // Pass the full duration

        _claim(user1);
        assertApproxEqAbs(eqmToken.balanceOf(user1), 100 ether, 1, "User1 should receive ~100 EQM");
    }

    function test_Reward_MultipleUsers_ProportionalClaim() public {
        _stake(user1, 100 ether);
        
        vm.startPrank(owner);
        eqmToken.approve(address(booster), 100 ether);
        eqmToken.mint(address(booster), 100 ether);
        booster.notifyRewardAmount(100 ether, 100 seconds);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 50); // 50 seconds pass
        _stake(user2, 100 ether);
        
        vm.warp(block.timestamp + 50); // Remaining 50 seconds pass

        _claim(user1);
        assertApproxEqAbs(eqmToken.balanceOf(user1), 75 ether, 1, "User1 should receive ~75 EQM");

        _claim(user2);
        assertApproxEqAbs(eqmToken.balanceOf(user2), 25 ether, 1, "User2 should receive ~25 EQM");
    }
}