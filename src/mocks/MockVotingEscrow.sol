// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract MockVotingEscrow {
    address public token;
    mapping(address => uint256) public lockedAmounts;

    constructor(address _token) {
        token = _token;
    }

    // Minimal implementation to satisfy the interface
    function createLock(uint256 value, uint256 /*unlockTime*/) external {
        lockedAmounts[msg.sender] += value;
        IERC20(token).transferFrom(msg.sender, address(this), value);
    }
    function increaseAmount(uint256 value) external {
        lockedAmounts[msg.sender] += value;
        IERC20(token).transferFrom(msg.sender, address(this), value);
    }
    function increaseUnlockTime(uint256 /*unlockTime*/) external {}
}