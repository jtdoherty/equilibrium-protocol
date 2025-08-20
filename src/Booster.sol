// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {EQM} from "./EQM.sol";

contract Booster is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for EQM;

    EQM public immutable EQM_TOKEN;
    IERC20 public immutable STAKING_TOKEN;

    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalances;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public periodFinish;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardAdded(uint256 reward);

    error NoAmountToStake();
    error NoAmountToUnstake();
    error NotEnoughStaked();
    error NoRewardsToClaim();
    error RewardPeriodNotFinished();

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    constructor(address _eqmToken, address _stakingToken) Ownable(msg.sender) {
        EQM_TOKEN = EQM(_eqmToken);
        STAKING_TOKEN = IERC20(_stakingToken);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalStaked);
    }

    function earned(address account) public view returns (uint256) {
        return (stakedBalances[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18) + rewards[account];
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert NoAmountToStake();
        totalStaked += amount;
        stakedBalances[msg.sender] += amount;
        STAKING_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        if (amount == 0) revert NoAmountToUnstake();
        if (stakedBalances[msg.sender] < amount) revert NotEnoughStaked();
        totalStaked -= amount;
        stakedBalances[msg.sender] -= amount;
        STAKING_TOKEN.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward == 0) revert NoRewardsToClaim();
        rewards[msg.sender] = 0;
        EQM_TOKEN.safeTransfer(msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }

    function notifyRewardAmount(uint256 reward, uint256 duration) external onlyOwner updateReward(address(0)) {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward / duration;
        } else {
            uint256 remaining = periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / duration;
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + duration;
        emit RewardAdded(reward);
    }

    function recoverErc20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(STAKING_TOKEN), "Cannot recover staking token");
        require(tokenAddress != address(EQM_TOKEN), "Cannot recover EQM token");
        IERC20(tokenAddress).safeTransfer(msg.sender, amount);
    }
}