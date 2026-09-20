import { expect } from "chai";
import { ethers } from "hardhat";
import { ShowRegistry, TicketNFT } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

const SEAT_ID = 101;
const FACE_PRICE = ethers.parseEther("1");
const SECTION_PRICES: [bigint, bigint, bigint, bigint, bigint] = [FACE_PRICE, FACE_PRICE, FACE_PRICE, FACE_PRICE, FACE_PRICE];
const SECTION_INDEX = 0; // which of the 5 registered section prices these tests mint against
const TOTAL_SEATS = 100;

// Status enum, mirrored from the contract (NONE, OWNED, LISTED, REVOKED, USED, SOUVENIR)
const Status = { NONE: 0, OWNED: 1, LISTED: 2, REVOKED: 3, USED: 4, SOUVENIR: 5 };

describe("TicketNFT", () => {
  let admin: HardhatEthersSigner;
  let organizer: HardhatEthersSigner;
  let marketplace: HardhatEthersSigner;
  let operator: HardhatEthersSigner;
  let gate: HardhatEthersSigner;
  let custodyVault: HardhatEthersSigner;
  let alice: HardhatEthersSigner;
  let bob: HardhatEthersSigner;
  let stranger: HardhatEthersSigner;
  let ticket: TicketNFT;
  let showRegistry: ShowRegistry;
  let SHOW_ID: bigint;

  beforeEach(async () => {
    [admin, organizer, marketplace, operator, gate, custodyVault, alice, bob, stranger] = await ethers.getSigners();

    const ShowRegistryFactory = await ethers.getContractFactory("ShowRegistry");
    showRegistry = await ShowRegistryFactory.deploy(admin.address);
    await showRegistry.connect(admin).grantRole(await showRegistry.ORGANIZER_ROLE(), organizer.address);

    const TicketNFTFactory = await ethers.getContractFactory("TicketNFT");
    ticket = await TicketNFTFactory.deploy(admin.address, custodyVault.address, await showRegistry.getAddress());

    await ticket.connect(admin).grantRole(await ticket.ORGANIZER_ROLE(), organizer.address);
    await ticket.connect(admin).grantRole(await ticket.MARKETPLACE_ROLE(), marketplace.address);
    await ticket.connect(admin).grantRole(await ticket.OPERATOR_ROLE(), operator.address);
    await ticket.connect(admin).grantRole(await ticket.GATE_ROLE(), gate.address);

    // Two shows registered with their sale window already open, so
    // mintTicket calls below don't need their own timing setup. Ids come
    // back as 1 and 2 (ShowRegistry's own auto-increment), which is what
    // the rest of this file refers to as SHOW_ID / SHOW_ID + 1.
    const now = await time.latest();
    await registerOpenShow();
    await registerOpenShow();

    async function registerOpenShow() {
      await showRegistry.connect(organizer).registerShow(SECTION_PRICES, TOTAL_SEATS, now - 1000, now + 1_000_000, "ipfs://show");
    }

    SHOW_ID = 1n;
  });

  async function mintToAlice() {
    const tx = await ticket.connect(organizer).mintTicket(alice.address, SHOW_ID, SEAT_ID, SECTION_INDEX);
    const receipt = await tx.wait();
    return receipt;
  }

  describe("mintTicket", () => {
    it("mints seat-bound, OWNED, to the given address", async () => {
      await mintToAlice();
      expect(await ticket.ownerOf(1)).to.equal(alice.address);
      const t = await ticket.tickets(1);
      expect(t.showId).to.equal(SHOW_ID);
      expect(t.seatId).to.equal(SEAT_ID);
      expect(t.facePrice).to.equal(FACE_PRICE);
      expect(t.status).to.equal(Status.OWNED);
    });

    it("rejects a second mint for the same seat", async () => {
      await mintToAlice();
      await expect(
        ticket.connect(organizer).mintTicket(bob.address, SHOW_ID, SEAT_ID, SECTION_INDEX)
      ).to.be.revertedWithCustomError(ticket, "SeatAlreadyMinted");
    });

    it("rejects mint from a non-organizer", async () => {
      await expect(
        ticket.connect(stranger).mintTicket(alice.address, SHOW_ID, SEAT_ID, SECTION_INDEX)
      ).to.be.revertedWithCustomError(ticket, "AccessControlUnauthorizedAccount");
    });
  });

  describe("one ticket per show", () => {
    it("rejects minting a second seat for the same show to the same account", async () => {
      await mintToAlice();
      await expect(
        ticket.connect(organizer).mintTicket(alice.address, SHOW_ID, SEAT_ID + 1, SECTION_INDEX)
      ).to.be.revertedWithCustomError(ticket, "AlreadyHoldsShowTicket");
    });

    it("allows the same account to hold seats for two different shows", async () => {
      await mintToAlice();
      await expect(ticket.connect(organizer).mintTicket(alice.address, SHOW_ID + 1n, SEAT_ID, SECTION_INDEX)).to.not.be.reverted;
    });

    it("rejects a marketplace settlement to a buyer who already holds a ticket for that show", async () => {
      await mintToAlice(); // alice: tokenId 1, SHOW_ID
      await ticket.connect(organizer).mintTicket(bob.address, SHOW_ID, SEAT_ID + 1, SECTION_INDEX); // bob: tokenId 2, SHOW_ID
      await ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE);

      await expect(ticket.connect(marketplace).settleTransfer(1, bob.address)).to.be.revertedWithCustomError(
        ticket,
        "AlreadyHoldsShowTicket"
      );
    });

    it("revoke frees the slot so the account can hold a new ticket for that show", async () => {
      await mintToAlice();
      await ticket.connect(operator).revoke(1);

      await expect(ticket.connect(organizer).mintTicket(alice.address, SHOW_ID, SEAT_ID + 1, SECTION_INDEX)).to.not.be.reverted;
    });

    it("rejects reissuing to someone who already holds a ticket for that show", async () => {
      await mintToAlice(); // alice: tokenId 1, SHOW_ID
      await ticket.connect(operator).revoke(1);
      await ticket.connect(organizer).mintTicket(bob.address, SHOW_ID, SEAT_ID + 1, SECTION_INDEX); // bob: tokenId 2, SHOW_ID

      await expect(ticket.connect(operator).reissue(1, bob.address)).to.be.revertedWithCustomError(
        ticket,
        "AlreadyHoldsShowTicket"
      );
    });
  });

  describe("transfer lock", () => {
    it("blocks plain transferFrom even by the owner", async () => {
      await mintToAlice();
      await expect(
        ticket.connect(alice).transferFrom(alice.address, bob.address, 1)
      ).to.be.revertedWithCustomError(ticket, "TransferLocked");
    });

    it("blocks approve and setApprovalForAll entirely", async () => {
      await mintToAlice();
      await expect(ticket.connect(alice).approve(bob.address, 1)).to.be.revertedWithCustomError(ticket, "ApprovalDisabled");
      await expect(ticket.connect(alice).setApprovalForAll(bob.address, true)).to.be.revertedWithCustomError(
        ticket,
        "ApprovalDisabled"
      );
    });
  });

  describe("listing + marketplace settlement", () => {
    it("lets OPERATOR_ROLE list on the owner's behalf at or below face price", async () => {
      await mintToAlice();
      await expect(ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE))
        .to.emit(ticket, "TicketListed")
        .withArgs(1, FACE_PRICE);
      expect((await ticket.tickets(1)).status).to.equal(Status.LISTED);
    });

    it("rejects listing above face price", async () => {
      await mintToAlice();
      await expect(
        ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE + 1n)
      ).to.be.revertedWithCustomError(ticket, "ListPriceExceedsFacePrice");
    });

    it("rejects listing when the given owner doesn't actually hold the ticket", async () => {
      await mintToAlice();
      await expect(
        ticket.connect(operator).listForTransferFor(1, bob.address, FACE_PRICE)
      ).to.be.revertedWithCustomError(ticket, "NotTicketOwner");
    });

    it("rejects listing from anyone without OPERATOR_ROLE", async () => {
      await mintToAlice();
      await expect(
        ticket.connect(alice).listForTransferFor(1, alice.address, FACE_PRICE)
      ).to.be.revertedWithCustomError(ticket, "AccessControlUnauthorizedAccount");
    });

    it("delistFor returns it to OWNED", async () => {
      await mintToAlice();
      await ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE);
      await ticket.connect(operator).delistFor(1, alice.address);
      expect((await ticket.tickets(1)).status).to.equal(Status.OWNED);
    });

    it("rejects delisting when the given owner doesn't actually hold the ticket", async () => {
      await mintToAlice();
      await ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE);
      await expect(ticket.connect(operator).delistFor(1, bob.address)).to.be.revertedWithCustomError(
        ticket,
        "NotTicketOwner"
      );
    });

    it("rejects delisting from anyone without OPERATOR_ROLE", async () => {
      await mintToAlice();
      await ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE);
      await expect(ticket.connect(alice).delistFor(1, alice.address)).to.be.revertedWithCustomError(
        ticket,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("settleTransfer moves ownership and returns to OWNED under the new owner", async () => {
      await mintToAlice();
      await ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE);

      await expect(ticket.connect(marketplace).settleTransfer(1, bob.address))
        .to.emit(ticket, "TicketSettled")
        .withArgs(1, alice.address, bob.address, FACE_PRICE);

      expect(await ticket.ownerOf(1)).to.equal(bob.address);
      const t = await ticket.tickets(1);
      expect(t.status).to.equal(Status.OWNED);
      expect(t.listPrice).to.equal(0);
    });

    it("rejects settleTransfer from anyone without MARKETPLACE_ROLE", async () => {
      await mintToAlice();
      await ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE);
      await expect(ticket.connect(alice).settleTransfer(1, bob.address)).to.be.revertedWithCustomError(
        ticket,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("rejects settleTransfer on a non-LISTED ticket", async () => {
      await mintToAlice();
      await expect(ticket.connect(marketplace).settleTransfer(1, bob.address)).to.be.revertedWithCustomError(
        ticket,
        "UnexpectedStatus"
      );
    });
  });

  describe("revoke + reissue (cancellation / succession)", () => {
    it("revoke moves the ticket into custody and marks REVOKED", async () => {
      await mintToAlice();
      await expect(ticket.connect(operator).revoke(1)).to.emit(ticket, "TicketRevoked").withArgs(1, alice.address);

      expect(await ticket.ownerOf(1)).to.equal(custodyVault.address);
      expect((await ticket.tickets(1)).status).to.equal(Status.REVOKED);
    });

    it("cannot revoke a LISTED ticket", async () => {
      await mintToAlice();
      await ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE);
      await expect(ticket.connect(operator).revoke(1)).to.be.revertedWithCustomError(ticket, "UnexpectedStatus");
    });

    it("reissue hands a REVOKED ticket to the next owner as OWNED", async () => {
      await mintToAlice();
      await ticket.connect(operator).revoke(1);

      await expect(ticket.connect(operator).reissue(1, bob.address)).to.emit(ticket, "TicketReissued").withArgs(1, bob.address);

      expect(await ticket.ownerOf(1)).to.equal(bob.address);
      expect((await ticket.tickets(1)).status).to.equal(Status.OWNED);
    });

    it("cannot reissue a ticket that isn't REVOKED", async () => {
      await mintToAlice();
      await expect(ticket.connect(operator).reissue(1, bob.address)).to.be.revertedWithCustomError(ticket, "UnexpectedStatus");
    });

    it("only OPERATOR_ROLE can revoke/reissue", async () => {
      await mintToAlice();
      await expect(ticket.connect(stranger).revoke(1)).to.be.revertedWithCustomError(ticket, "AccessControlUnauthorizedAccount");
    });
  });

  describe("entry + souvenir conversion", () => {
    it("markUsed transitions OWNED -> USED without changing owner", async () => {
      await mintToAlice();
      await expect(ticket.connect(gate).markUsed(1)).to.emit(ticket, "TicketUsed").withArgs(1);

      expect(await ticket.ownerOf(1)).to.equal(alice.address);
      expect((await ticket.tickets(1)).status).to.equal(Status.USED);
    });

    it("cannot mark a LISTED ticket used", async () => {
      await mintToAlice();
      await ticket.connect(operator).listForTransferFor(1, alice.address, FACE_PRICE);
      await expect(ticket.connect(gate).markUsed(1)).to.be.revertedWithCustomError(ticket, "UnexpectedStatus");
    });

    it("only GATE_ROLE can mark used", async () => {
      await mintToAlice();
      await expect(ticket.connect(stranger).markUsed(1)).to.be.revertedWithCustomError(ticket, "AccessControlUnauthorizedAccount");
    });

    it("converts a batch of USED tickets to SOUVENIR", async () => {
      await mintToAlice(); // tokenId 1, alice
      await ticket.connect(organizer).mintTicket(bob.address, SHOW_ID, SEAT_ID + 1, SECTION_INDEX); // tokenId 2, bob
      await ticket.connect(gate).markUsed(1);
      await ticket.connect(gate).markUsed(2);

      await expect(ticket.connect(operator).convertToSouvenir([1, 2]))
        .to.emit(ticket, "TicketConvertedToSouvenir")
        .withArgs(1);

      expect((await ticket.tickets(1)).status).to.equal(Status.SOUVENIR);
      expect((await ticket.tickets(2)).status).to.equal(Status.SOUVENIR);
      // ownership never moved for either ticket through USED -> SOUVENIR
      expect(await ticket.ownerOf(1)).to.equal(alice.address);
      expect(await ticket.ownerOf(2)).to.equal(bob.address);
    });

    it("rejects converting a non-USED ticket to souvenir", async () => {
      await mintToAlice();
      await expect(ticket.connect(operator).convertToSouvenir([1])).to.be.revertedWithCustomError(ticket, "UnexpectedStatus");
    });
  });
});
