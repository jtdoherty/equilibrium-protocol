// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// A simple mock ERC20 token for testing purposes (our fake ybBTC).
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock ybBTC", "ybBTC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EquilibriumVaultTest is Test {
    // --- State variables for our contracts ---
    EquilibriumVault public vault;
    m_ybBTC public mToken;
    MockERC20 public ybbtcToken;

    // --- State variables for our test users ---
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    /**
     * @notice This function is run before each test, setting up a clean state.
     */
     
    function setUp() public {
        // 1. Deploy our mock ybBTC token.
        ybbtcToken = new MockERC20();

        // 2. Deploy our real m_ybBTC token. The deployer (this test contract) is the initial owner.
        mToken = new m_ybBTC(address(this));

        // 3. Deploy our vault, linking the two tokens.
        vault = new EquilibriumVault(address(ybbtcToken), address(mToken));

        // 4. CRITICAL STEP: Transfer ownership of the mToken to the vault,
        // so the vault can mint and burn shares.
        mToken.transferOwnership(address(vault));

        // 5. Give our test users some mock ybBTC to deposit.
        ybbtcToken.mint(user1, 1000 ether);
        ybbtcToken.mint(user2, 1000 ether);
    }

    // --- Our First Test ---

    /**
     * @notice Tests the very first deposit into an empty vault.
     * The user should receive a 1:1 ratio of shares for their assets.
     */

    function test_FirstDeposit_ShouldMintShares1to1() public {
        uint256 depositAmount = 100 ether;

        // --- Action ---
        // We need to switch the context to `user1`. `vm.startPrank` tells Foundry
        // that all subsequent calls are coming `from` user1.
        vm.startPrank(user1);

        // User1 must first approve the vault to spend their ybBTC.
        ybbtcToken.approve(address(vault), depositAmount);

        // User1 deposits their ybBTC into the vault.
        vault.deposit(depositAmount);

        vm.stopPrank();

        // --- Assertions ---
        // Check that user1 received the correct amount of mToken shares.
        assertEq(mToken.balanceOf(user1), depositAmount, "User1 should receive 1:1 shares");

        // Check that the vault now holds the deposited ybBTC.
        assertEq(ybbtcToken.balanceOf(address(vault)), depositAmount, "Vault should hold the deposited ybBTC");

        // Check that the vault's internal accounting is correct.
        assertEq(vault.totalAssets(), depositAmount, "Vault totalAssets should equal the deposit");
    }
    
    // --- Our Second Test ---

    /**
     * @notice Tests a second deposit after the vault's assets have appreciated.
     * The second depositor should receive fewer shares, proportional to the new,
     * higher "share price".
     */

    function test_SecondDeposit_AfterYield_ShouldMintProportionalShares() public {
        // --- Setup ---
        // 1. User1 deposits 100 ybBTC, receiving 100 mToken shares (as tested before).
        vm.startPrank(user1);
        ybbtcToken.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        vm.stopPrank();

        // 2. Simulate yield. We'll just mint 10 ybBTC directly to the vault.
        // The vault's totalAssets are now 110, but total mToken supply is still 100.
        // This makes each share worth 1.1 ybBTC.
        ybbtcToken.mint(address(vault), 10 ether);

        // --- Assert Setup ---
        assertEq(vault.totalAssets(), 110 ether);
        assertEq(mToken.totalSupply(), 100 ether);

        // --- Action ---
        // 3. User2 deposits 110 ybBTC.
        // Based on our formula: shares = (110 * 100) / 110 = 100.
        uint256 user2DepositAmount = 110 ether;
        vm.startPrank(user2);
        ybbtcToken.approve(address(vault), user2DepositAmount);
        vault.deposit(user2DepositAmount);
        vm.stopPrank();

        // --- Assertions ---
        // User2 should receive exactly 100 shares for their 110 ybBTC deposit.
        assertEq(mToken.balanceOf(user2), 100 ether, "User2 should receive 100 shares");

        // Check final vault state
        assertEq(mToken.totalSupply(), 200 ether, "Total supply should be 200 shares");
        assertEq(vault.totalAssets(), 220 ether, "Total assets should be 220 ybBTC");
    }

    /**
     * @notice Tests the full withdraw flow.
     * A user deposits, the vault gains value, and the user withdraws their
     * proportional share of the appreciated assets.
     */

    function test_Withdraw_ShouldReturnAssetsAndBurnShares() public {
        // --- Setup ---
        // 1. User1 deposits 100 ybBTC.
        uint256 initialDeposit = 100 ether;
        vm.startPrank(user1);
        ybbtcToken.approve(address(vault), initialDeposit);
        vault.deposit(initialDeposit);
        vm.stopPrank();

        // 2. Simulate 10% yield. Vault's ybBTC is now 110.
        ybbtcToken.mint(address(vault), 10 ether);
        assertEq(vault.totalAssets(), 110 ether);

        // --- Action ---
        // 3. User1 decides to withdraw their entire stake.
        uint256 sharesToBurn = mToken.balanceOf(user1);
        // The expected return should be 110 ybBTC, as they own 100% of the shares.
        uint256 expectedReturn = 110 ether;

        vm.startPrank(user1);
        // User1 must approve the vault to burn their mTokens.
        mToken.approve(address(vault), sharesToBurn);
        vault.withdraw(sharesToBurn);
        vm.stopPrank();

        // --- Assertions ---
        // User1's mToken balance should be 0.
        assertEq(mToken.balanceOf(user1), 0, "User1 should have 0 shares after withdraw");

        // The vault should no longer hold any assets.
        assertEq(vault.totalAssets(), 0, "Vault should have 0 assets");

        // The total supply of shares should be 0.
        assertEq(mToken.totalSupply(), 0, "Total share supply should be 0");

        // User1 should have received their initial deposit + the yield.
        // Their total ybBTC balance should be 1000 (initial) - 100 (deposit) + 110 (withdraw) = 1010.
        assertEq(ybbtcToken.balanceOf(user1), 1010 ether, "User1 ybBTC balance should be correct");
    }
}