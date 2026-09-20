// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ShowRegistry} from "./ShowRegistry.sol";

/**
 * Seat-bound, transfer-restricted ticket NFT.
 *
 * One tokenId is minted per (showId, seatId) and reused for that seat's
 * entire lifetime - a revoked seat is reissued to its next owner rather
 * than burned and re-minted, so its full ownership history stays on one
 * token.
 *
 * State machine (see docs for the full picture):
 *   OWNED --list--> LISTED --settleTransfer--> OWNED (new owner)
 *   OWNED --revoke--> REVOKED --reissue--> OWNED (new owner)
 *   OWNED --markUsed--> USED --convertToSouvenir--> SOUVENIR
 *
 * Ownership only ever changes through settleTransfer / revoke / reissue /
 * mintTicket below - see _isTransferAllowed. Everything else (listing,
 * marking used, souvenir conversion) is a status flip on the same owner,
 * so it doesn't need to be a whitelisted transfer path at all.
 */
contract TicketNFT is ERC721, AccessControl {
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant GATE_ROLE = keccak256("GATE_ROLE");

    enum Status {
        NONE, // default value; also means "tokenId was never minted"
        OWNED,
        LISTED,
        REVOKED,
        USED,
        SOUVENIR
    }

    struct Ticket {
        uint256 showId;
        uint256 seatId;
        uint256 facePrice; // fixed at mint time, never changes afterwards
        uint256 listPrice; // only meaningful while status == LISTED
        Status status;
    }

    /// tokenId => ticket data. Public so anyone can independently verify
    /// face prices / current status without going through a mirror table.
    mapping(uint256 => Ticket) public tickets;

    /// keccak256(showId, seatId) => tokenId, so a seat can only ever be
    /// minted once. 0 means "not minted yet" (tokenId 0 is never issued).
    mapping(bytes32 => uint256) public seatTokenId;

    /// address => showId => currently holds an active ticket for that show.
    /// Enforces "1인 1매" across both primary issuance and secondary
    /// purchases - set on mint/settleTransfer/reissue, cleared on revoke
    /// (a cancelled ticket frees the buyer to book again).
    mapping(address => mapping(uint256 => bool)) public holdsShow;

    uint256 private _nextTokenId = 1;

    /// Holds tokens between revoke() and reissue() - i.e. seats that have
    /// been cancelled/recovered but not yet handed to the next owner
    /// (succession waitlist, or a manual/1st reopen resale).
    address public custodyVault;

    /// Source of truth for a show's face price and sale timing - mintTicket
    /// reads this instead of trusting a caller-supplied price.
    ShowRegistry public showRegistry;

    event TicketMinted(uint256 indexed tokenId, uint256 indexed showId, uint256 indexed seatId, address to, uint256 facePrice);
    event TicketListed(uint256 indexed tokenId, uint256 listPrice);
    event TicketDelisted(uint256 indexed tokenId);
    event TicketSettled(uint256 indexed tokenId, address indexed from, address indexed to, uint256 price);
    event TicketRevoked(uint256 indexed tokenId, address indexed from);
    event TicketReissued(uint256 indexed tokenId, address indexed to);
    event TicketUsed(uint256 indexed tokenId);
    event TicketConvertedToSouvenir(uint256 indexed tokenId);

    error ZeroAddress();
    error SeatAlreadyMinted(uint256 showId, uint256 seatId);
    error AlreadyHoldsShowTicket(address account, uint256 showId);
    error UnexpectedStatus(uint256 tokenId, Status current, Status required);
    error ListPriceExceedsFacePrice(uint256 askPrice, uint256 facePrice);
    error NotTicketOwner();
    error TransferLocked();
    error ApprovalDisabled();
    error SaleNotOpen(uint256 showId);

    constructor(address admin, address custodyVault_, address showRegistry_) ERC721("TIMO Ticket", "TIMO-TIX") {
        if (admin == address(0) || custodyVault_ == address(0) || showRegistry_ == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        custodyVault = custodyVault_;
        showRegistry = ShowRegistry(showRegistry_);
    }

    function setCustodyVault(address vault) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (vault == address(0)) revert ZeroAddress();
        custodyVault = vault;
    }

    /// Deliberately not immutable: unlike Marketplace (where repointing
    /// means "deploy a new one"), forcing a TicketNFT redeploy to fix a
    /// ShowRegistry issue would mean losing every ticket already minted.
    function setShowRegistry(address showRegistry_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (showRegistry_ == address(0)) revert ZeroAddress();
        showRegistry = ShowRegistry(showRegistry_);
    }

    function seatKey(uint256 showId, uint256 seatId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(showId, seatId));
    }

    // ------------------------------------------------------------------
    // Issuance
    // ------------------------------------------------------------------

    /**
     * Mints the ticket for one seat. facePrice comes from ShowRegistry, not
     * a caller-supplied argument, so there's no path to mint at the wrong
     * price - and minting is blocked outright before the show's registered
     * sale window opens. sectionIndex only selects *which* of the show's
     * already-registered section prices applies (0-4) - the caller can't
     * inject an arbitrary price, only pick among the five ShowRegistry
     * already has on file.
     */
    function mintTicket(address to, uint256 showId, uint256 seatId, uint8 sectionIndex)
        external
        onlyRole(ORGANIZER_ROLE)
        returns (uint256 tokenId)
    {
        bytes32 seat = seatKey(showId, seatId);
        if (seatTokenId[seat] != 0) revert SeatAlreadyMinted(showId, seatId);
        if (holdsShow[to][showId]) revert AlreadyHoldsShowTicket(to, showId);

        // reverts ShowDoesNotExist for a bad showId, InvalidSectionIndex for a bad sectionIndex
        uint256 facePrice = showRegistry.facePriceOf(showId, sectionIndex);
        if (!showRegistry.isSaleOpen(showId)) revert SaleNotOpen(showId);

        tokenId = _nextTokenId++;
        seatTokenId[seat] = tokenId;
        tickets[tokenId] = Ticket({showId: showId, seatId: seatId, facePrice: facePrice, listPrice: 0, status: Status.OWNED});
        holdsShow[to][showId] = true;

        _mint(to, tokenId);
        emit TicketMinted(tokenId, showId, seatId, to, facePrice);
    }

    // ------------------------------------------------------------------
    // Transfer market (listing is just a status flip; settlement is the
    // step that actually moves ownership). Every write here is
    // OPERATOR_ROLE-gated, not msg.sender-signed - ticket owners are
    // custodial wallets whose keys the backend holds, so there is no path
    // where a real owner ever signs their own transaction. The backend
    // passes `owner` and this contract re-checks it against ownerOf(tokenId)
    // before acting, the same way it already trusts itself for mintTicket /
    // revoke / markUsed.
    // ------------------------------------------------------------------

    function listForTransferFor(uint256 tokenId, address owner, uint256 askPrice) external onlyRole(OPERATOR_ROLE) {
        if (ownerOf(tokenId) != owner) revert NotTicketOwner();
        Ticket storage t = tickets[tokenId];
        if (t.status != Status.OWNED) revert UnexpectedStatus(tokenId, t.status, Status.OWNED);
        if (askPrice > t.facePrice) revert ListPriceExceedsFacePrice(askPrice, t.facePrice);

        t.status = Status.LISTED;
        t.listPrice = askPrice;
        emit TicketListed(tokenId, askPrice);
    }

    function delistFor(uint256 tokenId, address owner) external onlyRole(OPERATOR_ROLE) {
        if (ownerOf(tokenId) != owner) revert NotTicketOwner();
        Ticket storage t = tickets[tokenId];
        if (t.status != Status.LISTED) revert UnexpectedStatus(tokenId, t.status, Status.LISTED);

        t.status = Status.OWNED;
        t.listPrice = 0;
        emit TicketDelisted(tokenId);
    }

    /**
     * Moves a LISTED ticket to its buyer. The Marketplace contract is
     * expected to call this and pay the seller via TicketVault in the same
     * external transaction, so payment + ownership transfer + payout are
     * atomic with no escrow needed.
     */
    function settleTransfer(uint256 tokenId, address to) external onlyRole(MARKETPLACE_ROLE) returns (uint256 price) {
        Ticket storage t = tickets[tokenId];
        if (t.status != Status.LISTED) revert UnexpectedStatus(tokenId, t.status, Status.LISTED);
        if (holdsShow[to][t.showId]) revert AlreadyHoldsShowTicket(to, t.showId);

        address from = ownerOf(tokenId);
        price = t.listPrice;
        t.status = Status.OWNED;
        t.listPrice = 0;

        holdsShow[from][t.showId] = false;
        holdsShow[to][t.showId] = true;

        _update(to, tokenId, address(0));
        emit TicketSettled(tokenId, from, to, price);
    }

    // ------------------------------------------------------------------
    // Cancellation / succession
    // ------------------------------------------------------------------

    /**
     * Recovers a cancelled ticket into custody. Only allowed from OWNED -
     * per spec, a LISTED ticket cannot be cancelled/revoked while listed.
     */
    function revoke(uint256 tokenId) external onlyRole(OPERATOR_ROLE) {
        Ticket storage t = tickets[tokenId];
        if (t.status != Status.OWNED) revert UnexpectedStatus(tokenId, t.status, Status.OWNED);

        address from = ownerOf(tokenId);
        t.status = Status.REVOKED;
        holdsShow[from][t.showId] = false;
        _update(custodyVault, tokenId, address(0));
        emit TicketRevoked(tokenId, from);
    }

    /**
     * Hands a REVOKED (recovered) seat to its next owner - the succession
     * waitlist's next entry, or whoever bought it on reopen. If nobody
     * claims it, it just stays REVOKED/in custody, matching "미판매 상태로
     * 남는다" in the spec.
     */
    function reissue(uint256 tokenId, address to) external onlyRole(OPERATOR_ROLE) {
        Ticket storage t = tickets[tokenId];
        if (t.status != Status.REVOKED) revert UnexpectedStatus(tokenId, t.status, Status.REVOKED);
        if (holdsShow[to][t.showId]) revert AlreadyHoldsShowTicket(to, t.showId);

        t.status = Status.OWNED;
        holdsShow[to][t.showId] = true;
        _update(to, tokenId, address(0));
        emit TicketReissued(tokenId, to);
    }

    // ------------------------------------------------------------------
    // Entry / souvenir
    // ------------------------------------------------------------------

    /// A LISTED ticket must be delisted before entry - it doesn't make
    /// sense to check someone in while their ticket is up for resale.
    function markUsed(uint256 tokenId) external onlyRole(GATE_ROLE) {
        Ticket storage t = tickets[tokenId];
        if (t.status != Status.OWNED) revert UnexpectedStatus(tokenId, t.status, Status.OWNED);

        t.status = Status.USED;
        emit TicketUsed(tokenId);
    }

    /// Batched because this runs once for an entire show's used tickets
    /// after it ends, not per-ticket.
    function convertToSouvenir(uint256[] calldata tokenIds) external onlyRole(OPERATOR_ROLE) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            Ticket storage t = tickets[tokenId];
            if (t.status != Status.USED) revert UnexpectedStatus(tokenId, t.status, Status.USED);

            t.status = Status.SOUVENIR;
            emit TicketConvertedToSouvenir(tokenId);
        }
    }

    // ------------------------------------------------------------------
    // Transfer lock - the actual enforcement point
    // ------------------------------------------------------------------

    /**
     * auth == address(0) only ever happens when _update is called directly
     * from this contract's own role-gated functions above (mintTicket /
     * settleTransfer / revoke / reissue), never from the public
     * transferFrom/safeTransferFrom entry points (those always pass
     * _msgSender() as auth). So blocking every nonzero auth is exactly
     * "only these 3 (well, 4: +mint) paths may change ownership" without
     * needing a separate allow-list to maintain.
     *
     * This is the single place to extend if a new transfer path is ever
     * needed - add a condition here, not a rewrite of the state machine.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
        if (!_isTransferAllowed(auth)) revert TransferLocked();
        return super._update(to, tokenId, auth);
    }

    function _isTransferAllowed(address auth) internal pure returns (bool) {
        return auth == address(0);
    }

    /// Disabled outright, not just made irrelevant by _update's lock - an
    /// approved-looking token in a wallet/explorer would misleadingly
    /// suggest it's listable on a third-party marketplace.
    function approve(address, uint256) public pure override(ERC721) {
        revert ApprovalDisabled();
    }

    function setApprovalForAll(address, bool) public pure override(ERC721) {
        revert ApprovalDisabled();
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
