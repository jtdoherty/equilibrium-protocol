// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

/**
 * @title EQM Token
 * @author The Equilibrium Protocol
 * @notice The native governance and incentive token for the Equilibrium Protocol.
 * This token is an ERC20 with a controlled supply, where new tokens are minted
 * according to a defined emission schedule by a designated MINTER_ROLE.
 */
contract EQM is ERC20, AccessControl {
    // Define a unique role for minters.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @notice Initializes the EQM token with a name and symbol.
     * @dev The deployer (msg.sender) is initially granted the MINTER_ROLE.
     * This role should later be transferred to the RewardDistributor contract.
     */
    constructor() ERC20("Equilibrium Token", "EQM") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @notice Creates new EQM tokens and assigns them to an address.
     * @dev Only accounts with the MINTER_ROLE can call this function.
     * @param to The address to receive the new tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // The owner of this contract (who has DEFAULT_ADMIN_ROLE) can grant/revoke
    // MINTER_ROLE to other addresses, e.g., the RewardDistributor.
}