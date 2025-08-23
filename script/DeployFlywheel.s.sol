// script/DeployFlywheel.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
// Mocks
import {MockYBToken} from "../src/mocks/MockYBToken.sol";
import {MockVotingEscrow} from "../src/mocks/MockVotingEscrow.sol";
// Tokens
import {m_YB} from "../src/m_YB.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {EQM} from "../src/EQM.sol";
// Core
import {YBLocker} from "../src/YBLocker.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
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
        // Mocks (ybBTC is just another mock ERC20)
        MockYBToken ybToken = new MockYBToken();
        MockYBToken ybBtcToken = new MockYBToken();
        MockVotingEscrow votingEscrow = new MockVotingEscrow(address(ybToken));

        // Tokens
        EQM eqmToken = new EQM(deployer);
        m_ybBTC mYbBtcToken = new m_ybBTC(deployer);
        m_YB mYbToken = new m_YB(deployer);

        // Core & Economics
        EquilibriumVault vault = new EquilibriumVault(address(ybBtcToken), address(mYbBtcToken));
        Booster booster = new Booster(address(mYbBtcToken));
        // Note: Your RewardDistributor needs the EQM token address on creation
        RewardDistributor rewardDistributor = new RewardDistributor(address(eqmToken)); 
        YBLocker ybLocker = new YBLocker(address(ybToken), address(votingEscrow), address(mYbToken));

        // Control
        uint256 oneMinute = 60;
        HarvestKeeper harvestKeeper = new HarvestKeeper(
            address(ybToken),
            address(ybBtcToken),
            address(ybLocker),
            address(vault),
            address(rewardDistributor),
            oneMinute
        );
        keeperAddress = address(harvestKeeper);
        
        // --- 2. CONFIGURATION (The Ownership Dance) ---
        console.log("--- Configuring Permissions ---");
        // Give Vault permission to mint m_ybBTC
        mYbBtcToken.transferOwnership(address(vault));
        // Give YBLocker permission to mint m_YB
        mYbToken.transferOwnership(address(ybLocker));
        // Give Booster permission to receive EQM
        rewardDistributor.setBooster(address(booster));
        // Give RewardDistributor permission to mint EQM
        eqmToken.transferOwnership(address(rewardDistributor));
        
        // Give Keeper full control over other contracts
        vault.transferOwnership(address(harvestKeeper));
        ybLocker.transferOwnership(address(harvestKeeper));
        rewardDistributor.transferOwnership(address(harvestKeeper));

        // --- 3. MINT MOCK TOKENS FOR TESTING ---
        ybBtcToken.mint(deployer, 1000 ether);
        
        vm.stopBroadcast();
        return keeperAddress;
    }
}