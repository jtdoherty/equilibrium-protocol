// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title MockGaugeController
 * @author Equilibrium Team
 * @notice A simplified mock for the Curve GaugeController contract.
 * It primarily provides the TOKEN() function needed by the StrategyManager.
 */
contract MockGaugeController {
    IERC20 public immutable YB_TOKEN; // The YB token controlled by this gauge controller

    constructor(address _ybTokenAddress) {
        YB_TOKEN = IERC20(_ybTokenAddress);
    }

    function TOKEN() external view returns (address) {
        return address(YB_TOKEN);
    }

    // Add any other minimal functions that might be called by the StrategyManager or other contracts
    // For now, this is sufficient for the StrategyManager's current usage.
}
