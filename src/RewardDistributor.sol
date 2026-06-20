// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Interface for the Booster to call notifyRewardAmount
interface IBooster {
    function notifyRewardAmount(uint256 _reward, uint256 _duration) external;
}

// Interface for the EQM token to call mint
interface IMintableERC20 is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @title RewardDistributor
 * @author Equilibrium Protocol
 * @notice This contract is the central treasury for EQM rewards. It is the sole minter
 * of the EQM token. It is owned and controlled by the HarvestKeeper, which commands it
 * to mint new EQM and distribute them to the Booster contract.
 */
contract RewardDistributor is Ownable {
    // --- State Variables ---
    IMintableERC20 public immutable EQM_TOKEN;
    address public booster;
    uint256 public distributionDuration = 7 days;

    // --- Events ---
    event EqmDistributed(address indexed destination, uint256 amount, uint256 duration);
    event BoosterUpdated(address indexed newBooster);
    event DistributionDurationUpdated(uint256 newDuration);

    // --- Errors ---
    error ZeroAddress();
    error ZeroAmount();
    error ZeroDuration();
    error BoosterNotSet();

    constructor(address _eqmToken) Ownable(msg.sender) {
        if (_eqmToken == address(0)) revert ZeroAddress();
        EQM_TOKEN = IMintableERC20(_eqmToken);
    }

    // --- Core Logic ---
    /**
     * @notice Mints new EQM and sends them to the Booster to begin a reward cycle.
     * @dev Can only be called by the owner (the HarvestKeeper).
     * @param _amount The amount of new EQM tokens to mint and distribute.
     */
    function distributeRewards(uint256 _amount) external onlyOwner {
        if (booster == address(0)) revert BoosterNotSet();
        if (_amount == 0) revert ZeroAmount();

        // More gas-efficient: mints EQM directly to the Booster in one step.
        EQM_TOKEN.mint(booster, _amount);

        // Notify the Booster about the new reward amount and its distribution duration.
        IBooster(booster).notifyRewardAmount(_amount, distributionDuration);

        emit EqmDistributed(booster, _amount, distributionDuration);
    }

    // --- Admin Functions ---
    /**
     * @notice Sets or updates the address of the Booster contract.
     * @dev The owner of the Booster contract MUST be this RewardDistributor.
     */
    function setBooster(address _newBooster) external onlyOwner {
        if (_newBooster == address(0)) revert ZeroAddress();
        booster = _newBooster;
        emit BoosterUpdated(_newBooster);
    }

    /**
     * @notice Updates the duration over which rewards are distributed.
     */
    function setDistributionDuration(uint256 _duration) external onlyOwner {
        if (_duration == 0) revert ZeroDuration();
        distributionDuration = _duration;
        emit DistributionDurationUpdated(_duration);
    }

    /**
     * @notice Function to recover any other ERC20 token accidentally sent to this contract.
     * @dev This CANNOT be used to recover the EQM token.
     */
    function sweep(address _tokenAddress) external onlyOwner {
        if (_tokenAddress == address(EQM_TOKEN)) {
            revert(); // Cannot recover the primary token
        }
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(owner(), token.balanceOf(address(this)));
    }
}
