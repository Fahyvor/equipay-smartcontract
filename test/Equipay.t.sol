// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Equipay } from "../src/Equipay.sol";
// import { console } from "forge-std/console.sol";

contract EquipayTest is Test {
    Equipay public equipay;

    address buyer = address(1);
    address seller = address(2);
    address platformWallet = address(3);
    address owner;

    function setUp() public {
        owner = address(this);
        equipay = new Equipay(platformWallet, 200);
    }

    function testCreateEscrow() public {
        vm.prank(buyer);
        uint256 escrowId = equipay.createEscrow(seller);

        (address _buyer, address _seller,, Equipay.EscrowState state) = equipay.escrows(escrowId);
        assertEq(_buyer, buyer);
        assertEq(_seller, seller);
        assertEq(uint256(state), uint256(Equipay.EscrowState.AWAITING_PAYMENT));
    }

    function testFundEscrow() public {
        vm.deal(buyer, 1 ether);

        vm.prank(buyer);
        uint256 escrowId = equipay.createEscrow(seller);

        vm.prank(buyer);
        equipay.fundEscrow{value: 1 ether}(escrowId);

        assertEq(address(equipay).balance, 1 ether);

        (, , uint256 amount, Equipay.EscrowState state) = equipay.escrows(escrowId);
        assertEq(amount, 1 ether);
        
        assertEq(uint256(state), uint256(Equipay.EscrowState.FUNDED));
    }

    function testReleaseFunds() public {
        vm.deal(buyer, 1 ether);
        vm.deal(seller, 0);
        vm.deal(platformWallet, 0);

        vm.prank(buyer);
        uint256 escrowId = equipay.createEscrow(seller);

        vm.prank(buyer);
        equipay.fundEscrow{value: 1 ether}(escrowId);
        assertEq(address(equipay).balance, 1 ether);

        (, , uint256 amount, Equipay.EscrowState state) = equipay.escrows(escrowId);
        assertEq(amount, 1 ether);

        assertEq(uint256(state), uint256(Equipay.EscrowState.FUNDED));

        vm.prank(buyer);
        equipay.releaseFunds(escrowId);
        assertEq(address(equipay).balance, 0);

        (, , , Equipay.EscrowState newState) = equipay.escrows(escrowId);
        assertEq(uint256(newState), uint256(Equipay.EscrowState.RELEASED));
    }

    function testDispute() public {
        vm.deal(buyer, 1 ether);

        vm.prank(buyer);
        uint256 escrowId = equipay.createEscrow(seller);

        vm.prank(buyer);
        equipay.fundEscrow{value: 1 ether}(escrowId);
        assertEq(address(equipay).balance, 1 ether);

        (, , uint256 amount, Equipay.EscrowState state) = equipay.escrows(escrowId);
        assertEq(amount, 1 ether);

        assertEq(uint256(state), uint256(Equipay.EscrowState.FUNDED));

        vm.prank(buyer);
        equipay.dispute(escrowId);

        (, , , Equipay.EscrowState newState) = equipay.escrows(escrowId);
        assertEq(uint256(newState), uint256(Equipay.EscrowState.DISPUTED));
    }

    function testResolveDispute() public {
        vm.deal(buyer, 1 ether);
        vm.deal(seller, 0);
        vm.deal(platformWallet, 0);

        vm.prank(buyer);
        uint256 escrowId = equipay.createEscrow(seller);

        vm.prank(buyer);
        equipay.fundEscrow{value: 1 ether}(escrowId);
        assertEq(address(equipay).balance, 1 ether);

        (, , uint256 amount, Equipay.EscrowState state) = equipay.escrows(escrowId);
        assertEq(amount, 1 ether);

        assertEq(uint256(state), uint256(Equipay.EscrowState.FUNDED));

        vm.prank(buyer);
        equipay.dispute(escrowId);

        (, , , Equipay.EscrowState disputedState) = equipay.escrows(escrowId);
        assertEq(uint256(disputedState), uint256(Equipay.EscrowState.DISPUTED));

        // Resolve dispute in favour of seller
        vm.prank(owner);
        equipay.resolveDispute(escrowId, false);
        // equipay.resolveDispute(escrowId, true);
        assertEq(address(equipay).balance, 0);

        (, , , Equipay.EscrowState resolvedState) = equipay.escrows(escrowId);
        assertEq(uint256(resolvedState), uint256(Equipay.EscrowState.REFUNDED));
    }

    function testUpdatePlatformFee() public {
        vm.prank(owner);
        equipay.updatePlatformFee(300);

        assertEq(equipay.platformFeeBps(), 300);
    }

    function testUpdatePlatformWallet() public {
        address newPlatformWallet = address(4);
        vm.prank(owner);
        equipay.updatePlatformWallet(newPlatformWallet);

        assertEq(equipay.platformWallet(), newPlatformWallet);
    }
}