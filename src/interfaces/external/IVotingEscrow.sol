// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVotingEscrow
 * @author Equilibrium Protocol
 * @notice This interface is a direct translation of the YieldBasis VotingEscrow ABI.
 * It MUST be a perfect match to ensure successful cross-contract calls.
 * Last verified against YieldBasis ABI version: [VERSION_NUMBER_HERE] on [DATE_HERE].
 */
interface IVotingEscrow {
    /**
     * @notice Creates a new lock for the sender.
     * @param _value The amount of YB tokens to lock.
     * @param _unlock_time The timestamp when the lock expires.
     */
    function create_lock(uint256 _value, uint256 _unlock_time) external;

    /**
     * @notice Increases the amount of YB tokens in an existing lock.
     * @param _value The additional amount of YB tokens to lock.
     */
    function increase_amount(uint256 _value) external;

    /**
     * @notice Extends the duration of an existing lock.
     * @param _unlock_time The new, later timestamp for when the lock expires.
     */
    function increase_unlock_time(uint256 _unlock_time) external;
}