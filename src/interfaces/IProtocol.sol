// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEquilibriumVault {
    function executeStrategyChange(bool _shouldBeStaked) external;
    function compound(uint256 _amount) external;
    function getAssetBalances() external view returns (uint256 staked, uint256 unstaked);
    function rebalance(int256 delta) external;
    function stakedBalance() external view returns (uint256);
    function totalAssets() external view returns (uint256);
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