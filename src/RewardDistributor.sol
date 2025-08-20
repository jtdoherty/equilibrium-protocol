// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IBooster {
    function notifyRewardAmount(uint256 _reward, uint256 _duration) external;
}

interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract RewardDistributor is Ownable {
    using SafeERC20 for IERC20;

    IMintableERC20 public immutable EQM_TOKEN;
    address public booster;
    uint256 public distributionDuration = 7 days;

    event RewardReceived(address indexed token, uint256 amount);
    event EqmDistributed(uint256 amount, uint256 duration);
    event BoosterUpdated(address indexed newBooster);

    error ZeroAddress();
    error ZeroAmount();
    error ZeroDuration();
    error BoosterNotSet();
    error CannotRecoverEqmToken();

    constructor(address _eqmToken) Ownable(msg.sender) {
        if (_eqmToken == address(0)) revert ZeroAddress();
        EQM_TOKEN = IMintableERC20(_eqmToken);
    }

    function receiveReward(address _tokenAddress, uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();
        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        emit RewardReceived(_tokenAddress, _amount);
    }

    function distributeRewards(uint256 _amount) external onlyOwner {
        if (booster == address(0)) revert BoosterNotSet();
        if (_amount == 0) revert ZeroAmount();
        EQM_TOKEN.mint(booster, _amount); // Mint new EQM tokens directly to the Booster contract.
        IBooster(booster).notifyRewardAmount(_amount, distributionDuration); // Notify the Booster about the new reward amount and its distribution duration.
        emit EqmDistributed(_amount, distributionDuration);
    }
    
    function setBooster(address _newBooster) external onlyOwner {
        if (_newBooster == address(0)) revert ZeroAddress();
        booster = _newBooster;
        emit BoosterUpdated(_newBooster);
    }

    function setDistributionDuration(uint256 _duration) external onlyOwner {
        if (_duration == 0) revert ZeroDuration();
        distributionDuration = _duration;
    }

    function recoverErc20(address _tokenAddress, uint256 _amount) external onlyOwner {
        if (_tokenAddress == address(EQM_TOKEN)) {
            revert CannotRecoverEqmToken();
        }
        IERC20(_tokenAddress).safeTransfer(msg.sender, _amount);
    }
}
