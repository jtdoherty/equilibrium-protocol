// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {EQM} from "./EQM.sol";
import {Booster} from "./Booster.sol";

contract RewardDistributor is Ownable {
    using SafeERC20 for IERC20;

    EQM public immutable EQM_TOKEN;
    address public booster;
    uint256 public distributionDuration = 7 days; // Rewards are distributed over 1 week

    event RewardReceived(address indexed token, uint256 amount);
    event EqmDistributed(uint256 amount, uint256 duration);
    event BoosterUpdated(address indexed newBooster);

    error ZeroAddress();

    constructor(address _eqmToken) Ownable(msg.sender) {
        require(_eqmToken != address(0), "EQM token zero address");
        EQM_TOKEN = EQM(_eqmToken);
    }

    function receiveReward(address tokenAddress, uint256 amount) external {
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
        emit RewardReceived(tokenAddress, amount);
    }

    // This function can now be permissioned for a keeper
    function distributeRewards(uint256 amount) external onlyOwner {
        require(booster != address(0), "Booster not set");
        EQM_TOKEN.mint(address(this), amount); // Mint to this contract first
        EQM_TOKEN.approve(booster, amount); // Approve booster to pull
        Booster(booster).notifyRewardAmount(amount, distributionDuration);
        emit EqmDistributed(amount, distributionDuration);
    }

    function setBooster(address _newBooster) external onlyOwner {
        require(_newBooster != address(0), "Booster zero address");
        booster = _newBooster;
        emit BoosterUpdated(_newBooster);
    }

    function setDistributionDuration(uint256 _duration) external onlyOwner {
        distributionDuration = _duration;
    }
}