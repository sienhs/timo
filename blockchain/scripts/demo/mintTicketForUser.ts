import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";
import { createCustodialWallet } from "../../src/wallet/custodialWallet";

/**
 * Mints one ticket for a specific showId/seatId out of whatever is
 * *currently* seeded on a persistent chain (tmp/deployment.json), instead
 * of redeploying fresh contracts the way mint:demo/flow:demo/qr:live do.
 * Useful for "as this exact organizer from npm run seed, issue a ticket to
 * a specific user" without throwing away the rest of the seeded catalog.
 *
 * Env vars (all optional): SHOW_ID (default 1), SEAT_ID (default 1),
 * SECTION_INDEX (default 0, which of the show's 5 registered section
 * prices this seat is charged at), USER_ID (default a timestamped label).
 *
 *   SHOW_ID=1 SEAT_ID=5 SECTION_INDEX=2 USER_ID=demo-buyer npm run mint:seeded -- --network localhost
 *
 * Caveat: seedDummyShows.ts's organizer wallets are never persisted to
 * disk - their encrypted keystore only ever existed in that one process's
 * memory - so there's no way to sign as the *actual* seeded organizer from
 * a separate script run. This mints using `admin` instead, after granting
 * it ORGANIZER_ROLE if it doesn't already have it. TicketNFT.mintTicket
 * only checks "does the caller hold ORGANIZER_ROLE at all", not "is the
 * caller *this show's* registered organizer" (see contracts/TicketNFT.sol),
 * so the minted ticket is otherwise identical to one the real organizer
 * would have issued.
 */
async function main() {
  const showId = BigInt(process.env.SHOW_ID ?? "1");
  const seatId = BigInt(process.env.SEAT_ID ?? "1");
  const sectionIndex = Number(process.env.SECTION_INDEX ?? "0"); // small (0-4), no precision concern - plain number is fine
  const userId = process.env.USER_ID ?? `demo-user-${Date.now()}`;

  const deploymentPath = path.join(__dirname, "../../tmp/deployment.json");
  if (!fs.existsSync(deploymentPath)) {
    throw new Error(
      `${deploymentPath} 를 찾을 수 없습니다. 먼저 --network localhost 로 deploy 또는 seed를 실행하세요.`
    );
  }
  const deployment = JSON.parse(fs.readFileSync(deploymentPath, "utf-8"));

  const [admin] = await ethers.getSigners();
  const ticketNFT = await ethers.getContractAt("TicketNFT", deployment.ticketNFT);
  const showRegistry = await ethers.getContractAt("ShowRegistry", deployment.showRegistry);

  const show = await showRegistry.shows(showId);
  if (show.organizer === ethers.ZeroAddress) {
    throw new Error(`showId=${showId} 는 등록된 적 없습니다. 먼저 npm run seed 로 공연을 등록하세요.`);
  }

  const ORGANIZER_ROLE = await ticketNFT.ORGANIZER_ROLE();
  if (!(await ticketNFT.hasRole(ORGANIZER_ROLE, admin.address))) {
    await (await ticketNFT.grantRole(ORGANIZER_ROLE, admin.address)).wait();
  }

  const wallet = await createCustodialWallet(userId);
  await (await ticketNFT.connect(admin).mintTicket(wallet.address, showId, seatId, sectionIndex)).wait();

  const tokenId = await ticketNFT.seatTokenId(await ticketNFT.seatKey(showId, seatId));
  const ticket = await ticketNFT.tickets(tokenId);

  console.log("발행 완료");
  console.log(`  공연: showId=${showId} (${show.metadataURI})`);
  console.log(`  좌석: ${seatId}`);
  console.log(`  유저: ${userId} -> ${wallet.address}`);
  console.log(`  tokenId: ${tokenId}`);
  console.log(`  정가: ${ethers.formatEther(ticket.facePrice)} ETH`);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
