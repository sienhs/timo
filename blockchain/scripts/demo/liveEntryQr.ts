import { ethers } from "hardhat";
import { randomBytes } from "crypto";
import * as readline from "readline";
import * as QRCode from "qrcode";
import { createCustodialWallet, loadCustodialWallet } from "../../src/wallet/custodialWallet";
import { EntryQrPayload, generateDynamicCode, signEntryQr, verifyEntryQr } from "../../src/entry/entryVerification";
import { deployContracts } from "../deploy/deploy";

const TTL_SECONDS = 15;
const STATUS_NAMES = ["NONE", "OWNED", "LISTED", "REVOKED", "USED", "SOUVENIR"];

/**
 * Interactive simulation of both sides of entry verification in one
 * terminal: the ticket holder's screen (QR auto-rotating every
 * TTL_SECONDS) and the gate manager's scanner (press Enter to scan
 * whatever QR is on screen *right now*). A real deployment would be two
 * separate devices; here they're the same process so pressing Enter can
 * read the in-memory payload directly instead of needing file/network IPC
 * between two scripts. Run with `npm run qr:live`, Ctrl+C to quit early.
 */
async function main() {
  process.env.WALLET_MASTER_KEY ??= randomBytes(32).toString("hex");
  const [admin, organizer, gate] = await ethers.getSigners();

  const { showRegistry, ticketNFT } = await deployContracts(admin.address, admin.address);
  await (await showRegistry.grantRole(await showRegistry.ORGANIZER_ROLE(), organizer.address)).wait();
  await (await ticketNFT.grantRole(await ticketNFT.ORGANIZER_ROLE(), organizer.address)).wait();
  await (await ticketNFT.grantRole(await ticketNFT.GATE_ROLE(), gate.address)).wait();

  const now = (await ethers.provider.getBlock("latest"))!.timestamp;
  const price = ethers.parseEther("0.05");
  await (
    await showRegistry
      .connect(organizer)
      .registerShow([price, price, price, price, price], 100, now - 60, now + 30 * 24 * 3600, "dummy://라이브 게이트 데모")
  ).wait();

  const wallet = await createCustodialWallet("live-gate-demo-user");
  await (await ticketNFT.connect(organizer).mintTicket(wallet.address, 1, 1, 0)).wait();
  const tokenId = await ticketNFT.seatTokenId(await ticketNFT.seatKey(1, 1));
  const signer = await loadCustodialWallet(wallet);

  const consumedCodes = new Set<string>();
  let currentPayload: EntryQrPayload;
  let rotation = 0;
  let entered = false;
  let scanning = false;

  async function rotate() {
    if (entered) return;
    rotation++;
    const dynamicCode = generateDynamicCode(tokenId.toString(), TTL_SECONDS);
    currentPayload = await signEntryQr(signer, dynamicCode);
    const terminalQr = await QRCode.toString(JSON.stringify(currentPayload), { type: "terminal", small: true });
    const expiresAtKst = new Date(dynamicCode.expiresAt * 1000).toLocaleTimeString("ko-KR", { timeZone: "Asia/Seoul" });

    console.clear();
    console.log(`[유저 화면] tokenId=${tokenId}  소유자=${wallet.address}`);
    console.log(`[회전 #${rotation}] code=${dynamicCode.code}  만료 ${expiresAtKst} (KST)\n`);
    console.log(terminalQr);
    console.log(`Enter = 게이트 매니저가 지금 이 QR을 스캔  |  ${TTL_SECONDS}초마다 자동 회전  |  종료: Ctrl+C`);
  }

  await rotate();
  const rotationTimer = setInterval(rotate, TTL_SECONDS * 1000);

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  rl.on("line", async () => {
    if (entered || scanning) return;
    scanning = true;

    console.log("\n[게이트 스캔] 검증 중...");
    const currentOwner = await ticketNFT.ownerOf(tokenId);
    const result = verifyEntryQr(currentPayload, currentOwner, consumedCodes);

    if (!result.allowed) {
      console.log(`  거부: ${result.reason}\n(계속 회전 중 - 다음 회전 후 다시 Enter로 스캔해보세요)`);
      scanning = false;
      return;
    }

    await (await ticketNFT.connect(gate).markUsed(tokenId)).wait();
    const ticket = await ticketNFT.tickets(tokenId);
    console.log(`  허용 - 온체인 상태: ${STATUS_NAMES[Number(ticket.status)]}`);
    console.log("\n입장 완료. 프로세스를 종료합니다.");

    entered = true;
    clearInterval(rotationTimer);
    rl.close();
  });
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
