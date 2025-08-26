// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockLiquidityGauge
 * @author Equilibrium Team
 * @notice A simplified mock of a Curve-style Liquidity Gauge.
 * It allows users to deposit a token (ybBTC) and claim rewards in another token (YB).
 */
contract MockLiquidityGauge {
    IERC20 public immutable stakingToken; // The token to be staked (ybBTC)
    IERC20 public immutable rewardToken;  // The reward token (YB)

    mapping(address => uint256) public balances;
    mapping(address => uint256) public claimable_rewards;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Cannot deposit 0");
        balances[msg.sender] += _amount;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Cannot withdraw 0");
        balances[msg.sender] -= _amount;
        stakingToken.transfer(msg.sender, _amount);
    }

    function claim(address _recipient) external returns (uint256) {
        uint256 rewards = claimable_rewards[msg.sender];
        if (rewards > 0) {
            claimable_rewards[msg.sender] = 0;
            rewardToken.transfer(_recipient, rewards);
        }
        return rewards;
    }

    function balanceOf(address _user) external view returns (uint256) {
        return balances[_user];
    }

    /**
     * @notice Test-only function to manually set the amount of claimable rewards for a user.
     * @param _user The user whose rewards are being set.
     * @param _amount The amount of YB rewards to set.
     */
    function setRewards(address _user, uint256 _amount) external {
        claimable_rewards[_user] = _amount;
    }
}

// Minimal interface needed for mocks to interact with ERC20 tokens
interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}
