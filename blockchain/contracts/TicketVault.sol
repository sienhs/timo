// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * Internal ledger for TIMO's deposited balance ("코인"). This is
 * deliberately NOT an ERC-20: nothing here is ever transferable by a user,
 * never leaves the contract, and can't be cashed out - it only exists to
 * account for purchasing power. A PG charges real money off-chain and the
 * backend (OPERATOR_ROLE) mirrors that as a deposit here; every later
 * balance movement (primary sale, secondary market, succession) reads and
 * writes this same mapping, which is exactly what guarantees a balance can
 * never be double-spent across the two layers.
 *
 * Every state-changing call takes a caller-supplied bytes32 ref/id and
 * refuses to process the same one twice. That's the on-chain half of "동일
 * 결제 요청이 반복되어도 주문은 한 번만 확정된다" - the backend/DB is the
 * fast path, this is the belt-and-suspenders replay guard on the ledger
 * that actually owns the money.
 */
contract TicketVault is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    struct WaitlistLock {
        address user;
        uint256 amount;
        bool active;
    }

    /// Usable balance - spendable on a booking, a waitlist lock, or received
    /// as sale/settlement proceeds.
    mapping(address => uint256) public balanceOf;

    /// Balance currently locked against an active succession waitlist entry.
    /// Not part of balanceOf, so it can't be double-spent elsewhere while
    /// locked.
    mapping(address => uint256) public lockedOf;

    mapping(bytes32 => WaitlistLock) public waitlistLocks;

    /// Every ref/orderId/tradeId/waitlistId this contract has ever accepted,
    /// so a retried call is a no-op failure instead of a double charge.
    mapping(bytes32 => bool) public processedRefs;

    event Deposited(address indexed user, uint256 amount, bytes32 indexed refId);
    event ChargedForBooking(address indexed buyer, address indexed organizer, uint256 amount, bytes32 indexed orderId);
    event Refunded(address indexed user, uint256 amount, bytes32 indexed refId);
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
    error InsufficientBalance(address user, uint256 balance, uint256 requested);
    error WaitlistLockAlreadyActive(bytes32 waitlistId);
    error WaitlistLockNotActive(bytes32 waitlistId);
    error ActualPriceExceedsLocked(bytes32 waitlistId, uint256 locked, uint256 actualPrice);

    constructor(address admin) {
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

        balanceOf[user] += amount;
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

        _debit(buyer, amount);
        balanceOf[organizer] += amount;
        emit ChargedForBooking(buyer, organizer, amount, orderId);
    }

    /// Credits usable balance back with no fee deducted - used for both a
    /// cancellation refund and a minting-failure compensating transaction.
    /// There's no separate withdraw/cash-out path; this only ever returns
    /// value to the same internal ledger.
    function refund(address user, uint256 amount, bytes32 refId) external onlyRole(OPERATOR_ROLE) {
        if (user == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _consumeRef(refId);

        balanceOf[user] += amount;
        emit Refunded(user, amount, refId);
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

        _debit(buyer, price);
        balanceOf[seller] += price;
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

        _debit(user, amount);
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
        balanceOf[lock.user] += lock.amount;

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
            balanceOf[lock.user] += refundToBalance;
        }
        balanceOf[organizer] += actualPrice;

        emit WaitlistClaimed(lock.user, organizer, waitlistId, actualPrice, refundToBalance);
    }

    // ------------------------------------------------------------------
    // Internal helpers
    // ------------------------------------------------------------------

    function _debit(address user, uint256 amount) private {
        uint256 bal = balanceOf[user];
        if (bal < amount) revert InsufficientBalance(user, bal, amount);
        balanceOf[user] = bal - amount;
    }

    function _consumeRef(bytes32 refId) private {
        if (refId == bytes32(0)) revert ZeroRefId();
        if (processedRefs[refId]) revert DuplicateOperation(refId);
        processedRefs[refId] = true;
    }
}
