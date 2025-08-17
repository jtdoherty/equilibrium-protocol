// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol"; // Using the implementation for totalSupply

/**
 * @title EquilibriumVault
 * @author The Equilibrium Protocol
 * @notice The primary user-facing contract for ybBTC deposits.
 */
contract EquilibriumVault is Ownable {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    IERC20 public immutable YB_BTC;
    ERC20 public immutable M_YB_BTC; // Changed to ERC20 to access totalSupply()
    address public ybStakingPool;
    address public strategyManager;
    bool public isStaked;

    // --- Events ---

    event Deposit(address indexed user, uint256 ybbtcAmount, uint256 mybbtcAmount);
    event Withdraw(address indexed user, uint256 ybbtcAmount, uint256 mybbtcAmount);
    event StrategyChanged(bool isStaked);
    event StrategyManagerUpdated(address indexed newManager);
    event StakingPoolUpdated(address indexed newPool);

    // --- Errors ---

    error NotStrategyManager();
    error ZeroAmount();

    // --- Modifiers ---

    modifier onlyStrategyManager() {
        if (msg.sender != strategyManager) revert NotStrategyManager();
        _;
    }

    // --- Constructor ---

    constructor(address _ybBTC, address _m_ybBTC) Ownable(msg.sender) {
        YB_BTC = IERC20(_ybBTC);
        M_YB_BTC = ERC20(_m_ybBTC);
    }

    // --- Logic ---

    /**
     * @notice Calculates the total amount of ybBTC managed by this vault.
     * @dev This includes the ybBTC held in this contract plus any ybBTC staked in the pool.
     */
    function totalAssets() public view returns (uint256) {
        // Balance of this contract + Balance staked in the pool
        return YB_BTC.balanceOf(address(this)) + YB_BTC.balanceOf(ybStakingPool);
    }

    // --- User-Facing Functions ---

    function deposit(uint256 _amount) external {
        // TODO: Implement deposit logic
    }

    function withdraw(uint256 _mybbtcAmount) external {
        // TODO: Implement withdraw logic
    }

    // --- Strategy Functions (Restricted) ---

    function _stakePool() external onlyStrategyManager {
        // TODO: Implement staking logic
    }

    function _unstakePool() external onlyStrategyManager {
        // TODO: Implement unstaking logic
    }

    // --- Admin Functions ---

    function setStrategyManager(address _newManager) external onlyOwner {
        strategyManager = _newManager;
        emit StrategyManagerUpdated(_newManager);
    }

    function setStakingPool(address _newPool) external onlyOwner {
        ybStakingPool = _newPool;
        emit StakingPoolUpdated(_newPool);
    }
}