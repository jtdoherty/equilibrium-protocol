// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVotingEscrow
 * @author Equilibrium Protocol (Interface adapted from YieldBasis VotingEscrow.vy)
 * @notice Interface for the YieldBasis VotingEscrow contract.
 * Used by the YBLocker to manage locked YB tokens and obtain veYB power.
 */
interface IVotingEscrow {
    function create_lock(uint256 _value, uint256 _unlock_time) external;
    function increase_amount(uint256 _value, address _for) external; // Added _for param from Vyper code
    function increase_unlock_time(uint256 _unlock_time) external;
    function get_last_user_point(address addr) external view returns (int256 bias, int256 slope, uint256 ts); // More accurate Point struct return
    function locked__end(address _addr) external view returns (uint256); // Direct getter for locked.end
    function transfer_clearance_checker() external view returns (address); // Used by gauge controller
}
