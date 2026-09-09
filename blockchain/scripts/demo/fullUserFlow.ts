import { ethers } from "hardhat";
import { randomBytes } from "crypto";
import * as fs from "fs";
import * as path from "path";
import * as QRCode from "qrcode";
import { createCustodialWallet, loadCustodialWallet } from "../../src/wallet/custodialWallet";
import { generateDynamicCode, signEntryQr, verifyEntryQr } from "../../src/entry/entryVerification";
import { deployContracts } from "../deploy/deploy";

const STATUS_NAMES = ["NONE", "OWNED", "LISTED", "REVOKED", "USED", "SOUVENIR"];

/**
 * End-to-end walkthrough of the flow described in the spec, entirely
 * within blockchain/ since backend/ doesn't exist yet:
 *
 *   회원가입(지갑 생성) -> 충전 -> 예매(발행) -> 입장 검증(동적 코드+서명) -> 게이트 처리
 *
 * Every step uses the actual deployed contracts, the actual wallet
 * encryption module, and the actual entry-verification module - nothing
 * here is mocked. Run with `npm run flow:demo`.
 */
async function main() {
  process.env.WALLET_MASTER_KEY ??= randomBytes(32).toString("hex");

  const [admin, organizer, gate] = await ethers.getSigners();

  console.log("=== 0. 컨트랙트 배포 ===");
  const { showRegistry, ticketNFT, ticketVault } = await deployContracts(admin.address, admin.address);
  await (await showRegistry.grantRole(await showRegistry.ORGANIZER_ROLE(), organizer.address)).wait();
  await (await ticketNFT.grantRole(await ticketNFT.ORGANIZER_ROLE(), organizer.address)).wait();
  await (await ticketNFT.grantRole(await ticketNFT.GATE_ROLE(), gate.address)).wait();
  await (await ticketVault.grantRole(await ticketVault.OPERATOR_ROLE(), admin.address)).wait();
  console.log("  ShowRegistry:", await showRegistry.getAddress());
  console.log("  TicketNFT:   ", await ticketNFT.getAddress());
  console.log("  TicketVault: ", await ticketVault.getAddress());

  console.log("\n=== 1. 공연 등록 (주최사) ===");
  const now = (await ethers.provider.getBlock("latest"))!.timestamp;
  const facePrice = ethers.parseEther("0.05");
  const showId = 1;
  await (
    await showRegistry.connect(organizer).registerShow(facePrice, 100, now - 60, now + 30 * 24 * 3600, "dummy://데모 공연")
  ).wait();
  console.log(`  showId ${showId} 등록 완료 (정가 ${ethers.formatEther(facePrice)} ETH, 예매 오픈됨)`);

  console.log("\n=== 2. 회원가입 -> 커스터디얼 지갑 생성 ===");
  const wallet = await createCustodialWallet("demo-user-42");
  console.log(`  userId: ${wallet.userId}`);
  console.log(`  지갑 주소: ${wallet.address}`);
  console.log("  (Spring Boot 연동 시 이 시점에 users 테이블에 address/encryptedKeystoreJson/wrappedDek 저장)");

  console.log("\n=== 3. 잔액 충전 (PG 결제 완료 가정) ===");
  const depositAmount = ethers.parseEther("0.1");
  await (
    await ticketVault.connect(admin).deposit(wallet.address, depositAmount, ethers.id("pg-order-demo-1"))
  ).wait();
  console.log(`  ${ethers.formatEther(depositAmount)} ETH 충전`);
  console.log(`  사용 가능 잔액: ${ethers.formatEther(await ticketVault.balanceOf(wallet.address))} ETH`);

  console.log("\n=== 4. 예매 (좌석 발행 + 대금 차감/주최사 정산) ===");
  const seatId = 7;
  await (await ticketNFT.connect(organizer).mintTicket(wallet.address, showId, seatId)).wait();
  await (
    await ticketVault.connect(admin).chargeForBooking(wallet.address, organizer.address, facePrice, ethers.id("order-demo-1"))
  ).wait();
  const tokenId = await ticketNFT.seatTokenId(await ticketNFT.seatKey(showId, seatId));
  console.log(`  좌석 ${seatId}번 티켓 발행 (tokenId=${tokenId})`);
  console.log(`  유저 잔여 잔액:     ${ethers.formatEther(await ticketVault.balanceOf(wallet.address))} ETH`);
  console.log(`  주최사 누적 판매액: ${ethers.formatEther(await ticketVault.balanceOf(organizer.address))} ETH`);

  console.log("\n=== 5. 입장용 QR 생성 - 동적 코드 + 지갑 서명 ===");
  const signer = await loadCustodialWallet(wallet); // DB에 저장된 두 값을 복호화해서 서명 가능한 지갑으로 복원
  const dynamicCode = generateDynamicCode(tokenId.toString(), 15); // 15초 유효, 앱이 주기적으로 새로 발급받는 값
  const qrPayload = await signEntryQr(signer, dynamicCode); // 유저 개인키가 실제로 쓰이는 유일한 순간 - 가스 없는 오프체인 서명
  const expiresAtKst = new Date(dynamicCode.expiresAt * 1000).toLocaleString("ko-KR", { timeZone: "Asia/Seoul" });
  console.log(`  동적 코드: ${dynamicCode.code} (만료 ${expiresAtKst} KST)`);
  console.log(`  QR payload(요약): tokenId=${qrPayload.tokenId}, code=${qrPayload.code.slice(0, 8)}...`);

  const qrData = JSON.stringify(qrPayload); // 실제 스캐너는 이 문자열을 QR에서 그대로 읽어 JSON.parse함
  const terminalQr = await QRCode.toString(qrData, { type: "terminal", small: true });
  console.log("\n  터미널 QR (폰 카메라로 직접 스캔 가능 - 15초 안에 스캔해야 함):");
  console.log(terminalQr);

  const outDir = path.join(__dirname, "../../tmp");
  fs.mkdirSync(outDir, { recursive: true });
  const qrFilePath = path.join(outDir, "entry-qr-demo.png");
  await QRCode.toFile(qrFilePath, qrData, { width: 400 });
  console.log(`  PNG 저장: ${qrFilePath}`);

  console.log("\n=== 6. 게이트 스캔 1회차 - 정상 입장 ===");
  const consumedCodes = new Set<string>(); // 실제로는 모든 게이트가 공유하는 DB 테이블
  const currentOwner = await ticketNFT.ownerOf(tokenId); // 스캔 시점의 최신 온체인 소유자를 매번 새로 조회
  const firstScan = verifyEntryQr(qrPayload, currentOwner, consumedCodes);
  console.log(`  검증 결과: allowed=${firstScan.allowed}${firstScan.reason ? `, reason=${firstScan.reason}` : ""}`);

  if (!firstScan.allowed) {
    throw new Error(`입장 거부: ${firstScan.reason}`);
  }

  await (await ticketNFT.connect(gate).markUsed(tokenId)).wait(); // 검증 통과했을 때만 온체인 USED 처리
  const finalTicket = await ticketNFT.tickets(tokenId);
  console.log(`  최종 상태: ${STATUS_NAMES[Number(finalTicket.status)]}`);

  console.log("\n=== 7. 게이트 스캔 2회차 - 같은 QR 재사용(캡처/재입장) 시도 ===");
  const secondScan = verifyEntryQr(qrPayload, currentOwner, consumedCodes);
  console.log(`  검증 결과: allowed=${secondScan.allowed}, reason=${secondScan.reason}`);
  if (secondScan.allowed) {
    throw new Error("재사용 QR이 통과해버림 - 검증 로직 버그");
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
