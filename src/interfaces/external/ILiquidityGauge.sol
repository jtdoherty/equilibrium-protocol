// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol"; // LP token, YB token etc.

/**
 * @title ILiquidityGauge
 * @author Equilibrium Protocol (Interface adapted from YieldBasis LiquidityGauge.vy)
 * @notice Interface for the YieldBasis LiquidityGauge contract.
 * Used by EquilibriumVault to stake/unstake ybBTC, and by HarvestKeeper to claim YB emissions.
 */
interface ILiquidityGauge {
    // --- ERC4626 standard functions (inherited in Vyper) ---
    // We only need the deposit/withdraw/balanceOf of the LP Token from this gauge
    function deposit(uint256 assets, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function balanceOf(address account) external view returns (uint256); // balanceOf LP token in the gauge
    function lp_token() external view returns (address); // Address of the staked LP token (ybBTC)

    // --- Reward claiming specific functions ---
    function claim(IERC20 reward, address user) external returns (uint256); // To claim specific rewards (like YB)
    function preview_claim(IERC20 reward, address user) external view returns (uint256); // To preview pending rewards

    // This is the function that emits rewards from the GaugeController
    // The HarvestKeeper will need to call this to trigger YB emissions.
    // function emit() external returns (uint256); // Emits YB from GaugeController to this gauge
}