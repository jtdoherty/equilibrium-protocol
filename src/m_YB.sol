// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Maximized YB (m-YB)
 * @author The Equilibrium Protocol
 * @notice This is the liquid derivative token for YB locked in the YBLocker.
 * @dev It is an Ownable ERC20, where only the YBLocker contract has minting rights.
 */
contract m_YB is ERC20, Ownable {
    constructor(address initialOwner)
        ERC20("Maximized YB", "m-YB")
        Ownable(initialOwner)
    {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}