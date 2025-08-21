// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// --- NO LONGER BURNABLE ---
// The vault does not burn tokens anymore. Burning happens implicitly when
// tokens are sold into a liquidity pool.
contract m_ybBTC is ERC20, Ownable {
    constructor(address _initialOwner)
        ERC20("Maximized ybBTC", "m-ybBTC")
        Ownable(_initialOwner)
    {}

    // The EquilibriumVault should be the owner of this contract.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}