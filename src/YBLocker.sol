// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVotingEscrow} from "./interfaces/external/IVotingEscrow.sol";
import {m_YB} from "./m_YB.sol";

contract YBLocker is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant MAX_LOCK_TIME = 4 * 365 days;
    IERC20 public immutable YB_TOKEN;
    IVotingEscrow public immutable VOTING_ESCROW;
    m_YB public immutable M_YB_TOKEN;

    uint256 public lockEndTime;

    event Locked(uint256 amount, uint256 unlockTime);
    event Relocked(uint256 amount);
    event LockExtended(uint256 newUnlockTime);

    constructor(
        address _ybTokenAddress, 
        address _votingEscrowAddress, 
        address _mYbTokenAddress
    ) Ownable(msg.sender) {
        YB_TOKEN = IERC20(_ybTokenAddress);
        VOTING_ESCROW = IVotingEscrow(_votingEscrowAddress);
        M_YB_TOKEN = m_YB(_mYbTokenAddress);
    }

    function lock() external onlyOwner nonReentrant {
        // 1. Extend the lock if it's within 30 days of expiring
        if (lockEndTime > 0 && block.timestamp > lockEndTime - (30 days)) {
            uint256 newUnlockTime = block.timestamp + MAX_LOCK_TIME;
            lockEndTime = newUnlockTime;
            VOTING_ESCROW.increase_unlock_time(newUnlockTime);
            emit LockExtended(newUnlockTime);
        }
        
        // 2. Lock any new YB tokens this contract has received
        uint256 balance = YB_TOKEN.balanceOf(address(this));
        if (balance == 0) return;

        YB_TOKEN.approve(address(VOTING_ESCROW), balance);

        if (lockEndTime == 0) {
            // Create a new lock if one doesn't exist
            uint256 unlockTime = block.timestamp + MAX_LOCK_TIME;
            lockEndTime = unlockTime;
            VOTING_ESCROW.create_lock(balance, unlockTime);
            emit Locked(balance, unlockTime);
        } else {
            // Otherwise, add to the existing lock
            VOTING_ESCROW.increase_amount(balance, address(this));
            emit Relocked(balance);
        }

        // 3. Mint the liquid derivative to the owner (the HarvestKeeper)
        M_YB_TOKEN.mint(owner(), balance);
    }
    
    // Security function to recover other ERC20 tokens sent here by mistake
    function sweep(address _token) external onlyOwner {
        require(_token != address(YB_TOKEN), "YBLocker: Cannot sweep the primary token");
        IERC20 token = IERC20(_token);
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }
}