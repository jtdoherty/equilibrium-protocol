// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol"; // Added SafeERC20

/**
 * @title MockLiquidityGauge
 * @author Equilibrium Team
 * @notice A simplified mock of a Curve-style Liquidity Gauge.
 * It allows users to deposit a token (ybBTC) and claim rewards in another token (YB).
 */
contract MockLiquidityGauge {
    using SafeERC20 for IERC20; // Use SafeERC20

    IERC20 public immutable stakingToken; // The token to be staked (ybBTC)
    IERC20 public immutable rewardToken;  // The reward token (YB)

    mapping(address => uint256) public balances; // Maps receiver to staked balance
    mapping(address => uint256) public claimable_rewards;

    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    // Matches ILiquidityGauge.deposit(uint256 assets, address receiver)
    function deposit(uint256 _assets, address _receiver) external returns (uint256) {
        require(_assets > 0, "Cannot deposit 0");
        stakingToken.safeTransferFrom(msg.sender, address(this), _assets); // Transfer from msg.sender to gauge
        balances[_receiver] += _assets; // Update receiver's balance in gauge
        return _assets; // Return shares (1:1 for simplicity)
    }

    // Matches ILiquidityGauge.withdraw(uint256 assets, address receiver, address owner)
    function withdraw(uint256 _assets, address _receiver, address _owner) external returns (uint256) {
        require(_assets > 0, "Cannot withdraw 0");
        require(balances[_owner] >= _assets, "Insufficient staked balance");
        balances[_owner] -= _assets; // Decrease owner's balance in gauge
        stakingToken.safeTransfer(_receiver, _assets); // Transfer to receiver
        return _assets; // Return shares (1:1 for simplicity)
    }

    function claim(IERC20 _reward, address _user) external returns (uint256) {
        uint256 rewards = claimable_rewards[_user];
        if (rewards > 0) {
            claimable_rewards[_user] = 0;
            _reward.safeTransfer(_user, rewards);
        }
        return rewards;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return balances[_account];
    }

    function lp_token() external view returns (address) {
        return address(stakingToken);
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
