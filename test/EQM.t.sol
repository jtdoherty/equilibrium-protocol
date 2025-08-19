// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {EQM} from "../src/EQM.sol";
// --- The import below caused the error. It's now removed. ---
// import {AccessControlUnauthorizedAccount} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";


contract EQMTest is Test {
    EQM public eqm;
    address public deployer = address(0x1);
    address public minter = address(0x2);
    address public user = address(0x3);

    function setUp() public {
        vm.startPrank(deployer);
        eqm = new EQM();
        vm.stopPrank();
    }

    function test_DeployerCanMint() public {
        uint256 mintAmount = 1000 ether;
        vm.startPrank(deployer);
        eqm.mint(user, mintAmount);
        vm.stopPrank();
        assertEq(eqm.balanceOf(user), mintAmount, "Deployer should be able to mint to user");
        assertEq(eqm.totalSupply(), mintAmount, "Total supply should be correct after minting");
    }

    function test_NonMinterCannotMint() public {
        uint256 mintAmount = 1000 ether;
        vm.startPrank(user);
        // --- CORRECTED: Using the manually calculated selector ---
        bytes4 unauthorizedSelector = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.expectRevert(abi.encodeWithSelector(unauthorizedSelector, user, eqm.MINTER_ROLE()));
        eqm.mint(user, mintAmount);
        vm.stopPrank();
    }

    function test_GrantMinterRole() public {
        uint256 mintAmount = 500 ether;
        vm.startPrank(deployer);
        eqm.grantRole(eqm.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
        eqm.mint(user, mintAmount);
        vm.stopPrank();
        assertEq(eqm.balanceOf(user), mintAmount, "New minter should be able to mint");
        assertEq(eqm.totalSupply(), mintAmount, "Total supply should reflect new mint");
    }

    function test_RevokeMinterRole() public {
        uint256 initialMint = 100 ether;
        uint256 secondMint = 50 ether;
        vm.startPrank(deployer);
        eqm.grantRole(eqm.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
        eqm.mint(user, initialMint);
        vm.stopPrank();
        assertEq(eqm.balanceOf(user), initialMint);
        vm.startPrank(deployer);
        eqm.revokeRole(eqm.MINTER_ROLE(), minter);
        vm.stopPrank();
        vm.startPrank(minter);
        // --- CORRECTED: Using the manually calculated selector ---
        bytes4 unauthorizedSelector = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.expectRevert(abi.encodeWithSelector(unauthorizedSelector, minter, eqm.MINTER_ROLE()));
        eqm.mint(user, secondMint);
        vm.stopPrank();
        assertEq(eqm.balanceOf(user), initialMint, "User balance should not change after revocation");
    }
}