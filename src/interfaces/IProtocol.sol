// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEquilibriumVault {
    function executeStrategyChange(bool _shouldBeStaked) external;
    function compound(uint256 _amount) external;
}

interface IYBLocker {
    function lock() external;
}

interface IRewardDistributor {
    function distributeRewards(uint256 _amount) external;
}

interface IStrategyManager {
    function switchStrategy() external;
}