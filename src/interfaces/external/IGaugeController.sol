// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title IGaugeController
 * @author Equilibrium Protocol (Interface adapted from YieldBasis GaugeController.vy)
 * @notice Interface for the YieldBasis GaugeController contract.
 * Used by the StrategyManager to get gauge weights and emission rates.
 */
interface IGaugeController {
    function gauge_relative_weight(address gauge) external view returns (uint256);
    // The inflation rate is likely exposed via the TOKEN() contract itself or another view
    function TOKEN() external view returns (IERC20); // Gets the YB token address (GovernanceToken)

    // A function to get global inflation or some rate factor might be here.
    // Based on the source, `preview_emissions` seems to be the place to calculate future emissions.
    // Let's expose the internal `inflation_rate` of the TOKEN.
    // If TOKEN is `GovernanceToken`, it implies `GovernanceToken` has `inflation_rate()`
    // We will assume `TOKEN` has a `inflation_rate()` method, which is common.
}