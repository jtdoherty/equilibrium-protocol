// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEquilibriumVault {
    function getAssetBalances() external view returns (uint256 staked, uint256 unstaked);
    function rebalance(int256 percentageChange) external; // New function on vault
    function compound(uint256 _amount) external;
    function totalAssets() external view returns (uint256); // Added for StrategyManager
    function isStaked() external view returns (bool); // Added for StrategyManager
}

interface IYBLocker {
    function lock() external;
}

interface IRewardDistributor {
    function distributeRewards(uint256 _amount) external;
}

interface IStrategyManager {
    function switchStrategy() external;
    function updateFeeData(uint256 _newFeeAmount) external; // Keeper will update this
}
