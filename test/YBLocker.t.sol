// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YBLocker, IVotingEscrow} from "../src/YBLocker.sol";
import {m_YB} from "../src/m_YB.sol";
import {MockERC20} from "./EquilibriumVault.t.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockVotingEscrow is IVotingEscrow {
    uint256 public lockedAmount;
    uint256 public unlockTime;
    address public token;
    uint256 public callCountCreateLock;
    uint256 public callCountIncreaseAmount;
    uint256 public callCountIncreaseUnlockTime;

    constructor(address tokenAddress) {
        token = tokenAddress;
    }

    function createLock(uint256 value, uint256 newUnlockTime) external {
        lockedAmount += value;
        unlockTime = newUnlockTime;
        callCountCreateLock++;
        require(IERC20(token).transferFrom(msg.sender, address(this), value));
    }

    function increaseAmount(uint256 value) external {
        lockedAmount += value;
        callCountIncreaseAmount++;
        require(IERC20(token).transferFrom(msg.sender, address(this), value));
    }

    function increaseUnlockTime(uint256 newUnlockTime) external {
        unlockTime = newUnlockTime;
        callCountIncreaseUnlockTime++;
    }
}

contract YBLockerTest is Test {
    YBLocker public locker;
    MockERC20 public ybToken;
    m_YB public mYbToken;
    MockVotingEscrow public votingEscrow;
    address public owner = address(0x1);

    function setUp() public {
        vm.startPrank(owner);
        // --- FIX IS HERE ---
        ybToken = new MockERC20("Mock YB Token", "YB");
        mYbToken = new m_YB(owner);
        votingEscrow = new MockVotingEscrow(address(ybToken));
        locker = new YBLocker(address(ybToken), address(votingEscrow), address(mYbToken));
        mYbToken.transferOwnership(address(locker));
        vm.stopPrank();
    }

    function test_FirstLock_MintsMYB() public {
        ybToken.mint(address(locker), 100 ether);
        vm.startPrank(owner);
        locker.lock();
        vm.stopPrank();
        assertEq(votingEscrow.lockedAmount(), 100 ether);
        assertEq(mYbToken.balanceOf(owner), 100 ether, "Owner should receive 100 m_YB");
    }

    function test_SubsequentLock_MintsMoreMYB() public {
        ybToken.mint(address(locker), 100 ether);
        vm.startPrank(owner);
        locker.lock();
        vm.stopPrank();

        // Warp time to ensure increaseUnlockTime is called
        vm.warp(block.timestamp + 1 days);

        ybToken.mint(address(locker), 50 ether);
        vm.startPrank(owner);
        locker.lock();
        vm.stopPrank();
        
        assertEq(votingEscrow.lockedAmount(), 150 ether);
        assertEq(mYbToken.balanceOf(owner), 150 ether, "Owner should have a total of 150 m_YB");
        assertEq(votingEscrow.callCountIncreaseUnlockTime(), 1, "increaseUnlockTime should be called");
    }
}