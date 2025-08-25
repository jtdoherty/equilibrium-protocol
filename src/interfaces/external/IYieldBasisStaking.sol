// src/interfaces/external/IYieldBasisStaking.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IYieldBasisStaking
 * @author Equilibrium Protocol
 * @notice Interface for the YieldBasis staking pool where ybBTC can be staked to
 * earn trading fees and YB token emissions.
 * This MUST be verified against the final YieldBasis ABI.
 */
interface IYieldBasisStaking {
    /**
     * @notice Stakes a given amount of ybBTC.
     * @param _amount The amount of ybBTC to stake.
     */
    function stake(uint256 _amount) external;

    /**
     * @notice Withdraws a given amount of ybBTC.
     * @param _amount The amount of ybBTC to withdraw.
     */
    function withdraw(uint256 _amount) external;

    /**
     * @notice View function to see the staked balance of an address.
     * @param _account The address to check.
     * @return The staked balance.
     */
    function balanceOf(address _account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}