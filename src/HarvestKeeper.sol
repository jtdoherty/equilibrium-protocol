// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {KeeperCompatibleInterface} from "chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/KeeperCompatibleInterface.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {YBLocker} from "../src/YBLocker.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
import {RewardDistributor} from "../src/RewardDistributor.sol";

contract HarvestKeeper is KeeperCompatibleInterface, Ownable {
    uint256 public immutable interval;
    uint256 public lastTimeStamp;
    
    IERC20 public immutable YB_TOKEN;
    IERC20 public immutable YB_BTC_TOKEN;
    YBLocker public immutable YB_LOCKER;
    EquilibriumVault public immutable VAULT;
    RewardDistributor public immutable REWARD_DISTRIBUTOR;

    uint256 public constant EQM_PER_PERIOD = 100 ether; // Mint 100 EQM per harvest

    constructor(
        address _ybToken,
        address _ybBtcToken,
        address _ybLocker,
        address _vault,
        address _rewardDistributor,
        uint256 _interval
    ) Ownable(msg.sender) {
        YB_TOKEN = IERC20(_ybToken);
        YB_BTC_TOKEN = IERC20(_ybBtcToken);
        YB_LOCKER = YBLocker(_ybLocker);
        VAULT = EquilibriumVault(_vault);
        REWARD_DISTRIBUTOR = RewardDistributor(_rewardDistributor);
        interval = _interval;
        lastTimeStamp = block.timestamp;
    }

    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata) external override {
        if ((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            
            // --- OPTION A LOGIC ---

            // 1. Harvest ybBTC fees and send to Vault for auto-compounding
            uint256 ybBtcBalance = YB_BTC_TOKEN.balanceOf(address(this));
            if (ybBtcBalance > 0) {
                YB_BTC_TOKEN.approve(address(VAULT), ybBtcBalance);
                VAULT.compoundRewards(ybBtcBalance);
            }

            // 2. Harvest YB emissions and send to YBLocker
            uint256 ybBalance = YB_TOKEN.balanceOf(address(this));
            if (ybBalance > 0) {
                YB_TOKEN.transfer(address(YB_LOCKER), ybBalance);
                YB_LOCKER.lock();
            }

            // 3. Distribute EQM incentives to the Booster
            REWARD_DISTRIBUTOR.distributeRewards(EQM_PER_PERIOD);
        }
    }

    // Helper functions to simulate harvesting
    function addHarvestableYBFees(uint256 amount) external {
        YB_TOKEN.transferFrom(msg.sender, address(this), amount);
    }
    function addHarvestableBtcFees(uint256 amount) external {
        YB_BTC_TOKEN.transferFrom(msg.sender, address(this), amount);
    }
}