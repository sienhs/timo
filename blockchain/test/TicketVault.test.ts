import { expect } from "chai";
import { ethers } from "hardhat";
import { TicketVault } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

const ONE = ethers.parseEther("1");
const HALF = ethers.parseEther("0.5");

function ref(label: string) {
  return ethers.id(label);
}

describe("TicketVault", () => {
  let admin: HardhatEthersSigner;
  let operator: HardhatEthersSigner;
  let marketplace: HardhatEthersSigner;
  let organizer: HardhatEthersSigner;
  let alice: HardhatEthersSigner;
  let bob: HardhatEthersSigner;
  let stranger: HardhatEthersSigner;
  let vault: TicketVault;

  beforeEach(async () => {
    [admin, operator, marketplace, organizer, alice, bob, stranger] = await ethers.getSigners();

    const VaultFactory = await ethers.getContractFactory("TicketVault");
    vault = await VaultFactory.deploy(admin.address);

    await vault.connect(admin).grantRole(await vault.OPERATOR_ROLE(), operator.address);
    await vault.connect(admin).grantRole(await vault.MARKETPLACE_ROLE(), marketplace.address);
  });

  describe("deposit", () => {
    it("credits usable balance", async () => {
      await expect(vault.connect(operator).deposit(alice.address, ONE, ref("pg-1")))
        .to.emit(vault, "Deposited")
        .withArgs(alice.address, ONE, ref("pg-1"));
      expect(await vault.balanceOf(alice.address)).to.equal(ONE);
    });

    it("rejects a replayed refId", async () => {
      await vault.connect(operator).deposit(alice.address, ONE, ref("pg-1"));
      await expect(vault.connect(operator).deposit(alice.address, ONE, ref("pg-1"))).to.be.revertedWithCustomError(
        vault,
        "DuplicateOperation"
      );
    });

    it("rejects a zero refId", async () => {
      await expect(vault.connect(operator).deposit(alice.address, ONE, ethers.ZeroHash)).to.be.revertedWithCustomError(
        vault,
        "ZeroRefId"
      );
    });

    it("only OPERATOR_ROLE can deposit", async () => {
      await expect(vault.connect(stranger).deposit(alice.address, ONE, ref("pg-1"))).to.be.revertedWithCustomError(
        vault,
        "AccessControlUnauthorizedAccount"
      );
    });
  });

  describe("chargeForBooking", () => {
    beforeEach(async () => {
      await vault.connect(operator).deposit(alice.address, ONE, ref("pg-alice"));
    });

    it("moves funds from buyer to organizer", async () => {
      await expect(vault.connect(operator).chargeForBooking(alice.address, organizer.address, ONE, ref("order-1")))
        .to.emit(vault, "ChargedForBooking")
        .withArgs(alice.address, organizer.address, ONE, ref("order-1"));

      expect(await vault.balanceOf(alice.address)).to.equal(0);
      expect(await vault.balanceOf(organizer.address)).to.equal(ONE);
    });

    it("rejects insufficient balance", async () => {
      await expect(
        vault.connect(operator).chargeForBooking(alice.address, organizer.address, ONE * 2n, ref("order-2"))
      ).to.be.revertedWithCustomError(vault, "ERC20InsufficientBalance");
    });

    it("a retried orderId is a no-op failure, not a double charge", async () => {
      await vault.connect(operator).chargeForBooking(alice.address, organizer.address, HALF, ref("order-3"));
      await expect(
        vault.connect(operator).chargeForBooking(alice.address, organizer.address, HALF, ref("order-3"))
      ).to.be.revertedWithCustomError(vault, "DuplicateOperation");
      expect(await vault.balanceOf(organizer.address)).to.equal(HALF);
    });
  });

  describe("refund", () => {
    beforeEach(async () => {
      // refund claws money back out of the organizer, so the organizer
      // needs a prior balance to claw back from - exactly what a real
      // refund reverses.
      await vault.connect(operator).deposit(organizer.address, ONE, ref("pg-organizer"));
    });

    it("claws the amount back from the organizer and credits the user, with no fee deducted", async () => {
      await expect(vault.connect(operator).refund(alice.address, organizer.address, ONE, ref("refund-1")))
        .to.emit(vault, "Refunded")
        .withArgs(alice.address, organizer.address, ONE, ref("refund-1"));
      expect(await vault.balanceOf(alice.address)).to.equal(ONE);
      expect(await vault.balanceOf(organizer.address)).to.equal(0);
    });

    it("rejects a refund the organizer's balance can't cover", async () => {
      await expect(
        vault.connect(operator).refund(alice.address, organizer.address, ONE * 2n, ref("refund-2"))
      ).to.be.revertedWithCustomError(vault, "ERC20InsufficientBalance");
    });
  });

  describe("settleTransfer (secondary market)", () => {
    beforeEach(async () => {
      await vault.connect(operator).deposit(bob.address, ONE, ref("pg-bob"));
    });

    it("moves the full price from buyer to seller", async () => {
      await expect(vault.connect(marketplace).settleTransfer(alice.address, bob.address, ONE, ref("trade-1")))
        .to.emit(vault, "TransferSettled")
        .withArgs(alice.address, bob.address, ONE, ref("trade-1"));

      expect(await vault.balanceOf(bob.address)).to.equal(0);
      expect(await vault.balanceOf(alice.address)).to.equal(ONE);
    });

    it("only MARKETPLACE_ROLE can settle", async () => {
      await expect(
        vault.connect(operator).settleTransfer(alice.address, bob.address, ONE, ref("trade-2"))
      ).to.be.revertedWithCustomError(vault, "AccessControlUnauthorizedAccount");
    });

    it("rejects a zero price", async () => {
      await expect(
        vault.connect(marketplace).settleTransfer(alice.address, bob.address, 0, ref("trade-3"))
      ).to.be.revertedWithCustomError(vault, "ZeroAmount");
    });

    it("draws from the same balance a primary booking would have used (no double-spend across layers)", async () => {
      // bob has exactly 1 ETH-equivalent; spend it all on a secondary purchase,
      // then a primary booking charge against the same balance must fail.
      await vault.connect(marketplace).settleTransfer(alice.address, bob.address, ONE, ref("trade-4"));
      await expect(
        vault.connect(operator).chargeForBooking(bob.address, organizer.address, ONE, ref("order-after-trade"))
      ).to.be.revertedWithCustomError(vault, "ERC20InsufficientBalance");
    });
  });

  describe("succession waitlist", () => {
    beforeEach(async () => {
      await vault.connect(operator).deposit(alice.address, ONE, ref("pg-alice-2"));
    });

    it("locking moves funds out of usable balance into locked", async () => {
      await expect(vault.connect(operator).lockForWaitlist(alice.address, ONE, ref("wl-1")))
        .to.emit(vault, "WaitlistLocked")
        .withArgs(alice.address, ref("wl-1"), ONE);

      expect(await vault.balanceOf(alice.address)).to.equal(0);
      expect(await vault.lockedOf(alice.address)).to.equal(ONE);
    });

    it("locked funds are not usable for a booking charge", async () => {
      await vault.connect(operator).lockForWaitlist(alice.address, ONE, ref("wl-2"));
      await expect(
        vault.connect(operator).chargeForBooking(alice.address, organizer.address, ONE, ref("order-x"))
      ).to.be.revertedWithCustomError(vault, "ERC20InsufficientBalance");
    });

    it("cannot lock the same waitlistId twice", async () => {
      await vault.connect(operator).lockForWaitlist(alice.address, HALF, ref("wl-3"));
      await expect(vault.connect(operator).lockForWaitlist(alice.address, HALF, ref("wl-3"))).to.be.revertedWithCustomError(
        vault,
        "WaitlistLockAlreadyActive"
      );
    });

    it("unlock releases the full amount back to usable balance", async () => {
      await vault.connect(operator).lockForWaitlist(alice.address, ONE, ref("wl-4"));
      await expect(vault.connect(operator).unlockWaitlist(ref("wl-4")))
        .to.emit(vault, "WaitlistUnlocked")
        .withArgs(alice.address, ref("wl-4"), ONE);

      expect(await vault.balanceOf(alice.address)).to.equal(ONE);
      expect(await vault.lockedOf(alice.address)).to.equal(0);
    });

    it("cannot unlock a waitlistId that isn't active", async () => {
      await expect(vault.connect(operator).unlockWaitlist(ref("never-locked"))).to.be.revertedWithCustomError(
        vault,
        "WaitlistLockNotActive"
      );
    });

    it("claiming at a lower actual price refunds the difference and pays the organizer only the actual price", async () => {
      await vault.connect(operator).lockForWaitlist(alice.address, ONE, ref("wl-5")); // locked the highest grade price
      const actualPrice = HALF; // the recovered seat turned out to be a cheaper grade

      await expect(vault.connect(operator).claimWaitlistSeat(ref("wl-5"), organizer.address, actualPrice))
        .to.emit(vault, "WaitlistClaimed")
        .withArgs(alice.address, organizer.address, ref("wl-5"), actualPrice, ONE - actualPrice);

      expect(await vault.lockedOf(alice.address)).to.equal(0);
      expect(await vault.balanceOf(alice.address)).to.equal(ONE - actualPrice); // difference released
      expect(await vault.balanceOf(organizer.address)).to.equal(actualPrice);
    });

    it("claiming at exactly the locked amount refunds nothing", async () => {
      await vault.connect(operator).lockForWaitlist(alice.address, ONE, ref("wl-6"));
      await vault.connect(operator).claimWaitlistSeat(ref("wl-6"), organizer.address, ONE);

      expect(await vault.balanceOf(alice.address)).to.equal(0);
      expect(await vault.balanceOf(organizer.address)).to.equal(ONE);
    });

    it("rejects an actual price above what was locked", async () => {
      await vault.connect(operator).lockForWaitlist(alice.address, HALF, ref("wl-7"));
      await expect(
        vault.connect(operator).claimWaitlistSeat(ref("wl-7"), organizer.address, ONE)
      ).to.be.revertedWithCustomError(vault, "ActualPriceExceedsLocked");
    });

    it("a claimed waitlistId cannot be claimed or unlocked again", async () => {
      await vault.connect(operator).lockForWaitlist(alice.address, ONE, ref("wl-8"));
      await vault.connect(operator).claimWaitlistSeat(ref("wl-8"), organizer.address, ONE);

      await expect(vault.connect(operator).claimWaitlistSeat(ref("wl-8"), organizer.address, ONE)).to.be.revertedWithCustomError(
        vault,
        "WaitlistLockNotActive"
      );
      await expect(vault.connect(operator).unlockWaitlist(ref("wl-8"))).to.be.revertedWithCustomError(
        vault,
        "WaitlistLockNotActive"
      );
    });
  });
});
