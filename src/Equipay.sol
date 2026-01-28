// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title EquipayEscrow
/// @notice Trustless P2P escrow with platform fees
contract Equipay {
    address public owner;
    address public platformWallet;

    uint256 public platformFeeBps;
    uint256 public constant MAX_BPS = 10_000;

    enum EscrowState {
        AWAITING_PAYMENT,
        FUNDED,
        RELEASED,
        REFUNDED,
        DISPUTED
    }

    struct Escrow {
        address buyer;
        address seller;
        uint256 amount;
        EscrowState state;
    }

    uint256 public escrowCount;
    mapping(uint256 => Escrow) public escrows;

    /* ========== ERRORS ========== */
    error NotOwner();
    error NotBuyer();
    error InvalidState();
    error InvalidAmount();

    /* ========== EVENTS ========== */
    event EscrowCreated(uint256 indexed escrowId, address buyer, address seller);
    event EscrowFunded(uint256 indexed escrowId, uint256 amount);
    event EscrowReleased(uint256 indexed escrowId, uint256 sellerAmount, uint256 platformFee);
    event EscrowRefunded(uint256 indexed escrowId);
    event EscrowDisputed(uint256 indexed escrowId);
    event PlatformFeeBpsUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event PlatformWalletUpdated(address oldWallet, address newWallet);

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }
    function _onlyOwner() internal view {
        if (msg.sender != owner) revert NotOwner();
    }

    modifier onlyBuyer(uint256 escrowId) {
        _onlyBuyer(escrowId);
        _;
    }

    function _onlyBuyer(uint256 escrowId) internal view {
        if (msg.sender != escrows[escrowId].buyer) revert NotBuyer();
    }


    constructor(address _platformWallet, uint256 _platformFeeBps) {
        require(_platformWallet != address(0), "Invalid platform wallet");
        require(_platformFeeBps <= 1000, "Fee too high");

        owner = msg.sender;
        platformWallet = _platformWallet;
        platformFeeBps = _platformFeeBps;
    }


    /* ========== ESCROW FLOW ========== */

    function createEscrow(address seller) external returns (uint256) {
        require(seller != address(0), "Invalid seller");

        escrowCount++;

        escrows[escrowCount] = Escrow({
            buyer: msg.sender,
            seller: seller,
            amount: 0,
            state: EscrowState.AWAITING_PAYMENT
        });

        emit EscrowCreated(escrowCount, msg.sender, seller);
        return escrowCount;
    }

    function fundEscrow(uint256 escrowId) external payable onlyBuyer(escrowId) {
        Escrow storage e = escrows[escrowId];

        if (e.state != EscrowState.AWAITING_PAYMENT) revert InvalidState();
        if (msg.value == 0) revert InvalidAmount();

        e.amount = msg.value;
        e.state = EscrowState.FUNDED;

        emit EscrowFunded(escrowId, msg.value);
    }

    function releaseFunds(uint256 escrowId) external onlyBuyer(escrowId) {
        Escrow storage e = escrows[escrowId];
        if (e.state != EscrowState.FUNDED) revert InvalidState();

        e.state = EscrowState.RELEASED;
        uint256 platformFee = (e.amount * platformFeeBps) / MAX_BPS;
        uint256 sellerAmount = e.amount - platformFee;


        emit EscrowReleased(escrowId, sellerAmount, platformFee);
        (bool success, ) = payable(platformWallet).call{value: platformFee}("");
        require(success, "Platform fee transfer failed");
        (bool sellerSuccess, ) = payable(e.seller).call{value: sellerAmount}("");
        require(sellerSuccess, "Seller transfer failed");

    }

    function dispute(uint256 escrowId) external onlyBuyer(escrowId) {
        Escrow storage e = escrows[escrowId];
        if (e.state != EscrowState.FUNDED) revert InvalidState();

        e.state = EscrowState.DISPUTED;
        emit EscrowDisputed(escrowId);
    }

    function resolveDispute(uint256 escrowId, bool releaseToSeller) external onlyOwner {
        Escrow storage e = escrows[escrowId];
        if (e.state != EscrowState.DISPUTED) revert InvalidState();

        uint256 amount = e.amount;
        e.amount = 0;

        if (releaseToSeller) {
            e.state = EscrowState.RELEASED;
            uint256 platformFee = (amount * platformFeeBps) / MAX_BPS;
            uint256 sellerAmount = amount - platformFee;

            emit EscrowReleased(escrowId, sellerAmount, platformFee);

            (bool success, ) = payable(platformWallet).call{value: platformFee}("");
            require(success, "Platform fee transfer failed");
            (bool sellerSuccess, ) = payable(e.seller).call{value: sellerAmount}("");
            require(sellerSuccess, "Seller transfer failed");
        } else {
            e.state = EscrowState.REFUNDED;
            emit EscrowRefunded(escrowId);
            (bool buyerSuccess, ) = payable(e.buyer).call{value: amount}("");
            require(buyerSuccess, "Buyer refund transfer failed");
        }
    }

    /* ========== ADMIN ========== */
    function updatePlatformFee(uint256 newFeeBps) external onlyOwner {
        require(newFeeBps <= 1000, "Fee too high");
        emit PlatformFeeBpsUpdated(platformFeeBps, newFeeBps);
        platformFeeBps = newFeeBps;
    }

    function updatePlatformWallet(address newWallet) external onlyOwner {
        require(newWallet != address(0), "Invalid wallet");
        emit PlatformWalletUpdated(platformWallet, newWallet);
        platformWallet = newWallet;
    }
}
