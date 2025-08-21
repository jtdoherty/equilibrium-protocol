// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
import {StrategyManager, IYieldBasisStakingPool, IYieldBasisRewards} from "../src/StrategyManager.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {MockERC20} from "./EquilibriumVault.t.sol";

// --- MOCK CONTRACTS ---

contract MockStakingPool is IYieldBasisStakingPool {
    mapping(address => uint256) public balances;
    uint256 public totalStaked;
    IERC20 public immutable YBBTC_TOKEN;

    constructor(address ybbtcAddress) {
        YBBTC_TOKEN = IERC20(ybbtcAddress);
    }

    function stake(uint256 amount) external {
        // FIX: Check return value of transferFrom
        require(YBBTC_TOKEN.transferFrom(msg.sender, address(this), amount), "Mock stake failed");
        balances[msg.sender] += amount;
        totalStaked += amount;
    }

    function withdraw(uint256 amount) external {
        balances[msg.sender] -= amount;
        totalStaked -= amount;
        // FIX: Check return value of transfer
        require(YBBTC_TOKEN.transfer(msg.sender, amount), "Mock withdraw failed");
    }
    
    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

    function totalAssets() external view override returns (uint256) {
        return totalStaked;
    }
}

contract MockRewardsProvider is IYieldBasisRewards {
    uint256 public yearlyRewards;

    function setYearlyRewards(uint256 _rewards) external {
        yearlyRewards = _rewards;
    }

    function totalYearlyRewards() external view override returns (uint256) {
        return yearlyRewards;
    }
}


// --- TEST SUITE ---
contract StrategyManagerTest is Test {
    // ... (declarations are the same)
    EquilibriumVault public vault;
    StrategyManager public strategyManager;
    m_ybBTC public mToken;
    MockERC20 public ybbtcToken;
    MockStakingPool public mockStakingPool;
    MockRewardsProvider public mockRewardsProvider;
    address public owner = address(0x1);
    address public keeper = address(0x2);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(owner);
        ybbtcToken = new MockERC20("Mock ybBTC", "ybBTC");
        mockStakingPool = new MockStakingPool(address(ybbtcToken));
        mockRewardsProvider = new MockRewardsProvider();
        mToken = new m_ybBTC(owner);
        vault = new EquilibriumVault(address(ybbtcToken), address(mToken));
        strategyManager = new StrategyManager(address(vault), address(mockRewardsProvider));
        mToken.transferOwnership(address(vault));
        vault.setStakingPool(address(mockStakingPool));
        vault.setStrategyManager(address(strategyManager));
        strategyManager.setKeeper(keeper);
        vm.stopPrank();

        ybbtcToken.mint(user, 100 ether);
        vm.startPrank(user);
        ybbtcToken.approve(address(vault), 100 ether);
        vault.deposit(100 ether);
        // --- FIX: Stop the user prank to prevent it leaking into tests ---
        vm.stopPrank();
    }

    // --- These tests will now pass correctly ---
    function test_Rebalance_StakesAllWhenStakedAPRAboveUnstaked() public {
        mockRewardsProvider.setYearlyRewards(10 ether); 
        vm.prank(keeper);
        strategyManager.rebalance();
        assertEq(mockStakingPool.balanceOf(address(vault)), 100 ether);
        assertEq(ybbtcToken.balanceOf(address(vault)), 0);
    }

    function test_Rebalance_UnstakesAllWhenUnstakedAPRIsHigher() public {
        mockRewardsProvider.setYearlyRewards(10 ether);
        vm.prank(keeper);
        strategyManager.rebalance();
        assertEq(mockStakingPool.balanceOf(address(vault)), 100 ether); // Verify it's staked first

        mockRewardsProvider.setYearlyRewards(0);
        vm.prank(keeper);
        strategyManager.rebalance();
        assertEq(mockStakingPool.balanceOf(address(vault)), 0);
        assertEq(ybbtcToken.balanceOf(address(vault)), 100 ether);
    }

    function test_Rebalance_FindsEquilibriumAndStakesPartialAmount() public {
        mockRewardsProvider.setYearlyRewards(3 ether);
        vm.prank(keeper);
        strategyManager.rebalance();
        assertEq(mockStakingPool.balanceOf(address(vault)), 50 ether, "Vault should have staked 50 ether");
        assertEq(ybbtcToken.balanceOf(address(vault)), 50 ether, "Vault should have 50 liquid ybBTC");
    }

    function test_Rebalance_RevertsIfNotCalledByKeeper() public {
        vm.prank(user);
        vm.expectRevert("StrategyManager: Caller is not the keeper");
        strategyManager.rebalance();
    }
}