// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockChainlinkAggregator
 * @author Equilibrium Team
 * @notice A mock for the Chainlink V3 Aggregator interface.
 * Allows setting a mock price answer for testing contracts that rely on price feeds.
 */
contract MockChainlinkAggregator {
    uint8 public decimals;
    int256 public latestAnswer;

    constructor(uint8 _decimals, int256 _initialAnswer) {
        decimals = _decimals;
        latestAnswer = _initialAnswer;
    }

    /**
     * @notice Mocks the Chainlink latestRoundData function.
     * Returns a fixed answer set by the test setup.
     */
    function latestRoundData()
        external
        view
        returns (
            uint80, // roundId
            int256, // answer
            uint256, // startedAt
            uint256, // updatedAt
            uint80 // answeredInRound
        )
    {
        return (1, latestAnswer, block.timestamp, block.timestamp, 1);
    }

    /**
     * @notice Test-only function to update the mock price.
     * @param _newAnswer The new price to be returned by the oracle.
     */
    function updateAnswer(int256 _newAnswer) external {
        latestAnswer = _newAnswer;
    }
}
