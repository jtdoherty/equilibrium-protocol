// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface IVotingEscrow {
    function createLock(uint256 value, uint256 unlockTime) external;
    function increaseAmount(uint256 value) external;
    function increaseUnlockTime(uint256 unlockTime) external;
}

contract YBLocker is Ownable {
    uint256 public constant MAX_LOCK_TIME = 4 * 365 days;
    IERC20 public immutable YB_TOKEN;
    IVotingEscrow public immutable VOTING_ESCROW;
    uint256 public lockEndTime;

    event Locked(uint256 amount, uint256 unlockTime);
    event Relocked(uint256 amount);

    constructor(address ybTokenAddress, address votingEscrowAddress) Ownable(msg.sender) {
        YB_TOKEN = IERC20(ybTokenAddress);
        VOTING_ESCROW = IVotingEscrow(votingEscrowAddress);
    }

    function lock() external onlyOwner {
        uint256 balance = YB_TOKEN.balanceOf(address(this));

        // If a lock exists and is less than 4 years from now, extend it.
        if (lockEndTime > 0 && lockEndTime < block.timestamp + MAX_LOCK_TIME) {
            uint256 newUnlockTime = block.timestamp + MAX_LOCK_TIME;
            lockEndTime = newUnlockTime;
            VOTING_ESCROW.increaseUnlockTime(newUnlockTime);
            // We can emit an event here if desired
        }

        if (balance == 0) return;
        YB_TOKEN.approve(address(VOTING_ESCROW), 0);
        YB_TOKEN.approve(address(VOTING_ESCROW), balance);
        if (lockEndTime == 0) {
            uint256 unlockTime = block.timestamp + MAX_LOCK_TIME;
            lockEndTime = unlockTime;
            VOTING_ESCROW.createLock(balance, unlockTime);
            emit Locked(balance, unlockTime);
        } else {
            VOTING_ESCROW.increaseAmount(balance);
            emit Relocked(balance);
        }
    }
}
