import { expect } from "chai";
import { ethers } from "hardhat";
import { ShowRegistry } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

const FACE_PRICE = ethers.parseEther("1");
const TOTAL_SEATS = 100;
const METADATA_URI = "ipfs://show-metadata";
const Status = { REGISTERED: 0, CANCELLED: 1, ENDED: 2 };
const DAY = 24 * 60 * 60;

describe("ShowRegistry", () => {
  let admin: HardhatEthersSigner;
  let organizer: HardhatEthersSigner;
  let otherOrganizer: HardhatEthersSigner;
  let operator: HardhatEthersSigner;
  let stranger: HardhatEthersSigner;
  let registry: ShowRegistry;

  let saleOpenTime: number;
  let showTime: number;

  beforeEach(async () => {
    [admin, organizer, otherOrganizer, operator, stranger] = await ethers.getSigners();

    const RegistryFactory = await ethers.getContractFactory("ShowRegistry");
    registry = await RegistryFactory.deploy(admin.address);

    await registry.connect(admin).grantRole(await registry.ORGANIZER_ROLE(), organizer.address);
    await registry.connect(admin).grantRole(await registry.ORGANIZER_ROLE(), otherOrganizer.address);
    await registry.connect(admin).grantRole(await registry.OPERATOR_ROLE(), operator.address);

    const now = await time.latest();
    saleOpenTime = now + 10 * DAY;
    showTime = now + 30 * DAY;
  });

  async function register(overrides: Partial<{ facePrice: bigint; totalSeats: number; saleOpenTime: number; showTime: number }> = {}) {
    const tx = await registry
      .connect(organizer)
      .registerShow(
        overrides.facePrice ?? FACE_PRICE,
        overrides.totalSeats ?? TOTAL_SEATS,
        overrides.saleOpenTime ?? saleOpenTime,
        overrides.showTime ?? showTime,
        METADATA_URI
      );
    await tx.wait();
    return 1n; // first show registered in a fresh registry
  }

  describe("registerShow", () => {
    it("stores the show as REGISTERED under the caller as organizer", async () => {
      const showId = await register();
      const s = await registry.shows(showId);
      expect(s.organizer).to.equal(organizer.address);
      expect(s.facePrice).to.equal(FACE_PRICE);
      expect(s.totalSeats).to.equal(TOTAL_SEATS);
      expect(s.status).to.equal(Status.REGISTERED);
    });

    it("emits ShowRegistered", async () => {
      await expect(
        registry.connect(organizer).registerShow(FACE_PRICE, TOTAL_SEATS, saleOpenTime, showTime, METADATA_URI)
      )
        .to.emit(registry, "ShowRegistered")
        .withArgs(1, organizer.address, FACE_PRICE, TOTAL_SEATS, saleOpenTime, showTime);
    });

    it("rejects a zero face price", async () => {
      await expect(
        registry.connect(organizer).registerShow(0, TOTAL_SEATS, saleOpenTime, showTime, METADATA_URI)
      ).to.be.revertedWithCustomError(registry, "InvalidPrice");
    });

    it("rejects zero total seats", async () => {
      await expect(
        registry.connect(organizer).registerShow(FACE_PRICE, 0, saleOpenTime, showTime, METADATA_URI)
      ).to.be.revertedWithCustomError(registry, "InvalidSeatCount");
    });

    it("rejects a sale open time at or after the show time", async () => {
      await expect(
        registry.connect(organizer).registerShow(FACE_PRICE, TOTAL_SEATS, showTime, showTime, METADATA_URI)
      ).to.be.revertedWithCustomError(registry, "InvalidTiming");
    });

    it("only ORGANIZER_ROLE can register a show", async () => {
      await expect(
        registry.connect(stranger).registerShow(FACE_PRICE, TOTAL_SEATS, saleOpenTime, showTime, METADATA_URI)
      ).to.be.revertedWithCustomError(registry, "AccessControlUnauthorizedAccount");
    });
  });

  describe("updateShow", () => {
    it("updates the catalog entry before the sale opens", async () => {
      const showId = await register();
      const newPrice = ethers.parseEther("2");

      await expect(registry.connect(organizer).updateShow(showId, newPrice, 50, saleOpenTime, showTime, "ipfs://v2"))
        .to.emit(registry, "ShowUpdated")
        .withArgs(showId, newPrice, 50, saleOpenTime, showTime);

      const s = await registry.shows(showId);
      expect(s.facePrice).to.equal(newPrice);
      expect(s.totalSeats).to.equal(50);
      expect(s.metadataURI).to.equal("ipfs://v2");
    });

    it("rejects updates once the sale window has opened", async () => {
      const showId = await register();
      await time.increaseTo(saleOpenTime + 1);

      await expect(
        registry.connect(organizer).updateShow(showId, FACE_PRICE, TOTAL_SEATS, saleOpenTime, showTime, METADATA_URI)
      ).to.be.revertedWithCustomError(registry, "SaleAlreadyOpen");
    });

    it("rejects updates from anyone but the show's own organizer", async () => {
      const showId = await register();
      await expect(
        registry.connect(otherOrganizer).updateShow(showId, FACE_PRICE, TOTAL_SEATS, saleOpenTime, showTime, METADATA_URI)
      ).to.be.revertedWithCustomError(registry, "NotShowOrganizer");
    });

    it("rejects updating a cancelled show", async () => {
      const showId = await register();
      await registry.connect(organizer).cancelShow(showId);

      await expect(
        registry.connect(organizer).updateShow(showId, FACE_PRICE, TOTAL_SEATS, saleOpenTime, showTime, METADATA_URI)
      ).to.be.revertedWithCustomError(registry, "ShowNotEditable");
    });

    it("reverts on a nonexistent show", async () => {
      await expect(
        registry.connect(organizer).updateShow(999, FACE_PRICE, TOTAL_SEATS, saleOpenTime, showTime, METADATA_URI)
      ).to.be.revertedWithCustomError(registry, "ShowDoesNotExist");
    });
  });

  describe("cancelShow", () => {
    it("cancels within the D-7 window", async () => {
      const showId = await register();
      await expect(registry.connect(organizer).cancelShow(showId)).to.emit(registry, "ShowCancelled").withArgs(showId);
      expect((await registry.shows(showId)).status).to.equal(Status.CANCELLED);
    });

    it("rejects cancellation once inside the D-7 window", async () => {
      const showId = await register();
      await time.increaseTo(showTime - 6 * DAY);

      await expect(registry.connect(organizer).cancelShow(showId)).to.be.revertedWithCustomError(
        registry,
        "CancellationWindowPassed"
      );
    });

    it("allows cancelling right at the D-7 boundary", async () => {
      const showId = await register();
      // one second before the deadline, not the exact instant - avoids
      // flaking on which block the tx itself lands in
      await time.increaseTo(showTime - 7 * DAY - 1);

      await expect(registry.connect(organizer).cancelShow(showId)).to.not.be.reverted;
    });

    it("only the show's organizer can cancel it", async () => {
      const showId = await register();
      await expect(registry.connect(otherOrganizer).cancelShow(showId)).to.be.revertedWithCustomError(
        registry,
        "NotShowOrganizer"
      );
    });

    it("cannot cancel an already-cancelled show", async () => {
      const showId = await register();
      await registry.connect(organizer).cancelShow(showId);
      await expect(registry.connect(organizer).cancelShow(showId)).to.be.revertedWithCustomError(registry, "ShowNotEditable");
    });
  });

  describe("endShow", () => {
    it("rejects ending a show before its showTime", async () => {
      const showId = await register();
      await expect(registry.connect(operator).endShow(showId)).to.be.revertedWithCustomError(registry, "ShowNotYetOver");
    });

    it("ends a show once its showTime has passed", async () => {
      const showId = await register();
      await time.increaseTo(showTime + 1);

      await expect(registry.connect(operator).endShow(showId)).to.emit(registry, "ShowEnded").withArgs(showId);
      expect((await registry.shows(showId)).status).to.equal(Status.ENDED);
    });

    it("only OPERATOR_ROLE can end a show, not even the organizer", async () => {
      const showId = await register();
      await time.increaseTo(showTime + 1);

      await expect(registry.connect(organizer).endShow(showId)).to.be.revertedWithCustomError(
        registry,
        "AccessControlUnauthorizedAccount"
      );
    });

    it("cannot end a cancelled show", async () => {
      const showId = await register();
      await registry.connect(organizer).cancelShow(showId);
      await time.increaseTo(showTime + 1);

      await expect(registry.connect(operator).endShow(showId)).to.be.revertedWithCustomError(registry, "ShowNotEditable");
    });
  });

  describe("isSaleOpen", () => {
    it("is false before saleOpenTime and true at/after it", async () => {
      const showId = await register();
      expect(await registry.isSaleOpen(showId)).to.equal(false);

      await time.increaseTo(saleOpenTime);
      expect(await registry.isSaleOpen(showId)).to.equal(true);
    });

    it("is false once the show is cancelled, even past saleOpenTime", async () => {
      const showId = await register();
      await registry.connect(organizer).cancelShow(showId);
      await time.increaseTo(saleOpenTime);

      expect(await registry.isSaleOpen(showId)).to.equal(false);
    });

    it("is false for a showId that was never registered (not a default-initialized false positive)", async () => {
      // A never-registered show reads back as a zeroed struct - status
      // REGISTERED(0) and saleOpenTime 0 - which would wrongly look "open"
      // without the explicit existence check.
      expect(await registry.isSaleOpen(999)).to.equal(false);
    });
  });

  describe("facePriceOf", () => {
    it("returns the registered face price", async () => {
      const showId = await register({ facePrice: ethers.parseEther("3") });
      expect(await registry.facePriceOf(showId)).to.equal(ethers.parseEther("3"));
    });

    it("reverts for a nonexistent show", async () => {
      await expect(registry.facePriceOf(999)).to.be.revertedWithCustomError(registry, "ShowDoesNotExist");
    });
  });
});
