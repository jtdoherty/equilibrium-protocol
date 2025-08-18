// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {EquilibriumVault} from "./EquilibriumVault.sol";

contract StrategyManager is Ownable {
    EquilibriumVault public vault;
    address public keeper;
    uint256 public switchBufferBps;

    event KeeperUpdated(address indexed newKeeper);
    event SwitchBufferUpdated(uint256 newBufferBps);
    event StrategySwitched(bool isStaked);

    error NotKeeper();

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert NotKeeper();
        _;
    }



    constructor(address vaultAddress) Ownable(msg.sender) {
        vault = EquilibriumVault(vaultAddress);
    }

    // --- CORRECTION: Changed from `pure` to `view` and added `virtual` ---
    function getUnstakedApr() public view virtual returns (uint256) {
        return 500;
    }

    // --- CORRECTION: Changed from `pure` to `view` and added `virtual` ---
    function getStakedApr() public view virtual returns (uint256) {
        return 600;
    }

    function switchStrategy() external onlyKeeper {
        bool isCurrentlyStaked = vault.isStaked();
        uint256 unstakedApr = getUnstakedApr();
        uint256 stakedApr = getStakedApr();

        if (isCurrentlyStaked) {
            if (unstakedApr > stakedApr + switchBufferBps) {
                vault._unstakePool();
                emit StrategySwitched(false);
            }
        } else {
            if (stakedApr > unstakedApr + switchBufferBps) {
                vault._stakePool();
                emit StrategySwitched(true);
            }
        }
    }

    function setKeeper(address newKeeper) external onlyOwner {
        keeper = newKeeper;
        emit KeeperUpdated(newKeeper);
    }

    function setSwitchBuffer(uint256 newBufferBps) external onlyOwner {
        switchBufferBps = newBufferBps;
        emit SwitchBufferUpdated(newBufferBps);
    }
}