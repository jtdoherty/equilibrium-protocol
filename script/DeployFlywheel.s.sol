// script/DeployFlywheel.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockYBToken} from "../src/mocks/MockYBToken.sol";
import {m_YB} from "../src/m_YB.sol"; // Adjusted path
import {MockVotingEscrow} from "../src/mocks/MockVotingEscrow.sol";
import {YBLocker} from "../src/YBLocker.sol"; // Adjusted path
import {HarvestKeeper} from "../src/HarvestKeeper.sol"; // Adjusted path

contract DeployFlywheel is Script {
    function run() external returns (address keeperAddress) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // --- DEPLOYMENT ---

        console.log("1. Deploying Mocks...");
        MockYBToken ybToken = new MockYBToken();
        MockVotingEscrow votingEscrow = new MockVotingEscrow(address(ybToken));
        console.log("  - MockYBToken deployed to:", address(ybToken));
        console.log("  - MockVotingEscrow deployed to:", address(votingEscrow));
        
        console.log("2. Deploying m_YB token with deployer as temporary owner...");
        m_YB mYbToken = new m_YB(deployer);
        console.log("  - m_YB token deployed to:", address(mYbToken));

        console.log("3. Deploying YBLocker...");
        YBLocker ybLocker = new YBLocker(address(ybToken), address(votingEscrow), address(mYbToken));
        console.log("  - YBLocker deployed to:", address(ybLocker));

        // --- MODIFICATION FOR FAST TESTING ---
        console.log("4. Deploying HarvestKeeper with a 1-minute interval...");
        uint256 oneMinute = 60; // Set interval to 60 seconds
        HarvestKeeper harvestKeeper = new HarvestKeeper(address(ybToken), address(ybLocker), oneMinute);
        keeperAddress = address(harvestKeeper);
        console.log("  - HarvestKeeper deployed to:", keeperAddress);
        
        // --- CONFIGURATION ---
        console.log("--- Starting Configuration ---");

        console.log("5. Transferring m_YB ownership to YBLocker...");
        mYbToken.transferOwnership(address(ybLocker));
        console.log("  - Ownership transferred.");

        console.log("6. Transferring YBLocker ownership to HarvestKeeper...");
        ybLocker.transferOwnership(address(harvestKeeper));
        console.log("  - Ownership transferred.");

        console.log("7. Minting 1000 YB to deployer %s", deployer);
        uint256 initialMintAmount = 1000 ether;
        ybToken.mint(deployer, initialMintAmount);

        console.log("8. Approving HarvestKeeper to receive deployer's YB...");
        ybToken.approve(address(harvestKeeper), initialMintAmount);
        
        vm.stopBroadcast();
        return keeperAddress;
    }
}