// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {TicketNFT} from "./TicketNFT.sol";
import {TicketVault} from "./TicketVault.sol";

/**
 * Ties TicketNFT.settleTransfer and TicketVault.settleTransfer into one
 * call, so a secondary-market purchase can never leave ownership and
 * payment out of sync - that's the entire point of doing this on-chain
 * instead of through an escrow/dispute process. If either half fails
 * (buyer's balance is short, buyer already holds a ticket for the show,
 * the listing was already settled, ...) the whole transaction reverts and
 * nothing moves.
 *
 * Every other rule (listing exists and is still LISTED, listPrice <=
 * facePrice, buyer doesn't already hold a ticket for this show) is already
 * enforced inside TicketNFT/TicketVault themselves - this contract adds no
 * business rules of its own, it only sequences the two calls atomically.
 *
 * This contract's own address must be granted MARKETPLACE_ROLE on BOTH
 * TicketNFT and TicketVault (by their respective admins, after deployment)
 * to actually be able to call either settleTransfer.
 */
contract Marketplace is AccessControl {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// Immutable rather than admin-settable: repointing a live marketplace
    /// at a different NFT/Vault pair is a migration event that should mean
    /// deploying a new Marketplace, not a quiet parameter swap on this one.
    TicketNFT public immutable ticketNFT;
    TicketVault public immutable ticketVault;

    event TicketPurchased(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price, bytes32 tradeId);

    error ZeroAddress();

    constructor(address admin, address ticketNFT_, address ticketVault_) {
        if (admin == address(0) || ticketNFT_ == address(0) || ticketVault_ == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        ticketNFT = TicketNFT(ticketNFT_);
        ticketVault = TicketVault(ticketVault_);
    }

    /**
     * Settles a LISTED ticket to its buyer. Called by the backend
     * (OPERATOR_ROLE) once it has matched a buyer to a listing off-chain -
     * buyers never call this themselves, matching the rest of the custodial
     * design. tradeId only needs to be unique per purchase; TicketVault is
     * what actually enforces it can't be replayed.
     */
    function buy(uint256 tokenId, address buyer, bytes32 tradeId) external onlyRole(OPERATOR_ROLE) {
        address seller = ticketNFT.ownerOf(tokenId);
        uint256 price = ticketNFT.settleTransfer(tokenId, buyer);
        ticketVault.settleTransfer(seller, buyer, price, tradeId);

        emit TicketPurchased(tokenId, seller, buyer, price, tradeId);
    }
}
