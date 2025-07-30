// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Equipay
/// @notice Accepts AVAX and auto-splits to stakeholders on payment
contract Equipay {
    address public owner;
    address[] public payees;
    uint256[] public shares;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address[] memory _payees, uint256[] memory _shares) {
        require(_payees.length == _shares.length, "Mismatch in payees and shares");
        uint256 totalShares;

        for (uint256 i = 0; i < _shares.length; i++) {
            totalShares += _shares[i];
        }

        require(totalShares == 100, "Shares must sum to 100");
        owner = msg.sender;
        payees = _payees;
        shares = _shares;
    }

    receive() external payable {
        split();
    }

    function split() public payable {
        require(msg.value > 0, "No payment");
        uint256 total = msg.value;

        for (uint256 i = 0; i < payees.length; i++) {
            uint256 amount = (total * shares[i]) / 100;
            payable(payees[i]).transfer(amount);
        }
    }

    function updateShares(address[] memory _newPayees, uint256[] memory _newShares) external onlyOwner {
        require(_newPayees.length == _newShares.length, "Mismatch");
        uint256 total;
        for (uint256 i = 0; i < _newShares.length; i++) {
            total += _newShares[i];
        }
        require(total == 100, "Shares must sum to 100");

        payees = _newPayees;
        shares = _newShares;
    }

    function getPayees() external view returns (address[] memory, uint256[] memory) {
        return (payees, shares);
    }
}
