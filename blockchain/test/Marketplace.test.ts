import { expect } from "chai";
import { ethers } from "hardhat";
import { Marketplace, ShowRegistry, TicketNFT, TicketVault } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

const SHOW_ID = 1;
const SEAT_ID = 101;
const FACE_PRICE = ethers.parseEther("1");
const TOTAL_SEATS = 100;
const Status = { NONE: 0, OWNED: 1, LISTED: 2, REVOKED: 3, USED: 4, SOUVENIR: 5 };

function ref(label: string) {
  return ethers.id(label);
}

describe("Marketplace", () => {
  let admin: HardhatEthersSigner;
  let organizer: HardhatEthersSigner;
  let operator: HardhatEthersSigner;
  let custodyVault: HardhatEthersSigner;
  let alice: HardhatEthersSigner; // seller
  let bob: HardhatEthersSigner; // buyer
  let stranger: HardhatEthersSigner;
  let ticketNFT: TicketNFT;
  let vault: TicketVault;
  let marketplace: Marketplace;
  let showRegistry: ShowRegistry;

  beforeEach(async () => {
    [admin, organizer, operator, custodyVault, alice, bob, stranger] = await ethers.getSigners();

    const ShowRegistryFactory = await ethers.getContractFactory("ShowRegistry");
    showRegistry = await ShowRegistryFactory.deploy(admin.address);
    await showRegistry.connect(admin).grantRole(await showRegistry.ORGANIZER_ROLE(), organizer.address);

    const TicketNFTFactory = await ethers.getContractFactory("TicketNFT");
    ticketNFT = await TicketNFTFactory.deploy(admin.address, custodyVault.address, await showRegistry.getAddress());

    const VaultFactory = await ethers.getContractFactory("TicketVault");
    vault = await VaultFactory.deploy(admin.address);

    const MarketplaceFactory = await ethers.getContractFactory("Marketplace");
    marketplace = await MarketplaceFactory.deploy(admin.address, await ticketNFT.getAddress(), await vault.getAddress());
    const marketplaceAddress = await marketplace.getAddress();

    // Two shows (ids 1 and 2 - ShowRegistry's own auto-increment) with
    // their sale window already open, so mintTicket below needs no extra
    // timing setup.
    const now = await time.latest();
    await showRegistry.connect(organizer).registerShow(FACE_PRICE, TOTAL_SEATS, now - 1000, now + 1_000_000, "ipfs://show-1");
    await showRegistry.connect(organizer).registerShow(FACE_PRICE, TOTAL_SEATS, now - 1000, now + 1_000_000, "ipfs://show-2");

    // Grant the Marketplace *contract* MARKETPLACE_ROLE on both underlying
    // contracts - this is the deployment-time wiring the README describes.
    await ticketNFT.connect(admin).grantRole(await ticketNFT.MARKETPLACE_ROLE(), marketplaceAddress);
    await vault.connect(admin).grantRole(await vault.MARKETPLACE_ROLE(), marketplaceAddress);
    await ticketNFT.connect(admin).grantRole(await ticketNFT.ORGANIZER_ROLE(), organizer.address);
    await marketplace.connect(admin).grantRole(await marketplace.OPERATOR_ROLE(), operator.address);
  });

  async function mintAndListToAlice(seatId: number = SEAT_ID) {
    await ticketNFT.connect(organizer).mintTicket(alice.address, SHOW_ID, seatId);
    const tokenId = await ticketNFT.seatTokenId(await ticketNFT.seatKey(SHOW_ID, seatId));
    await ticketNFT.connect(alice).listForTransfer(tokenId, FACE_PRICE);
    return tokenId;
  }

  it("moves NFT ownership and vault balance together in one call", async () => {
    const tokenId = await mintAndListToAlice();
    await vault.connect(admin).grantRole(await vault.OPERATOR_ROLE(), operator.address); // for the deposit below
    await vault.connect(operator).deposit(bob.address, FACE_PRICE, ref("pg-bob"));

    await expect(marketplace.connect(operator).buy(tokenId, bob.address, ref("trade-1")))
      .to.emit(marketplace, "TicketPurchased")
      .withArgs(tokenId, alice.address, bob.address, FACE_PRICE, ref("trade-1"));

    expect(await ticketNFT.ownerOf(tokenId)).to.equal(bob.address);
    expect((await ticketNFT.tickets(tokenId)).status).to.equal(Status.OWNED);
    expect(await vault.balanceOf(bob.address)).to.equal(0);
    expect(await vault.balanceOf(alice.address)).to.equal(FACE_PRICE);
  });

  it("only OPERATOR_ROLE can call buy", async () => {
    const tokenId = await mintAndListToAlice();
    await expect(marketplace.connect(stranger).buy(tokenId, bob.address, ref("trade-2"))).to.be.revertedWithCustomError(
      marketplace,
      "AccessControlUnauthorizedAccount"
    );
  });

  describe("atomicity - a failure on either side reverts the whole purchase", () => {
    it("insufficient buyer balance leaves the NFT untouched (still LISTED, still alice's)", async () => {
      const tokenId = await mintAndListToAlice();
      // bob never deposited anything

      await expect(marketplace.connect(operator).buy(tokenId, bob.address, ref("trade-3"))).to.be.revertedWithCustomError(
        vault,
        "InsufficientBalance"
      );


      expect(await ticketNFT.ownerOf(tokenId)).to.equal(alice.address);
      expect((await ticketNFT.tickets(tokenId)).status).to.equal(Status.LISTED);
    });

    it("a buyer who already holds a ticket for the show is rejected before any balance moves", async () => {
      const tokenId = await mintAndListToAlice();
      await ticketNFT.connect(organizer).mintTicket(bob.address, SHOW_ID, SEAT_ID + 1); // bob already has a seat
      await vault.connect(admin).grantRole(await vault.OPERATOR_ROLE(), operator.address);
      await vault.connect(operator).deposit(bob.address, FACE_PRICE, ref("pg-bob-2"));

      await expect(marketplace.connect(operator).buy(tokenId, bob.address, ref("trade-4"))).to.be.revertedWithCustomError(
        ticketNFT,
        "AlreadyHoldsShowTicket"
      );

      // nothing moved: alice still owns/lists it, bob's deposit is untouched
      expect(await ticketNFT.ownerOf(tokenId)).to.equal(alice.address);
      expect(await vault.balanceOf(bob.address)).to.equal(FACE_PRICE);
    });

    it("a replayed tradeId reverts the NFT transfer too, even though the NFT half alone would have succeeded", async () => {
      // Two different listings, buyer reuses the same tradeId for both - the
      // second call's TicketNFT.settleTransfer succeeds on its own, but the
      // TicketVault.settleTransfer that follows in the *same* transaction
      // must fail on the duplicate ref and roll the NFT change back too.
      const tokenId1 = await mintAndListToAlice(SEAT_ID);

      await vault.connect(admin).grantRole(await vault.OPERATOR_ROLE(), operator.address);
      await vault.connect(operator).deposit(bob.address, FACE_PRICE * 2n, ref("pg-bob-3"));
      await marketplace.connect(operator).buy(tokenId1, bob.address, ref("trade-shared"));

      // bob can't hold a second ticket for the same show, so list a second
      // show's seat to a different seller instead.
      await ticketNFT.connect(organizer).mintTicket(alice.address, SHOW_ID + 1, SEAT_ID);
      const tokenId2 = await ticketNFT.seatTokenId(await ticketNFT.seatKey(SHOW_ID + 1, SEAT_ID));
      await ticketNFT.connect(alice).listForTransfer(tokenId2, FACE_PRICE);

      await expect(
        marketplace.connect(operator).buy(tokenId2, bob.address, ref("trade-shared"))
      ).to.be.revertedWithCustomError(vault, "DuplicateOperation");

      // tokenId2 must still be LISTED under alice - the NFT-side transfer
      // that ran inside the reverted call never actually took effect.
      expect(await ticketNFT.ownerOf(tokenId2)).to.equal(alice.address);
      expect((await ticketNFT.tickets(tokenId2)).status).to.equal(Status.LISTED);
    });
  });
});
