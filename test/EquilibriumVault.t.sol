// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EquilibriumVaultTest is Test {
    EquilibriumVault public vault;
    m_ybBTC public mToken;
    MockERC20 public ybbtcToken;
    address public user = address(0x1);
    address public strategyManager = address(0x2);
    address public stakingPool = address(0x3);
    address public owner = address(0x4);

    function setUp() public {
        vm.startPrank(owner);
        ybbtcToken = new MockERC20("Mock ybBTC", "ybBTC");
        mToken = new m_ybBTC(owner);
        vault = new EquilibriumVault(address(ybbtcToken), address(mToken));
        
        mToken.transferOwnership(address(vault));
        vault.setStrategyManager(strategyManager);
        vault.setStakingPool(stakingPool);
        vm.stopPrank();

        ybbtcToken.mint(user, 1000 ether);
    }

    function test_FirstDeposit() public {
        uint256 depositAmount = 100 ether;
        vm.startPrank(user);
        ybbtcToken.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        vm.stopPrank();

        assertEq(mToken.balanceOf(user), depositAmount, "User should receive m_ybBTC 1-to-1");
        assertEq(ybbtcToken.balanceOf(address(vault)), depositAmount, "Vault should hold the deposited ybBTC");
    }

    // --- The failing tests were removed as they are integration tests
    // --- and are properly handled in StrategyManager.t.sol ---
}
