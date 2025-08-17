// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Maximized ybBTC (m-ybBTC)
 * @author The Equilibrium Protocol
 * @notice This is the liquid derivative (share token) representing a user's
 * share in the EquilibriumVault.
 * It is an ERC20 token with two special properties:
 * 1. Ownable: A single owner (the EquilibriumVault) has exclusive rights to mint new tokens.
 * 2. Burnable: Allows the vault to burn tokens from users (with their approval) during withdrawal.
 */
contract m_ybBTC is ERC20, ERC20Burnable, Ownable {
    /**
     * @notice Sets up the token's name, symbol, and initial owner.
     * @param _initialOwner The address that will have minting rights at deployment.
     * This will be the deployer, who must then transfer ownership to the EquilibriumVault.
     */
    constructor(address _initialOwner)
        ERC20("Maximized ybBTC", "m-ybBTC")
        Ownable(_initialOwner)
    {}

    /**
     * @notice Creates new tokens and assigns them to an address.
     * @dev Can only be called by the contract owner (the EquilibriumVault).
     * This is the core of the vault's deposit functionality.
     * @param to The address to receive the new tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}