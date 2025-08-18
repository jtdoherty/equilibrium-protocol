// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EquilibriumVault, IStakingPool} from "../src/EquilibriumVault.sol";
import {StrategyManager} from "../src/StrategyManager.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {MockERC20} from "./EquilibriumVault.t.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract TestStrategyManager is StrategyManager {
    uint256 public unstakedAprOverride;
    uint256 public stakedAprOverride;
    constructor(address vaultAddress) StrategyManager(vaultAddress) {}
    function setAprs(uint256 _unstaked, uint256 _staked) external {
        unstakedAprOverride = _unstaked;
        stakedAprOverride = _staked;
    }
    function getUnstakedApr() public view override returns (uint256) { return unstakedAprOverride; }
    function getStakedApr() public view override returns (uint256) { return stakedAprOverride; }
}

contract MockStakingPool is IStakingPool {
    IERC20 public immutable ybbtc;
    constructor(address ybbtcAddress) { ybbtc = IERC20(ybbtcAddress); }
    function stake(uint256 amount) external { ybbtc.transferFrom(msg.sender, address(this), amount); }
    function withdraw(uint256 amount) external { ybbtc.transfer(msg.sender, amount); }
}

contract StrategyManagerTest is Test {
    EquilibriumVault public vault;
    TestStrategyManager public manager;
    m_ybBTC public mToken;
    MockERC20 public ybbtcToken;
    MockStakingPool public stakingPool;
    address public owner = address(0x1);
    address public keeper = address(0x2);
    address public user = address(0x3);

    function setUp() public {
        ybbtcToken = new MockERC20();
        stakingPool = new MockStakingPool(address(ybbtcToken));
        vm.startPrank(owner);
        mToken = new m_ybBTC(owner);
        vault = new EquilibriumVault(address(ybbtcToken), address(mToken));
        manager = new TestStrategyManager(address(vault));
        mToken.transferOwnership(address(vault));
        vault.setStrategyManager(address(manager));
        vault.setStakingPool(address(stakingPool));
        manager.setKeeper(keeper);
        manager.setSwitchBuffer(50);
        vm.stopPrank();
        ybbtcToken.mint(user, 100 ether);
        vm.startPrank(user);
        ybbtcToken.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        vm.stopPrank();
    }

    // ... (All other test functions are unchanged) ...

    function test_Switch_StakesWhenProfitable() public {
        manager.setAprs(500, 600);
        assertEq(vault.isStaked(), false);
        vm.startPrank(keeper);
        manager.switchStrategy();
        vm.stopPrank();
        assertEq(vault.isStaked(), true, "Vault should be staked");
        assertEq(ybbtcToken.balanceOf(address(stakingPool)), 100 ether, "Staking pool should hold the ybBTC");
    }

    function test_Switch_UnstakesWhenProfitable() public {
        manager.setAprs(500, 600);
        vm.startPrank(keeper);
        manager.switchStrategy();
        vm.stopPrank();
        assertEq(vault.isStaked(), true);
        manager.setAprs(700, 500);
        vm.startPrank(keeper);
        manager.switchStrategy();
        vm.stopPrank();
        assertEq(vault.isStaked(), false, "Vault should be unstaked");
        assertEq(ybbtcToken.balanceOf(address(vault)), 100 ether, "Vault should have its ybBTC back");
    }

    function test_Switch_DoesNotStake_IfNotEnoughProfit() public {
        manager.setAprs(500, 600);
        vm.startPrank(owner);
        manager.setSwitchBuffer(150);
        vm.stopPrank();
        vm.startPrank(keeper);
        manager.switchStrategy();
        vm.stopPrank();
        assertEq(vault.isStaked(), false, "Vault should NOT be staked");
    }

    function test_Switch_RevertsIfNotKeeper() public {
        vm.startPrank(user);
        vm.expectRevert(StrategyManager.NotKeeper.selector);
        manager.switchStrategy();
        vm.stopPrank();
    }

    function test_Admin_CanSetKeeper() public {
        address newKeeper = address(0x4);
        vm.startPrank(owner);
        manager.setKeeper(newKeeper);
        vm.stopPrank();
        assertEq(manager.keeper(), newKeeper);
    }

    function test_Admin_RevertsSetKeeper_IfNotOwner() public {
        address newKeeper = address(0x4);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        manager.setKeeper(newKeeper);
        vm.stopPrank();
    }
}