// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Booster is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    IERC20 public immutable M_YB_BTC; // The token users stake (e.g., m_ybBTC)
    IERC20 public immutable EQM;      // The token users earn as a reward

    // Reward calculation variables
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    // Staking variables
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    // --- Events ---
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardNotified(uint256 newReward, uint256 duration);

    constructor(address _mYbbBtcAddress, address _eqmAddress) Ownable(msg.sender) {
        M_YB_BTC = IERC20(_mYbbBtcAddress);
        EQM = IERC20(_eqmAddress);
    }

    // --- Core Reward Logic ---
    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply;
    }

    function earned(address _account) public view returns (uint256) {
        return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18 + rewards[_account];
    }

    // --- User-Facing Functions ---
    function stake(uint256 _amount) external nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "Booster: Cannot stake 0");
        totalSupply += _amount;
        balanceOf[msg.sender] += _amount;
        M_YB_BTC.safeTransferFrom(msg.sender, address(this), _amount);
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant updateReward(msg.sender) {
        require(_amount > 0, "Booster: Cannot withdraw 0");
        totalSupply -= _amount;
        balanceOf[msg.sender] -= _amount;
        M_YB_BTC.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function getReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            EQM.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    // --- Admin Functions ---
    // This is the function called by RewardDistributor
    function notifyRewardAmount(uint256 _reward, uint256 _duration) external onlyOwner updateReward(address(0)) {
        require(_duration > 0, "Booster: Duration must be > 0");
        require(_reward > 0, "Booster: Reward must be > 0");
        
        rewardRate = _reward / _duration;
        lastUpdateTime = block.timestamp;
        emit RewardNotified(_reward, _duration);
    }
}