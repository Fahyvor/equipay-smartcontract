// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Equipay.sol";
import "forge-std/console.sol";

contract EquipayTest is Test {
    Equipay public equipay;

    address public alice;
    address public bob;
    address[] payees;
    uint256[] shares;

    function setUp() public {
        alice = address(0x1);
        bob = address(0x2);

        payees.push(alice);
        payees.push(bob);

        shares.push(60);
        shares.push(40);

        equipay = new Equipay(payees, shares);
    }

    function testConstructorSetsValuesCorrectly() public view {
        (address[] memory _payees, uint256[] memory _shares) = equipay.getPayees();
        assertEq(_payees.length, 2);
        assertEq(_payees[0], alice);
        assertEq(_payees[1], bob);
        assertEq(_shares[0], 60);
        assertEq(_shares[1], 40);
    }

    function testSplitFundsCorrectly() public {
        // Send ETH to contract from this test contract
        (bool sent, ) = address(equipay).call{value: 1 ether}("");
        require(sent, "ETH not sent");

        equipay.split();

        assertEq(alice.balance, 0.6 ether);
        assertEq(bob.balance, 0.4 ether);
    }

    function testReceiveTriggerSplit() public {
        console.log("Alice balance:", alice.balance);
        console.log("Bob balance:", bob.balance);
        // Send ETH to contract, which should trigger receive() and then split()
        (bool sent, ) = address(equipay).call{value: 1 ether}("");
        require(sent, "ETH not sent");

        // If split is called in receive(), this should be enough
        assertEq(alice.balance, 0.6 ether);
        assertEq(bob.balance, 0.4 ether);
    }


}