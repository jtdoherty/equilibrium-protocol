// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title EquilibriumVault
 * @author The Equilibrium Protocol
 * @notice The primary user-facing contract for ybBTC deposits.
 * This vault holds all deposited ybBTC and switches them between direct
 * fee accrual (holding) and YB emission farming (staking) based on
 * commands from the StrategyManager contract.
 */
contract EquilibriumVault is Ownable {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    // The token users deposit (e.g., ybBTC). Set at deployment to prevent changes.
    IERC20 public immutable ybBTC;

    // The liquid derivative token minted to users as a receipt (m-ybBTC).
    // This vault will need the authority to mint this token.
    IERC20 public immutable m_ybBTC;

    // The address of the YieldBasis staking contract where ybBTC is sent to earn YB.
    address public ybStakingPool;

    // The "brain" contract that is allowed to trigger strategy switches.
    address public strategyManager;

    // A flag to track the vault's current strategy.
    // false = Unstaked (earning trading fees)
    // true = Staked (earning YB emissions)
    bool public isStaked;

    // --- Events ---

    event Deposit(address indexed user, uint256 ybBTC_amount, uint256 m_ybBTC_amount);
    event Withdraw(address indexed user, uint256 ybBTC_amount, uint256 m_ybBTC_amount);
    event StrategyChanged(bool isStaked);
    event StrategyManagerUpdated(address indexed newManager);
    event StakingPoolUpdated(address indexed newPool);

    // --- Errors ---

    error NotStrategyManager();
    error ZeroAmount();

    // --- Modifiers ---

    modifier onlyStrategyManager() {
        if (msg.sender != strategyManager) {
            revert NotStrategyManager();
        }
        _;
    }

    // --- Constructor ---

    constructor(address _ybBTC, address _m_ybBTC) Ownable(msg.sender) {
        ybBTC = IERC20(_ybBTC);
        m_ybBTC = IERC20(_m_ybBTC);
    }

    // --- User-Facing Functions ---

    /**
     * @notice Deposits ybBTC into the vault and mints m-ybBTC to the user.
     * @dev The exchange rate logic will be added later. For now, we can assume 1:1.
     * @param _amount The amount of ybBTC to deposit.
     */
    function deposit(uint256 _amount) external {
        // TODO: Implement deposit logic
        // 1. Check for non-zero amount.
        // 2. Calculate m-ybBTC to mint based on total assets and supply.
        // 3. Transfer ybBTC from user to this contract.
        // 4. Mint m-ybBTC to the user.
        // 5. Emit Deposit event.
    }

    /**
     * @notice Burns m-ybBTC from the user and sends back ybBTC.
     * @dev The exchange rate logic will be added later.
     * @param _m_ybBTC_amount The amount of m-ybBTC shares to redeem.
     */
    function withdraw(uint256 _m_ybBTC_amount) external {
        // TODO: Implement withdraw logic
        // 1. Check for non-zero amount.
        // 2. Calculate ybBTC to return based on share of total assets.
        // 3. Burn m-ybBTC from the user.
        // 4. Transfer ybBTC from this contract to the user.
        // 5. Emit Withdraw event.
    }

    // --- Strategy Functions (Restricted) ---

    /**
     * @notice Stakes the entire ybBTC balance of the vault into the YieldBasis pool.
     * @dev Can only be called by the StrategyManager.
     */
    function _stakePool() external onlyStrategyManager {
        // TODO: Implement staking logic
        // 1. Approve ybStakingPool to spend our ybBTC.
        // 2. Call the stake function on the ybStakingPool contract.
        // 3. Update isStaked status to true.
        // 4. Emit StrategyChanged event.
    }

    /**
     * @notice Unstakes the entire ybBTC balance of the vault from the YieldBasis pool.
     * @dev Can only be called by the StrategyManager.
     */
    function _unstakePool() external onlyStrategyManager {
        // TODO: Implement unstaking logic
        // 1. Call the withdraw/unstake function on the ybStakingPool contract.
        // 2. Update isStaked status to false.
        // 3. Emit StrategyChanged event.
    }

    // --- Admin Functions ---

    /**
     * @notice Sets the address of the StrategyManager contract.
     * @dev Only the owner (initially the deployer, later the DAO) can call this.
     */
    function setStrategyManager(address _newManager) external onlyOwner {
        strategyManager = _newManager;
        emit StrategyManagerUpdated(_newManager);
    }

    /**
     * @notice Sets the address of the ybBTC Staking Pool.
     * @dev Only the owner can call this.
     */
    function setStakingPool(address _newPool) external onlyOwner {
        ybStakingPool = _newPool;
        emit StakingPoolUpdated(_newPool);
    }
}