// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YBLocker, IVotingEscrow} from "../src/YBLocker.sol";
import {MockERC20} from "./EquilibriumVault.t.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockVotingEscrow is IVotingEscrow {
    uint256 public lockedAmount;
    uint256 public unlockTime;
    address public token;
    uint256 public callCountCreateLock;
    uint256 public callCountIncreaseAmount;
    // --- NEW: Counter for increaseUnlockTime calls ---
    uint256 public callCountIncreaseUnlockTime;

    constructor(address tokenAddress) {
        token = tokenAddress;
    }

    function createLock(uint256 value, uint256 newUnlockTime) external {
        lockedAmount += value;
        unlockTime = newUnlockTime;
        callCountCreateLock++;
        bool success = IERC20(token).transferFrom(msg.sender, address(this), value);
        require(success, "Mock transferFrom failed in createLock");
    }

    function increaseAmount(uint256 value) external {
        lockedAmount += value;
        callCountIncreaseAmount++;
        bool success = IERC20(token).transferFrom(msg.sender, address(this), value);
        require(success, "Mock transferFrom failed in increaseAmount");
    }

    // --- NEW: Mock implementation for increaseUnlockTime ---
    function increaseUnlockTime(uint256 newUnlockTime) external {
        unlockTime = newUnlockTime;
        callCountIncreaseUnlockTime++;
    }
}

contract YBLockerTest is Test {
    YBLocker public locker;
    MockERC20 public ybToken;
    MockVotingEscrow public votingEscrow;
    address public owner = address(0x1);

    function setUp() public {
        vm.startPrank(owner);
        ybToken = new MockERC20();
        votingEscrow = new MockVotingEscrow(address(ybToken));
        locker = new YBLocker(address(ybToken), address(votingEscrow));
        vm.stopPrank();
    }

    function test_FirstLock_CallsCreateLock() public {
        ybToken.mint(address(locker), 100 ether);
        vm.startPrank(owner);
        locker.lock();
        vm.stopPrank();
        assertEq(votingEscrow.lockedAmount(), 100 ether, "Escrow should have 100 tokens");
        assertEq(votingEscrow.callCountCreateLock(), 1, "createLock should be called once");
        assertEq(votingEscrow.callCountIncreaseAmount(), 0, "increaseAmount should not be called");
        // --- NEW: Check increaseUnlockTime call count ---
        assertEq(votingEscrow.callCountIncreaseUnlockTime(), 0, "increaseUnlockTime should not be called on first lock");
        assertGt(locker.lockEndTime(), block.timestamp, "Lock end time should be in the future");
    }

    function test_SubsequentLock_CallsIncreaseAmount() public {
        ybToken.mint(address(locker), 100 ether);
        vm.startPrank(owner);
        locker.lock();
        vm.stopPrank();

        // Simulate a small time passage for the lockEndTime to become slightly in the past relative to MAX_LOCK_TIME for the next call
        vm.warp(block.timestamp + 1 days); // Move time forward slightly

        ybToken.mint(address(locker), 50 ether);
        vm.startPrank(owner);
        locker.lock();
        vm.stopPrank();

        assertEq(votingEscrow.lockedAmount(), 150 ether, "Escrow should have 150 tokens total");
        assertEq(votingEscrow.callCountCreateLock(), 1, "createLock should only be called once");
        assertEq(votingEscrow.callCountIncreaseAmount(), 1, "increaseAmount should be called once");
        // --- NEW: Check increaseUnlockTime call count (should be 1 because we extended it) ---
        assertEq(votingEscrow.callCountIncreaseUnlockTime(), 1, "increaseUnlockTime should be called once on subsequent lock");
    }
}