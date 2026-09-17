import { ethers } from "hardhat";
import { deployContracts } from "../deploy/deploy";

const STATUS_NAMES = ["NONE", "OWNED", "LISTED", "REVOKED", "USED", "SOUVENIR"];

/**
 * Self-contained mint smoke test: deploys fresh contracts, registers one
 * show, mints one seat to a buyer, and prints the resulting ticket state.
 * Uses Hardhat's default accounts #0/#1/#2 as admin/organizer/buyer so it
 * needs no setup - run with `npm run mint:demo`.
 */
async function main() {
  const [admin, organizer, buyer] = await ethers.getSigners();

  console.log("Deploying contracts...");
  const { showRegistry, ticketNFT } = await deployContracts(admin.address, admin.address);
  console.log("  ShowRegistry:", await showRegistry.getAddress());
  console.log("  TicketNFT:   ", await ticketNFT.getAddress());

  await (await showRegistry.grantRole(await showRegistry.ORGANIZER_ROLE(), organizer.address)).wait();
  await (await ticketNFT.grantRole(await ticketNFT.ORGANIZER_ROLE(), organizer.address)).wait();
  console.log(`\nGranted ORGANIZER_ROLE to ${organizer.address} (Hardhat account #1)`);

  const now = (await ethers.provider.getBlock("latest"))!.timestamp;
  const facePrice = ethers.parseEther("0.05");
  const sectionIndex = 0;
  await (
    await showRegistry
      .connect(organizer)
      .registerShow(
        [facePrice, facePrice, facePrice, facePrice, facePrice],
        100,
        now - 60,
        now + 30 * 24 * 3600,
        "dummy://샘플 공연"
      )
  ).wait();
  const showId = 1;
  console.log(`Registered show ${showId} (facePrice ${ethers.formatEther(facePrice)} ETH, sale already open)`);

  const seatId = 12;
  await (await ticketNFT.connect(organizer).mintTicket(buyer.address, showId, seatId, sectionIndex)).wait();
  console.log(`\nMinted seat ${seatId} to ${buyer.address} (Hardhat account #2)`);

  const tokenId = await ticketNFT.seatTokenId(await ticketNFT.seatKey(showId, seatId));
  const ticket = await ticketNFT.tickets(tokenId);
  const owner = await ticketNFT.ownerOf(tokenId);

  console.log("\nTicket state:");
  console.log("  tokenId:  ", tokenId.toString());
  console.log("  owner:    ", owner);
  console.log("  showId:   ", ticket.showId.toString());
  console.log("  seatId:   ", ticket.seatId.toString());
  console.log("  facePrice:", ethers.formatEther(ticket.facePrice), "ETH");
  console.log("  status:   ", STATUS_NAMES[Number(ticket.status)]);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
