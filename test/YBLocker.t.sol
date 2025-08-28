// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockVotingEscrow} from "../src/mocks/MockVotingEscrow.sol";
import {YBLocker} from "../src/YBLocker.sol";
import {m_YB} from "../src/m_YB.sol";

contract YBLockerTest is Test {
    MockERC20 public YB_TOKEN;
    MockVotingEscrow public votingEscrow;
    m_YB public mYB_TOKEN;
    YBLocker public ybLocker;

    address public deployer; // Owner of YBLocker and initial mYB_TOKEN owner
    address public user;     // User who provides YB_TOKEN

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");

        // Deploy Mock YB Token
        YB_TOKEN = new MockERC20("YieldBasis Token", "YB");

        // Deploy Mock VotingEscrow
        votingEscrow = new MockVotingEscrow(address(YB_TOKEN));

        // Deploy m_YB token with deployer as initial owner
        mYB_TOKEN = new m_YB(deployer);

        // Deploy YBLocker with deployer as owner
        vm.startPrank(deployer);
        ybLocker = new YBLocker(address(YB_TOKEN), address(votingEscrow), address(mYB_TOKEN));
        // Transfer ownership of mYB_TOKEN to YBLocker so it can mint
        mYB_TOKEN.transferOwnership(address(ybLocker));
        vm.stopPrank();

        // Mint some YB_TOKEN for the user to deposit
        YB_TOKEN.mint(user, 1000e18);
    }

    function testInitialLock() public {
        uint256 lockAmount = 200e18;

        // User transfers YB to YBLocker
        vm.startPrank(user);
        YB_TOKEN.transfer(address(ybLocker), lockAmount);
        vm.stopPrank();

        // YBLocker (owned by deployer) calls lock()
        vm.startPrank(deployer);
        ybLocker.lock();
        vm.stopPrank();

        // Verify YBLocker's YB_TOKEN balance is 0 after locking
        assertEq(YB_TOKEN.balanceOf(address(ybLocker)), 0, "YBLocker should have 0 YB_TOKEN after locking");

        // Verify MockVotingEscrow holds the YB_TOKEN
        assertEq(YB_TOKEN.balanceOf(address(votingEscrow)), lockAmount, "VotingEscrow should hold the locked YB_TOKEN");

        // Verify YBLocker has the correct voting power in MockVotingEscrow
        assertEq(votingEscrow.balanceOf(address(ybLocker)), lockAmount, "YBLocker should have correct voting power");

        // Verify deployer (owner of YBLocker) received m_YB_TOKEN
        assertEq(mYB_TOKEN.balanceOf(deployer), lockAmount, "Deployer should receive m_YB_TOKEN");
    }

    function testRelockExisting() public {
        uint256 initialLockAmount = 200e18;
        uint256 additionalLockAmount = 100e18;

        // Initial lock
        vm.startPrank(user);
        YB_TOKEN.transfer(address(ybLocker), initialLockAmount);
        vm.stopPrank();
        vm.startPrank(deployer);
        ybLocker.lock();
        vm.stopPrank();

        // Assert initial state
        assertEq(YB_TOKEN.balanceOf(address(votingEscrow)), initialLockAmount, "Initial lock amount correct");
        assertEq(votingEscrow.balanceOf(address(ybLocker)), initialLockAmount, "Initial voting power correct");
        assertEq(mYB_TOKEN.balanceOf(deployer), initialLockAmount, "Initial m_YB minted correct");

        // Deposit more YB and relock
        vm.startPrank(user);
        YB_TOKEN.transfer(address(ybLocker), additionalLockAmount);
        vm.stopPrank();

        vm.startPrank(deployer);
        ybLocker.lock();
        vm.stopPrank();

        // Verify total YB_TOKEN in VotingEscrow
        assertEq(YB_TOKEN.balanceOf(address(votingEscrow)), initialLockAmount + additionalLockAmount, "Total YB_TOKEN in VotingEscrow after relock");

        // Verify updated voting power for YBLocker
        assertEq(votingEscrow.balanceOf(address(ybLocker)), initialLockAmount + additionalLockAmount, "Updated voting power for YBLocker");

        // Verify deployer (owner of YBLocker) received additional m_YB_TOKEN
        assertEq(mYB_TOKEN.balanceOf(deployer), initialLockAmount + additionalLockAmount, "Total m_YB minted to deployer after relock");
    }
}
