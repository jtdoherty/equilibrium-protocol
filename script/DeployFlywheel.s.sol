// script/DeployFlywheel.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
// Mocks
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockVotingEscrow} from "../src/mocks/MockVotingEscrow.sol";
import {MockLiquidityGauge} from "../src/mocks/MockLiquidityGauge.sol";
import {MockChainlinkAggregator} from "../src/mocks/MockChainlinkAggregator.sol";
import {MockGaugeController} from "../src/mocks/MockGaugeController.sol"; // Added MockGaugeController
// Tokens
import {m_YB} from "../src/m_YB.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {EQM} from "../src/EQM.sol";
// Core
import {YBLocker} from "../src/YBLocker.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
import {StrategyManager} from "../src/StrategyManager.sol";
// Economics
import {Booster} from "../src/Booster.sol";
import {RewardDistributor} from "../src/RewardDistributor.sol";
// Control
import {HarvestKeeper} from "../src/HarvestKeeper.sol";


contract DeployFlywheel is Script {
    function run() external returns (address keeperAddress) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // --- 1. DEPLOYMENT ---
        console.log("--- Deploying Contracts ---");
        // Mocks
        MockERC20 ybToken = new MockERC20("YieldBasis Token", "YB");
        MockERC20 ybBtcToken = new MockERC20("YieldBasis BTC", "ybBTC");
        MockVotingEscrow votingEscrow = new MockVotingEscrow(address(ybToken));
        MockLiquidityGauge ybStakingGauge = new MockLiquidityGauge(address(ybBtcToken), address(ybToken)); 
        MockChainlinkAggregator ybPriceFeed = new MockChainlinkAggregator(8, 1e8); // 8 decimals, initial price 1 USD
        MockGaugeController ybGaugeController = new MockGaugeController(address(ybToken)); // Deploy MockGaugeController

        // Tokens
        EQM eqmToken = new EQM(deployer);
        m_ybBTC mYbBtcToken = new m_ybBTC(deployer);
        m_YB mYbToken = new m_YB(deployer);

        // Core & Economics
        EquilibriumVault vault = new EquilibriumVault(
            address(ybBtcToken),
            address(mYbBtcToken),
            address(ybStakingGauge)
        );
        Booster booster = new Booster(address(mYbBtcToken), address(eqmToken));
        RewardDistributor rewardDistributor = new RewardDistributor(address(eqmToken)); 
        YBLocker ybLocker = new YBLocker(address(ybToken), address(votingEscrow), address(mYbToken));
        StrategyManager strategyManager = new StrategyManager(
            address(vault),
            address(ybStakingGauge),
            address(ybGaugeController), // Correctly use MockGaugeController
            address(ybPriceFeed)
        );

        // Control
        uint256 oneMinute = 60;
        HarvestKeeper harvestKeeper = new HarvestKeeper(
            address(ybToken),
            address(ybBtcToken),
            address(ybStakingGauge),
            address(vault),
            address(ybLocker),
            address(rewardDistributor),
            address(strategyManager),
            oneMinute
        );
        keeperAddress = address(harvestKeeper);
        
        // --- 2. CONFIGURATION (The Ownership Dance) ---
        console.log("--- Configuring Permissions ---");
        // Give Vault permission to mint m_ybBTC
        mYbBtcToken.transferOwnership(address(vault));
        // Give YBLocker permission to mint m_YB
        mYbToken.transferOwnership(address(ybLocker));
        // Give Booster permission to receive EQM from RewardDistributor
        rewardDistributor.setBooster(address(booster));
        // Give RewardDistributor permission to mint EQM
        eqmToken.transferOwnership(address(rewardDistributor));
        // Set StrategyManager in the Vault
        vault.setManager(address(strategyManager));
        
        // Give Keeper full control over other contracts
        vault.transferOwnership(address(harvestKeeper));
        ybLocker.transferOwnership(address(harvestKeeper));
        rewardDistributor.transferOwnership(address(harvestKeeper));
        strategyManager.transferOwnership(address(harvestKeeper));

        // --- 3. MINT MOCK TOKENS FOR TESTING ---
        ybBtcToken.mint(deployer, 1000 ether);
        ybToken.mint(address(ybStakingGauge), 100 ether); // Mint some YB into the gauge as initial rewards
        
        vm.stopBroadcast();
        return keeperAddress;
    }
}
