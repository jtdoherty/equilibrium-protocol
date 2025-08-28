// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol"; // Added IERC20 import

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
     * @notice Mocks increasing the amount in an existing lock.
     */
    function increase_amount(uint256 _value, address /*_addr*/) external {
        require(_value > 0, "Cannot add 0");
        stakingToken.transferFrom(msg.sender, address(this), _value);
        lockedBalances[msg.sender] += _value; // Add to existing lock
    }

    /**
     * @notice Mocks increasing the unlock time. For this mock, it does nothing as we don't track unlock times in detail.
     */
    function increase_unlock_time(uint256 /*_new_unlock_time*/) external {
        // In a real scenario, this would update the unlock time.
        // For this mock, we'll just let it pass without specific logic.
    }

    /**
     * @notice Returns the user's voting power, mocked as their locked balance.
     */
    function balanceOf(address _user) external view returns (uint256) {
        return lockedBalances[_user];
    }
}
