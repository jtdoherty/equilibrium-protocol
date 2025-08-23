// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {KeeperCompatibleInterface} from "chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/KeeperCompatibleInterface.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {YBLocker} from "../src/YBLocker.sol"; // Adjust path

contract HarvestKeeper is KeeperCompatibleInterface, Ownable {
    uint256 public immutable interval;
    uint256 public lastTimeStamp;
    
    IERC20 public immutable YB_TOKEN;
    YBLocker public immutable YB_LOCKER;

    constructor(address _ybTokenAddress, address _ybLockerAddress, uint256 _interval) Ownable(msg.sender) {
        YB_TOKEN = IERC20(_ybTokenAddress);
        YB_LOCKER = YBLocker(_ybLockerAddress);
        interval = _interval;
        lastTimeStamp = block.timestamp;
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
        // No performData needed
    }

    function performUpkeep(bytes calldata) external override {
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            
            // Approve YBLocker to spend our YB and then lock it.
            // The YB must already be in this contract.
            uint256 ybBalance = YB_TOKEN.balanceOf(address(this));
            if (ybBalance > 0) {
                YB_TOKEN.transfer(address(YB_LOCKER), ybBalance); // Send the tokens directly to the locker
                YB_LOCKER.lock(); // Now tell the locker to lock what it just received
            }
        }
    }

    // Helper function to load this contract with "harvested" rewards
    function addHarvestableRewards(uint256 amount) external {
        // In a real scenario, this would be a more secure function.
        // For testing, we'll just pull from the caller.
        YB_TOKEN.transferFrom(msg.sender, address(this), amount);
    }
}