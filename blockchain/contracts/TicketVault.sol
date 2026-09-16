// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * Internal ledger for TIMO's deposited balance ("코인"), exposed as an
 * ERC-20 so wallets/explorers can read balances and Transfer events with
 * real amounts - but every public mutator (transfer/transferFrom/approve)
 * is disabled, same pattern as TicketNFT.approve/setApprovalForAll. Balance
 * can only move through the OPERATOR_ROLE/MARKETPLACE_ROLE functions below,
 * which call ERC20's internal _mint/_transfer/_burn directly - so it's
 * still never cashed out or moved by a user action, just now inspectable
 * as a real token instead of a private mapping.
 *
 * A PG charges real money off-chain and the backend (OPERATOR_ROLE) mirrors
 * that as a deposit here; every later balance movement (primary sale,
 * secondary market, succession) reads and writes the same ERC-20 balance,
 * which is exactly what guarantees a balance can never be double-spent
 * across the two layers.
 *
 * Every state-changing call takes a caller-supplied bytes32 ref/id and
 * refuses to process the same one twice. That's the on-chain half of "동일
 * 결제 요청이 반복되어도 주문은 한 번만 확정된다" - the backend/DB is the
 * fast path, this is the belt-and-suspenders replay guard on the ledger
 * that actually owns the money.
 */
