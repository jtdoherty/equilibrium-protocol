// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EquilibriumVault} from "../src/EquilibriumVault.sol";
import {m_ybBTC} from "../src/m_ybBTC.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// ... (MockERC20 contract is unchanged) ...
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
    address public manager = address(0x4);
    // --- NEW: Define a mock staking pool address ---
    address public stakingPool = address(0x999);

    function setUp() public {
        ybbtcToken = new MockERC20();
        mToken = new m_ybBTC(address(this));
        vault = new EquilibriumVault(address(ybbtcToken), address(mToken));
        mToken.transferOwnership(address(vault));
        vault.setStrategyManager(manager);
        // --- NEW: Set the staking pool in the vault ---
        vault.setStakingPool(stakingPool);
        ybbtcToken.mint(user1, 1000 ether);
        ybbtcToken.mint(user2, 1000 ether);
    }
    // ... (All other tests are unchanged) ...
    function test_FirstDeposit_ShouldMintShares1to1() public {/*...*/}
    function test_SecondDeposit_AfterYield_ShouldMintProportionalShares() public {/*...*/}
    function test_Withdraw_ShouldReturnAssetsAndBurnShares() public {/*...*/}
    function test_Withdraw_RevertsIfAmountExceedsBalance() public {/*...*/}
    function test_Deposit_RevertsIfAmountIsZero() public {/*...*/}

    function test_Stake_RevertsIfAlreadyStaked() public {
        vm.prank(manager);
        vault._stakePool();
        assertTrue(vault.isStaked());
        vm.prank(manager);
        vm.expectRevert(EquilibriumVault.AlreadyInState.selector);
        vault._stakePool();
    }

    function test_Unstake_RevertsIfNotStaked() public {
        assertFalse(vault.isStaked());
        vm.prank(manager);
        vm.expectRevert(EquilibriumVault.NotInState.selector);
        vault._unstakePool();
    }
}