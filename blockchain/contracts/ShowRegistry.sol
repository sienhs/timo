// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * Pre-sale catalog of shows: a face price *per section* (every venue in
 * this system is seeded with exactly SECTION_COUNT sections - see
 * LocalDataSeeder.SECTION_SEEDS on the backend), a seat count, and the
 * sale/show timing that gates when tickets may be minted.
 *
 * This contract only manages the *catalog*. It doesn't track individual
 * seats or how many have been minted (TicketNFT does, via seatTokenId) and
 * it doesn't touch money (TicketVault does) - keeping those concerns apart
 * is what lets each contract stay simple and independently auditable.
 *
 * Section index is a caller-supplied uint8 in [0, SECTION_COUNT) - this
 * contract doesn't know or care what a section is *named*, only that
 * whichever off-chain section a seat belongs to maps to a stable index
 * (the backend derives this from Section rows ordered by id, which is
 * guaranteed stable - see SectionRepository.findAllByVenueIdOrderByIdAsc).
 */
contract ShowRegistry is AccessControl {
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// Every venue in this system has exactly this many seating sections -
    /// not a general-purpose "up to N grades" limit, a fixed shape.
    uint8 public constant SECTION_COUNT = 5;

    enum Status {
        REGISTERED,
        CANCELLED,
        ENDED
    }

    struct Show {
        address organizer;
        uint256[SECTION_COUNT] sectionPrices; // index-aligned with the show's off-chain section order
        uint256 totalSeats;
        uint256 saleOpenTime; // unix seconds; booking/minting gated on this
        uint256 showTime; // unix seconds; when the performance itself happens
        string metadataURI; // off-chain: poster, description, venue, seat map layout
        Status status;
    }

    /// showId => show. Public so anyone can independently verify a show's
    /// published prices/timing without a mirror table. Note: Solidity's
    /// auto-generated getter omits the sectionPrices array (structs with
    /// array members drop them from the implicit getter's return tuple) -
    /// use facePriceOf(showId, sectionIndex) to read a price.
    mapping(uint256 => Show) public shows;

    uint256 private _nextShowId = 1;

    /// "공연 취소는 D-7일까지 가능하다"
    uint256 public constant CANCELLATION_DEADLINE = 7 days;

    event ShowRegistered(
        uint256 indexed showId,
        address indexed organizer,
        uint256[SECTION_COUNT] sectionPrices,
        uint256 totalSeats,
        uint256 saleOpenTime,
        uint256 showTime
    );
    event ShowUpdated(
        uint256 indexed showId, uint256[SECTION_COUNT] sectionPrices, uint256 totalSeats, uint256 saleOpenTime, uint256 showTime
    );
    event ShowCancelled(uint256 indexed showId);
    event ShowEnded(uint256 indexed showId);

    error ZeroAddress();
    error InvalidPrice();
    error InvalidSeatCount();
    error InvalidTiming();
    error InvalidSectionIndex(uint8 sectionIndex);
    error ShowDoesNotExist(uint256 showId);
    error NotShowOrganizer(uint256 showId);
    error ShowNotEditable(uint256 showId, Status status);
    error SaleAlreadyOpen(uint256 showId);
    error CancellationWindowPassed(uint256 showId);
    error ShowNotYetOver(uint256 showId);

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerShow(
        uint256[SECTION_COUNT] calldata sectionPrices,
        uint256 totalSeats,
        uint256 saleOpenTime,
        uint256 showTime,
        string calldata metadataURI
    ) external onlyRole(ORGANIZER_ROLE) returns (uint256 showId) {
        _requireAllPricesNonZero(sectionPrices);
        if (totalSeats == 0) revert InvalidSeatCount();
        if (saleOpenTime >= showTime) revert InvalidTiming();

        showId = _nextShowId++;
        Show storage s = shows[showId];
        s.organizer = msg.sender;
        s.sectionPrices = sectionPrices;
        s.totalSeats = totalSeats;
        s.saleOpenTime = saleOpenTime;
        s.showTime = showTime;
        s.metadataURI = metadataURI;
        s.status = Status.REGISTERED;

        emit ShowRegistered(showId, msg.sender, sectionPrices, totalSeats, saleOpenTime, showTime);
    }

    /**
     * Only editable while REGISTERED and before its own saleOpenTime -
     * "정가표를 공연 등록 시점에 먼저 올린다" + "발행 이후 정가는 변경되지
     * 않는다": once the sale window a buyer could be relying on has
     * started, the catalog entry freezes too, not just already-minted
     * tickets.
     */
    function updateShow(
        uint256 showId,
        uint256[SECTION_COUNT] calldata sectionPrices,
        uint256 totalSeats,
        uint256 saleOpenTime,
        uint256 showTime,
        string calldata metadataURI
    ) external {
        Show storage s = _requireOrganizer(showId);
        if (s.status != Status.REGISTERED) revert ShowNotEditable(showId, s.status);
        if (block.timestamp >= s.saleOpenTime) revert SaleAlreadyOpen(showId);
        _requireAllPricesNonZero(sectionPrices);
        if (totalSeats == 0) revert InvalidSeatCount();
        if (saleOpenTime >= showTime) revert InvalidTiming();

        s.sectionPrices = sectionPrices;
        s.totalSeats = totalSeats;
        s.saleOpenTime = saleOpenTime;
        s.showTime = showTime;
        s.metadataURI = metadataURI;

        emit ShowUpdated(showId, sectionPrices, totalSeats, saleOpenTime, showTime);
    }

    /**
     * D-7 cutoff only - actually revoking already-minted tickets and
     * refunding their buyers happens off-chain/backend-orchestrated (via
     * TicketNFT.revoke + TicketVault.refund per affected ticket), not
     * here: this contract doesn't track which tokenIds belong to a show,
     * and looping over an unbounded set on-chain is the kind of thing that
     * runs out of gas at scale.
     */
    function cancelShow(uint256 showId) external {
        Show storage s = _requireOrganizer(showId);
        if (s.status != Status.REGISTERED) revert ShowNotEditable(showId, s.status);
        if (block.timestamp > s.showTime - CANCELLATION_DEADLINE) revert CancellationWindowPassed(showId);

        s.status = Status.CANCELLED;
        emit ShowCancelled(showId);
    }

    /// Platform-driven (not the organizer) so "종료" reflects the show
    /// actually having happened, not an organizer's own say-so.
    function endShow(uint256 showId) external onlyRole(OPERATOR_ROLE) {
        Show storage s = _showOrRevert(showId);
        if (s.status != Status.REGISTERED) revert ShowNotEditable(showId, s.status);
        if (block.timestamp < s.showTime) revert ShowNotYetOver(showId);

        s.status = Status.ENDED;
        emit ShowEnded(showId);
    }

    /// "예매 오픈 시각 이전에는 좌석 선택이 성립되지 않는다" as a single
    /// cheap check other contracts/the backend can call. False (not a
    /// revert) for a showId that was never registered - a zeroed-out Show
    /// would otherwise read as "REGISTERED, saleOpenTime 0" and this would
    /// wrongly report true.
    function isSaleOpen(uint256 showId) external view returns (bool) {
        Show storage s = shows[showId];
        return s.organizer != address(0) && s.status == Status.REGISTERED && block.timestamp >= s.saleOpenTime;
    }

    /// Cheap, single-purpose lookup for TicketNFT.mintTicket instead of
    /// pulling the whole Show (including metadataURI) across the call.
    function facePriceOf(uint256 showId, uint8 sectionIndex) external view returns (uint256) {
        Show storage s = _showOrRevert(showId);
        if (sectionIndex >= SECTION_COUNT) revert InvalidSectionIndex(sectionIndex);
        return s.sectionPrices[sectionIndex];
    }

    /// All SECTION_COUNT prices for a show in one call - the off-chain seat
    /// map screen wants the whole price table, not one section at a time.
    function sectionPricesOf(uint256 showId) external view returns (uint256[SECTION_COUNT] memory) {
        return _showOrRevert(showId).sectionPrices;
    }

    function _requireAllPricesNonZero(uint256[SECTION_COUNT] calldata sectionPrices) private pure {
        for (uint8 i = 0; i < SECTION_COUNT; i++) {
            if (sectionPrices[i] == 0) revert InvalidPrice();
        }
    }

    function _showOrRevert(uint256 showId) private view returns (Show storage) {
        Show storage s = shows[showId];
        if (s.organizer == address(0)) revert ShowDoesNotExist(showId);
        return s;
    }

    function _requireOrganizer(uint256 showId) private view returns (Show storage) {
        Show storage s = _showOrRevert(showId);
        if (s.organizer != msg.sender) revert NotShowOrganizer(showId);
        return s;
    }
}
