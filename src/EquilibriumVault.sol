// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";

contract EquilibriumVault is Ownable {
    IERC20 public immutable YB_BTC;
    m_ybBTC public immutable M_YB_BTC;

    // In a real vault, this would be a complex calculation.
    // For our test, we'll keep it simple: 1 ybBTC = 1 m_ybBTC.
    constructor(address _ybBtcAddress, address _mYbbBtcAddress) Ownable(msg.sender) {
        YB_BTC = IERC20(_ybBtcAddress);
        M_YB_BTC = m_ybBTC(_mYbbBtcAddress);
    }

    function deposit(uint256 _amount) external {
        YB_BTC.transferFrom(msg.sender, address(this), _amount);
        M_YB_BTC.mint(msg.sender, _amount);
    }

    // This function will be called by our keeper to auto-compound rewards.
    function compoundRewards(uint256 _amount) external onlyOwner {
        YB_BTC.transferFrom(msg.sender, address(this), _amount);
    }
}