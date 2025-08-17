// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {m_ybBTC} from "./m_ybBTC.sol"; // Import our new contract

/**
 * @title EquilibriumVault
 * @author The Equilibrium Protocol
 * @notice The primary user-facing contract for ybBTC deposits.
 */
contract EquilibriumVault is Ownable {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    IERC20 public immutable YB_BTC;
    m_ybBTC public immutable M_YB_BTC; // Use the specific contract type
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
        M_YB_BTC = m_ybBTC(_m_ybBTC); // Cast to our specific contract type
    }

    // --- Logic ---

    function totalAssets() public view returns (uint256) {
        return YB_BTC.balanceOf(address(this)) + YB_BTC.balanceOf(ybStakingPool);
    }

    // --- User-Facing Functions ---

    function deposit(uint256 _amount) external {
        if (_amount == 0) revert ZeroAmount();

        uint256 totalShares = M_YB_BTC.totalSupply();
        uint256 totalVaultAssets = totalAssets();
        uint256 sharesToMint;

        if (totalShares == 0 || totalVaultAssets == 0) {
            sharesToMint = _amount;
        } else {
            sharesToMint = (_amount * totalShares) / totalVaultAssets;
        }

        if (sharesToMint == 0) revert ZeroAmount();

        YB_BTC.safeTransferFrom(msg.sender, address(this), _amount);

        // This call now works because our m_ybBTC contract has a public, ownable mint function.
        M_YB_BTC.mint(msg.sender, sharesToMint);

        emit Deposit(msg.sender, _amount, sharesToMint);
    }

    function withdraw(uint256 _mybbtcAmount) external {
        if (_mybbtcAmount == 0) revert ZeroAmount();

        uint256 totalShares = M_YB_BTC.totalSupply();
        uint256 totalVaultAssets = totalAssets();
        uint256 assetsToReturn = (_mybbtcAmount * totalVaultAssets) / totalShares;

        if (assetsToReturn == 0) revert ZeroAmount();

        // This requires the user to have first approved the vault.
        M_YB_BTC.burnFrom(msg.sender, _mybbtcAmount);

        YB_BTC.safeTransfer(msg.sender, assetsToReturn);

        emit Withdraw(msg.sender, assetsToReturn, _mybbtcAmount);
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