contract TicketVault is ERC20, AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    struct WaitlistLock {
        address user;
        uint256 amount;
        bool active;
    }

    /// Balance currently locked against an active succession waitlist entry.
    /// Burned out of the ERC-20 balance while locked (see lockForWaitlist),
    /// so it can't be double-spent elsewhere and isn't part of balanceOf/
    /// totalSupply during the lock.
    mapping(address => uint256) public lockedOf;

    mapping(bytes32 => WaitlistLock) public waitlistLocks;

    /// Every ref/orderId/tradeId/waitlistId this contract has ever accepted,
    /// so a retried call is a no-op failure instead of a double charge.
    mapping(bytes32 => bool) public processedRefs;

    event Deposited(address indexed user, uint256 amount, bytes32 indexed refId);
    event ChargedForBooking(address indexed buyer, address indexed organizer, uint256 amount, bytes32 indexed orderId);
    event Refunded(address indexed user, address indexed organizer, uint256 amount, bytes32 indexed refId);
    event TransferSettled(address indexed seller, address indexed buyer, uint256 price, bytes32 indexed tradeId);
    event WaitlistLocked(address indexed user, bytes32 indexed waitlistId, uint256 amount);
    event WaitlistUnlocked(address indexed user, bytes32 indexed waitlistId, uint256 amount);
    event WaitlistClaimed(
        address indexed user, address indexed organizer, bytes32 indexed waitlistId, uint256 actualPrice, uint256 refundedToBalance
    );

    error ZeroAddress();
    error ZeroAmount();
    error ZeroRefId();
    error DuplicateOperation(bytes32 refId);
    error WaitlistLockAlreadyActive(bytes32 waitlistId);
    error WaitlistLockNotActive(bytes32 waitlistId);
    error ActualPriceExceedsLocked(bytes32 waitlistId, uint256 locked, uint256 actualPrice);
    error TransferDisabled();

    constructor(address admin) ERC20("Mushroom", "MSR") {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ------------------------------------------------------------------
    // Charging (PG confirmed a real-money payment off-chain; this just
    // mirrors it as usable balance)
    // ------------------------------------------------------------------

    function deposit(address user, uint256 amount, bytes32 refId) external onlyRole(OPERATOR_ROLE) {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _consumeRef(refId);

        _mint(user, amount);
        emit Deposited(user, amount, refId);
    }

    // ------------------------------------------------------------------
    // Primary sale - deducts the buyer and credits the organizer in the
    // same call, since 1차 판매 대금은 주최사 잔액으로 누적된다. This is the
    // on-chain mirror of the off-chain seat-assignment+deduction the
    // backend already committed atomically in its own DB; the backend
    // calls this right after (or as part of the same async pipeline as
    // NFT minting), using the same orderId for idempotency either way.
    // ------------------------------------------------------------------

    function chargeForBooking(address buyer, address organizer, uint256 amount, bytes32 orderId) external onlyRole(OPERATOR_ROLE) {
        if (buyer == address(0) || organizer == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _consumeRef(orderId);

        _transfer(buyer, organizer, amount);
        emit ChargedForBooking(buyer, organizer, amount, orderId);
    }

    /**
     * Claws the amount back out of the organizer's balance and returns it
     * to the buyer - a real reversal of a previous chargeForBooking, not
     * newly minted money. Used for both a cancellation refund and a
     * minting-failure compensating transaction; both callers already know
     * which organizer's balance chargeForBooking credited for this same
     * order/reservation (same facePrice, same show), since that's what
     * they're reversing. If the organizer's balance is short (already
     * spent elsewhere as a buyer themselves), this reverts with the
     * standard ERC-20 insufficient-balance error same as any other
     * transfer - there's no separate float this draws from.
     */
    function refund(address user, address organizer, uint256 amount, bytes32 refId) external onlyRole(OPERATOR_ROLE) {
        if (user == address(0) || organizer == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _consumeRef(refId);

        _transfer(organizer, user, amount);
        emit Refunded(user, organizer, amount, refId);
    }

    // ------------------------------------------------------------------
    // Secondary market - the Marketplace contract calls this in the same
    // transaction as TicketNFT.settleTransfer, so payment and ownership
    // transfer are atomic with no escrow. Full listPrice passes through to
    // the seller; there's no platform fee here because none is specified
    // yet (listing-cancellation penalties are explicitly undecided in the
    // spec, and no fee is mentioned for a completed sale).
    // ------------------------------------------------------------------

    function settleTransfer(address seller, address buyer, uint256 price, bytes32 tradeId) external onlyRole(MARKETPLACE_ROLE) {
        if (seller == address(0) || buyer == address(0)) revert ZeroAddress();
        if (price == 0) revert ZeroAmount();
        _consumeRef(tradeId);

        _transfer(buyer, seller, price);
        emit TransferSettled(seller, buyer, price, tradeId);
    }

    // ------------------------------------------------------------------
    // Succession waitlist - registering locks the show's highest seat
    // grade's face price out of usable balance (spec: single ungraded
    // queue, so the deposit has to cover whatever grade eventually gets
    // recovered). waitlistId is a one-time id: once claimed or unlocked it
    // can never be reused, which is what stops a lock from being drained
    // twice.
    // ------------------------------------------------------------------

    function lockForWaitlist(address user, uint256 amount, bytes32 waitlistId) external onlyRole(OPERATOR_ROLE) {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (waitlistLocks[waitlistId].user != address(0)) revert WaitlistLockAlreadyActive(waitlistId);

        _burn(user, amount);
        lockedOf[user] += amount;
        waitlistLocks[waitlistId] = WaitlistLock({user: user, amount: amount, active: true});

        emit WaitlistLocked(user, waitlistId, amount);
    }

    /// Cancelling a waitlist entry releases the full lock back to usable
    /// balance - unlocking is free, matching the "환불 없음" rule since
    /// nothing was ever actually spent yet.
    function unlockWaitlist(bytes32 waitlistId) external onlyRole(OPERATOR_ROLE) {
        WaitlistLock storage lock = waitlistLocks[waitlistId];
        if (!lock.active) revert WaitlistLockNotActive(waitlistId);

        lock.active = false;
        lockedOf[lock.user] -= lock.amount;
        _mint(lock.user, lock.amount);

        emit WaitlistUnlocked(lock.user, waitlistId, lock.amount);
    }

    /**
     * A recovered seat is offered to the front of the waitlist. actualPrice
     * is that seat's real face price, which may be lower than what was
     * locked (the lock covers the highest grade; the recovered seat can be
     * any grade). actualPrice is paid to the organizer out of the lock;
     * the rest (locked - actualPrice) is released back to usable balance.
     */
    function claimWaitlistSeat(bytes32 waitlistId, address organizer, uint256 actualPrice) external onlyRole(OPERATOR_ROLE) {
        if (organizer == address(0)) revert ZeroAddress();
        WaitlistLock storage lock = waitlistLocks[waitlistId];
        if (!lock.active) revert WaitlistLockNotActive(waitlistId);
        if (actualPrice > lock.amount) revert ActualPriceExceedsLocked(waitlistId, lock.amount, actualPrice);

        lock.active = false;
        uint256 refundToBalance = lock.amount - actualPrice;

        lockedOf[lock.user] -= lock.amount;
        if (refundToBalance > 0) {
            _mint(lock.user, refundToBalance);
        }
        _mint(organizer, actualPrice);

        emit WaitlistClaimed(lock.user, organizer, waitlistId, actualPrice, refundToBalance);
    }

    // ------------------------------------------------------------------
    // ERC-20 surface stays standard (balanceOf/totalSupply/Transfer events)
    // so wallets and explorers can read this like any token - but every
    // user-facing mutator is disabled outright, not just left unreachable.
    // Only the role-gated functions above (which call _mint/_transfer/
    // _burn directly, bypassing these) can ever move balance. Same pattern
    // as TicketNFT.approve/setApprovalForAll being disabled for the same
    // reason: an approved-looking balance would misleadingly suggest a
    // user could move or spend it themselves.
    // ------------------------------------------------------------------

    function transfer(address, uint256) public pure override returns (bool) {
        revert TransferDisabled();
    }

    function approve(address, uint256) public pure override returns (bool) {
        revert TransferDisabled();
    }

    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert TransferDisabled();
    }

    // ------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------

    function _consumeRef(bytes32 refId) private {
        if (refId == bytes32(0)) revert ZeroRefId();
        if (processedRefs[refId]) revert DuplicateOperation(refId);
        processedRefs[refId] = true;
    }
}
