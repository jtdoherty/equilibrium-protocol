// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockVotingEscrow
 * @author Equilibrium Team
 * @notice A simplified mock of the Curve Voting Escrow contract (veCRV).
 * It simulates locking a token (YB) to receive voting power (veYB).
 * For simplicity, voting power is 1:1 with the amount locked.
 */
contract MockVotingEscrow {
    IERC20 public immutable stakingToken; // The token to be locked (YB)
    mapping(address => uint256) public lockedBalances;

    constructor(address _stakingToken) {
        stakingToken = IERC20(_stakingToken);
    }

    /**
     * @notice Mocks creating a lock. Simply records the locked amount.
     */
    function create_lock(uint256 _value, uint256 /*_unlock_time*/) external {
        require(_value > 0, "Cannot lock 0");
        stakingToken.transferFrom(msg.sender, address(this), _value);
        lockedBalances[msg.sender] += _value;
    }

    /**
     * @notice Returns the user's voting power, mocked as their locked balance.
     */
    function balanceOf(address _user) external view returns (uint256) {
        return lockedBalances[_user];
    }
}