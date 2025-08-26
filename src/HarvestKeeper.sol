// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {KeeperCompatibleInterface} from "chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/KeeperCompatibleInterface.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IEquilibriumVault, IYBLocker, IRewardDistributor, IStrategyManager} from "./interfaces/IProtocol.sol";
import {ILiquidityGauge} from "./interfaces/external/ILiquidityGauge.sol";

/**
 * @title HarvestKeeper
 * @author Equilibrium Protocol
 * @notice This is the master orchestrator contract, triggered by Chainlink Automation.
 * It calls all other core protocol contracts in a specific sequence to execute the
 * strategy, harvest revenue, and distribute rewards.
 */
contract HarvestKeeper is KeeperCompatibleInterface, Ownable {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    uint256 public immutable interval;
    uint256 public lastUpdateTime;
    
    // External protocol tokens
    IERC20 public immutable YB_TOKEN;
    IERC20 public immutable YB_BTC_TOKEN;
    ILiquidityGauge public immutable YB_STAKING_GAUGE;

    // Internal protocol contracts
    IEquilibriumVault public immutable VAULT;
    IYBLocker public immutable YB_LOCKER;
    IRewardDistributor public immutable REWARD_DISTRIBUTOR;
    IStrategyManager public immutable STRATEGY_MANAGER;

    uint256 public eqmPerPeriod = 100 ether; // Example: Mint 100 EQM per harvest

    constructor(
        address _ybToken,
        address _ybBtcToken,
        address _ybStakingGauge,
        address _vault,
        address _ybLocker,
        address _rewardDistributor,
        address _strategyManager, // New parameter for StrategyManager
        uint256 _interval
    ) Ownable(msg.sender) {
        YB_TOKEN = IERC20(_ybToken);
        YB_BTC_TOKEN = IERC20(_ybBtcToken);
        YB_STAKING_GAUGE = ILiquidityGauge(_ybStakingGauge);
        VAULT = IEquilibriumVault(_vault);
        YB_LOCKER = IYBLocker(_ybLocker);
        REWARD_DISTRIBUTOR = IRewardDistributor(_rewardDistributor);
        STRATEGY_MANAGER = IStrategyManager(_strategyManager); // Initialize StrategyManager
        interval = _interval;
        lastUpdateTime = block.timestamp;
    }

    // --- Chainlink Automation ---
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = (block.timestamp - lastUpdateTime) > interval;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata) external override {
        if ((block.timestamp - lastUpdateTime) < interval) return;
        lastUpdateTime = block.timestamp;

        // --- THE ORCHESTRATION CHECKLIST ---

        // 0. Claim YB emissions from the gauge (this is what generates the YB for our YBLocker)
        // This also triggers internal checkpointing in the gauge.
        // Use a low-level call to bypass the 'emit' keyword conflict.
        (bool success, ) = address(YB_STAKING_GAUGE).call(abi.encodeWithSignature("emit()"));
        require(success, "Call to emit() failed");
        
        // 1. Trigger the "Brain" to optimize the vault's strategy
        STRATEGY_MANAGER.switchStrategy();

        // 2. Harvest ybBTC fees (Unstaked revenue) and send to Vault for auto-compounding
        uint256 ybBtcBalance = YB_BTC_TOKEN.balanceOf(address(this));
        if (ybBtcBalance > 0) {
            YB_BTC_TOKEN.approve(address(VAULT), ybBtcBalance);
            VAULT.compound(ybBtcBalance);
            STRATEGY_MANAGER.updateFeeData(ybBtcBalance); // Crucial: Update fee data for StrategyManager
        }

        // 3. Harvest YB emissions and send to YBLocker
        uint256 ybBalance = YB_TOKEN.balanceOf(address(this));
        if (ybBalance > 0) {
            YB_TOKEN.transfer(address(YB_LOCKER), ybBalance);
            YB_LOCKER.lock();
        }

        // 4. Distribute EQM incentives via the RewardDistributor
        REWARD_DISTRIBUTOR.distributeRewards(eqmPerPeriod);
    }

    // --- Helper functions to simulate harvesting for testing ---
    function addHarvestableYBFees(uint256 amount) external {
        YB_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
    }
    function addHarvestableBtcFees(uint256 amount) external {
        YB_BTC_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
    }
}