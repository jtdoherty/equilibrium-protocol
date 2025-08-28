// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockLiquidityGauge} from "../src/mocks/MockLiquidityGauge.sol";
import {MockChainlinkAggregator} from "../src/mocks/MockChainlinkAggregator.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {StrategyManager} from "../src/StrategyManager.sol";

contract EquilibriumVaultTest is Test {
    MockERC20 public ybBTC;
    MockERC20 public YB_TOKEN;
    m_ybBTC public mYBBTC;
    EquilibriumVault public vault;
    MockLiquidityGauge public ybStakingGauge;
    StrategyManager public strategyManager;
    MockChainlinkAggregator public ybPriceFeed;

    address public deployer;
    address public user;

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");

        // Deploy Mock tokens
        ybBTC = new MockERC20("YieldBasis BTC", "ybBTC");
        YB_TOKEN = new MockERC20("YieldBasis Token", "YB");
        
        // Deploy Mock Liquidity Gauge (stakingToken: ybBTC, rewardToken: YB_TOKEN)
        ybStakingGauge = new MockLiquidityGauge(address(ybBTC), address(YB_TOKEN));

        // Deploy m_ybBTC token with deployer as initial owner
        mYBBTC = new m_ybBTC(deployer);

        // Deploy Mock Chainlink Aggregator
        ybPriceFeed = new MockChainlinkAggregator(8, 1e8); // 8 decimals, initial price 1 USD

        // Set deployer as the sender for deploying vault and setting manager
        vm.startPrank(deployer);

        // Deploy the vault with all required addresses
        // Since Ownable(msg.sender) is used, deployer will be the owner.
        vault = new EquilibriumVault(address(ybBTC), address(mYBBTC), address(ybStakingGauge));

        // Deploy StrategyManager
        strategyManager = new StrategyManager(
            address(vault),
            address(ybStakingGauge),
            address(YB_TOKEN), // Placeholder for YB_GAUGE_CONTROLLER for now, using YB_TOKEN address
            address(ybPriceFeed)
        );

        // Transfer ownership of mYBBTC to the vault so it can mint
        mYBBTC.transferOwnership(address(vault));
        // Set the StrategyManager in the Vault (now deployer is the owner of vault)
        vault.setManager(address(strategyManager));
        
        vm.stopPrank(); // Stop pranking as deployer

        // Mint some ybBTC for the user (user is not deployer)
        ybBTC.mint(user, 1000e18);
    }

    function testDepositYbBTC() public {
        uint256 depositAmount = 100e18;

        // User approves the vault to spend ybBTC
        vm.startPrank(user);
        ybBTC.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();

        // Check user's m_ybBTC balance
        assertEq(mYBBTC.balanceOf(user), depositAmount, "User should receive m-ybBTC equal to deposit");

        // Check vault's ybBTC balance
        assertEq(ybBTC.balanceOf(address(vault)), depositAmount, "Vault should hold deposited ybBTC");

        // Check user's ybBTC balance
        assertEq(ybBTC.balanceOf(user), 900e18, "User's ybBTC balance should decrease");
    }

    function testWithdrawYbBTC() public {
        uint256 depositAmount = 100e18;
        uint256 withdrawAmount = 50e18;

        // First, deposit some ybBTC
        vm.startPrank(user);
        ybBTC.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();

        // Assert initial state after deposit for clarity
        assertEq(mYBBTC.balanceOf(user), depositAmount, "User should have m-ybBTC after deposit");
        assertEq(ybBTC.balanceOf(address(vault)), depositAmount, "Vault should hold ybBTC after deposit");
        assertEq(ybBTC.balanceOf(user), 900e18, "User ybBTC balance correct after deposit");

        // Now, withdraw a portion
        vm.startPrank(user);
        mYBBTC.approve(address(vault), withdrawAmount); // Approve vault to burn m-ybBTC (or transfer for burning placeholder)
        vault.withdraw(withdrawAmount);
        vm.stopPrank();

        // Check user's m_ybBTC balance after withdrawal
        assertEq(mYBBTC.balanceOf(user), depositAmount - withdrawAmount, "User's m-ybBTC should decrease after withdrawal");

        // Check vault's ybBTC balance after withdrawal
        assertEq(ybBTC.balanceOf(address(vault)), depositAmount - withdrawAmount, "Vault's ybBTC should decrease after withdrawal");

        // Check user's ybBTC balance after withdrawal
        assertEq(ybBTC.balanceOf(user), 900e18 + withdrawAmount, "User's ybBTC should increase after withdrawal");
    }
}
