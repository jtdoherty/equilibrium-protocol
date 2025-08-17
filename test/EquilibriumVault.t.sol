// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock ybBTC", "ybBTC") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EquilibriumVaultTest is Test {
    EquilibriumVault public vault;
    m_ybBTC public mToken;
    MockERC20 public ybbtcToken;
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        ybbtcToken = new MockERC20();
        mToken = new m_ybBTC(address(this));
        vault = new EquilibriumVault(address(ybbtcToken), address(mToken));
        mToken.transferOwnership(address(vault));
        ybbtcToken.mint(user1, 1000 ether);
        ybbtcToken.mint(user2, 1000 ether);
    }

    function test_FirstDeposit_ShouldMintShares1to1() public {
        uint256 depositAmount = 100 ether;
        vm.startPrank(user1);
        ybbtcToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();
        assertEq(mToken.balanceOf(user1), depositAmount, "User1 should receive 1:1 shares");
        assertEq(ybbtcToken.balanceOf(address(vault)), depositAmount, "Vault should hold the deposited ybBTC");
        assertEq(vault.totalAssets(), depositAmount, "Vault totalAssets should equal the deposit");
    }

    function test_SecondDeposit_AfterYield_ShouldMintProportionalShares() public {
        vm.startPrank(user1);
        ybbtcToken.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        vm.stopPrank();
        ybbtcToken.mint(address(vault), 10 ether);
        assertEq(vault.totalAssets(), 110 ether);
        assertEq(mToken.totalSupply(), 100 ether);
        uint256 user2DepositAmount = 110 ether;
        vm.startPrank(user2);
        ybbtcToken.approve(address(vault), user2DepositAmount);
        vault.deposit(user2DepositAmount);
        vm.stopPrank();
        assertEq(mToken.balanceOf(user2), 100 ether, "User2 should receive 100 shares");
        assertEq(mToken.totalSupply(), 200 ether, "Total supply should be 200 shares");
        assertEq(vault.totalAssets(), 220 ether, "Total assets should be 220 ybBTC");
    }

    function test_Withdraw_ShouldReturnAssetsAndBurnShares() public {
        uint256 initialDeposit = 100 ether;
        vm.startPrank(user1);
        ybbtcToken.approve(address(vault), initialDeposit);
        vault.deposit(initialDeposit);
        vm.stopPrank();
        ybbtcToken.mint(address(vault), 10 ether);
        assertEq(vault.totalAssets(), 110 ether);
        uint256 sharesToBurn = mToken.balanceOf(user1);
        vm.startPrank(user1);
        mToken.approve(address(vault), sharesToBurn);
        vault.withdraw(sharesToBurn);
        vm.stopPrank();
        assertEq(mToken.balanceOf(user1), 0, "User1 should have 0 shares after withdraw");
        assertEq(vault.totalAssets(), 0, "Vault should have 0 assets");
        assertEq(mToken.totalSupply(), 0, "Total share supply should be 0");
        assertEq(ybbtcToken.balanceOf(user1), 1010 ether, "User1 ybBTC balance should be correct");
    }

    function test_Withdraw_RevertsIfAmountExceedsBalance() public {
        vm.startPrank(user1);
        ybbtcToken.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        vm.expectRevert();
        vault.withdraw(101 ether);
        vm.stopPrank();
    }

    function test_Deposit_RevertsIfAmountIsZero() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSelector(EquilibriumVault.ZeroAmount.selector));
        vault.deposit(0);
        vm.stopPrank();
    }
}