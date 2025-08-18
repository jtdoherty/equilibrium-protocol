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

        // --- CORRECTION: We must call lock() as the owner. ---
        vm.startPrank(owner);
        locker.lock();
        vm.stopPrank();
        // --- END CORRECTION ---

        assertEq(votingEscrow.lockedAmount(), 100 ether, "Escrow should have 100 tokens");
        assertEq(votingEscrow.callCountCreateLock(), 1, "createLock should be called once");
        assertEq(votingEscrow.callCountIncreaseAmount(), 0, "increaseAmount should not be called");
        assertGt(locker.lockEndTime(), block.timestamp, "Lock end time should be in the future");
    }

    function test_SubsequentLock_CallsIncreaseAmount() public {
        ybToken.mint(address(locker), 100 ether);
        // --- CORRECTION: First lock must be from the owner. ---
        vm.startPrank(owner);
        locker.lock();
        vm.stopPrank();

        ybToken.mint(address(locker), 50 ether);
        // --- CORRECTION: Second lock must also be from the owner. ---
        vm.startPrank(owner);
        locker.lock();
        vm.stopPrank();
        // --- END CORRECTION ---

        assertEq(votingEscrow.lockedAmount(), 150 ether, "Escrow should have 150 tokens total");
        assertEq(votingEscrow.callCountCreateLock(), 1, "createLock should only be called once");
        assertEq(votingEscrow.callCountIncreaseAmount(), 1, "increaseAmount should be called once");
    }
}