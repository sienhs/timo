import { ethers } from "hardhat";
import * as fs from "fs";
import * as path from "path";

const STATUS_NAMES = ["NONE", "OWNED", "LISTED", "REVOKED", "USED", "SOUVENIR"];
const LISTED_STATUS = 2;

interface DeploymentInfo {
  network: string;
  deployedAt: string;
  showRegistry: string;
  ticketNFT: string;
  ticketVault: string;
  marketplace: string;
}

/**
 * Reads whichever TicketNFT was deployed most recently (tmp/deployment.json,
 * written by deployContracts()) and prints every minted ticket's current
 * on-chain state. TicketNFT deliberately isn't ERC721Enumerable (extra
 * storage writes on every transfer for a feature only this debug script
 * needs), and tokenIds are never reused/burned, so tokenId=1,2,3... is
 * walked in order until the first NONE status - that's the first tokenId
 * that was never minted, i.e. the end of the list.
 *
 * Only useful against a persistent chain: run `npx hardhat node`, then run
 * whatever seeds it (seed/deploy/mint:demo/flow:demo/qr:live) with
 * `--network localhost`, then `npm run tickets:list -- --network localhost`.
 */
async function main() {
  const deploymentPath = path.join(__dirname, "../../tmp/deployment.json");
  if (!fs.existsSync(deploymentPath)) {
    throw new Error(
      `${deploymentPath} 를 찾을 수 없습니다. 먼저 --network localhost 로 deploy/seed/mint:demo/flow:demo/qr:live 중 하나를 실행하세요.`
    );
  }
  const deployment: DeploymentInfo = JSON.parse(fs.readFileSync(deploymentPath, "utf-8"));

  const ticketNFT = await ethers.getContractAt("TicketNFT", deployment.ticketNFT);
  const showRegistry = await ethers.getContractAt("ShowRegistry", deployment.showRegistry);

  console.log(`TicketNFT:  ${deployment.ticketNFT}`);
  console.log(`네트워크:   ${deployment.network} (배포 시각 ${deployment.deployedAt})\n`);

  const showMetadataCache = new Map<string, string>();
  async function metadataOf(showId: bigint): Promise<string> {
    const key = showId.toString();
    if (!showMetadataCache.has(key)) {
      const show = await showRegistry.shows(showId);
      showMetadataCache.set(key, show.metadataURI);
    }
    return showMetadataCache.get(key)!;
  }

  const rows: Record<string, string>[] = [];
  const statusCounts: Record<string, number> = {};

  let tokenId = 1n;
  while (true) {
    const ticket = await ticketNFT.tickets(tokenId);
    if (Number(ticket.status) === 0) break; // NONE = 이 tokenId부터는 아직 민팅된 적 없음 -> 목록 끝

    const statusName = STATUS_NAMES[Number(ticket.status)];
    statusCounts[statusName] = (statusCounts[statusName] ?? 0) + 1;

    rows.push({
      tokenId: tokenId.toString(),
      show: `#${ticket.showId} (${await metadataOf(ticket.showId)})`,
      seatId: ticket.seatId.toString(),
      status: statusName,
      "facePrice(ETH)": ethers.formatEther(ticket.facePrice),
      "listPrice(ETH)": Number(ticket.status) === LISTED_STATUS ? ethers.formatEther(ticket.listPrice) : "-",
      owner: await ticketNFT.ownerOf(tokenId),
    });
    tokenId++;
  }

  if (rows.length === 0) {
    console.log("발행된 티켓이 없습니다.");
    return;
  }

  console.table(rows);
  console.log("상태별 집계:", statusCounts);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
