// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { Payel } from "../src/Payel.sol";
// import { console } from "forge-std/console.sol";

contract PayelTest is Test {
    Payel public payel;

    address buyer = address(1);
    address seller = address(2);
    address platformWallet = address(3);
    address owner;

    function setUp() public {
        owner = address(this);
        payel = new Payel(platformWallet, 200);
    }

    function testCreateEscrow() public {
        vm.prank(buyer);
        uint256 escrowId = payel.createEscrow(seller);

        (address _buyer, address _seller,, Payel.EscrowState state) = payel.escrows(escrowId);
        assertEq(_buyer, buyer);
        assertEq(_seller, seller);
        assertEq(uint256(state), uint256(Payel.EscrowState.AWAITING_PAYMENT));
    }

    function testFundEscrow() public {
        vm.deal(buyer, 1 ether);

        vm.prank(buyer);
        uint256 escrowId = payel.createEscrow(seller);

        vm.prank(buyer);
        payel.fundEscrow{value: 1 ether}(escrowId);

        assertEq(address(payel).balance, 1 ether);

        (, , uint256 amount, Payel.EscrowState state) = payel.escrows(escrowId);
        assertEq(amount, 1 ether);
        
        assertEq(uint256(state), uint256(Payel.EscrowState.FUNDED));
    }

    function testReleaseFunds() public {
        vm.deal(buyer, 1 ether);
        vm.deal(seller, 0);
        vm.deal(platformWallet, 0);

        vm.prank(buyer);
        uint256 escrowId = payel.createEscrow(seller);

        vm.prank(buyer);
        payel.fundEscrow{value: 1 ether}(escrowId);
        assertEq(address(payel).balance, 1 ether);

        (, , uint256 amount, Payel.EscrowState state) = payel.escrows(escrowId);
        assertEq(amount, 1 ether);

        assertEq(uint256(state), uint256(Payel.EscrowState.FUNDED));

        vm.prank(buyer);
        payel.releaseFunds(escrowId);
        assertEq(address(payel).balance, 0);

        (, , , Payel.EscrowState newState) = payel.escrows(escrowId);
        assertEq(uint256(newState), uint256(Payel.EscrowState.RELEASED));
    }

    function testDispute() public {
        vm.deal(buyer, 1 ether);

        vm.prank(buyer);
        uint256 escrowId = payel.createEscrow(seller);

        vm.prank(buyer);
        payel.fundEscrow{value: 1 ether}(escrowId);
        assertEq(address(payel).balance, 1 ether);

        (, , uint256 amount, Payel.EscrowState state) = payel.escrows(escrowId);
        assertEq(amount, 1 ether);

        assertEq(uint256(state), uint256(Payel.EscrowState.FUNDED));

        vm.prank(buyer);
        payel.dispute(escrowId);

        (, , , Payel.EscrowState newState) = payel.escrows(escrowId);
        assertEq(uint256(newState), uint256(Payel.EscrowState.DISPUTED));
    }

    function testResolveDispute() public {
        vm.deal(buyer, 1 ether);
        vm.deal(seller, 0);
        vm.deal(platformWallet, 0);

        vm.prank(buyer);
        uint256 escrowId = payel.createEscrow(seller);

        vm.prank(buyer);
        payel.fundEscrow{value: 1 ether}(escrowId);
        assertEq(address(payel).balance, 1 ether);

        (, , uint256 amount, Payel.EscrowState state) = payel.escrows(escrowId);
        assertEq(amount, 1 ether);

        assertEq(uint256(state), uint256(Payel.EscrowState.FUNDED));

        vm.prank(buyer);
        payel.dispute(escrowId);

        (, , , Payel.EscrowState disputedState) = payel.escrows(escrowId);
        assertEq(uint256(disputedState), uint256(Payel.EscrowState.DISPUTED));

        // Resolve dispute in favour of seller
        vm.prank(owner);
        payel.resolveDispute(escrowId, false);
        // payel.resolveDispute(escrowId, true);
        assertEq(address(payel).balance, 0);

        (, , , Payel.EscrowState resolvedState) = payel.escrows(escrowId);
        assertEq(uint256(resolvedState), uint256(Payel.EscrowState.REFUNDED));
    }

    function testUpdatePlatformFee() public {
        vm.prank(owner);
        payel.updatePlatformFee(300);

        assertEq(payel.platformFeeBps(), 300);
    }

    function testUpdatePlatformWallet() public {
        address newPlatformWallet = address(4);
        vm.prank(owner);
        payel.updatePlatformWallet(newPlatformWallet);

        assertEq(payel.platformWallet(), newPlatformWallet);
    }
}