import { ethers } from "hardhat";
import { randomBytes } from "crypto";
import { createCustodialWallet, loadCustodialWallet } from "../../src/wallet/custodialWallet";
import { deployContracts, resolveDeployer } from "../deploy/deploy";
import dummyShowsData from "../../seed-data/dummy-shows.json";

/**
 * Deploys the contracts and seeds several dummy organizers, each with their
 * own real custodial wallet (via src/wallet/custodialWallet), registering a
 * few shows. There's no real organizer onboarding/self-service in this
 * project - the team seeds this data directly - so this script stands in
 * for that. Run with `npm run seed`.
 *
 * The organizer/show data itself lives in seed-data/dummy-shows.json, not
 * inline here, so that a future backend seed script (which needs the same
 * shows' off-chain fields - poster, description, venue - keyed by the same
 * showId) can read the same file instead of a second, easily-drifting copy
 * of "which dummy shows exist". Array order here is what determines the
 * on-chain showId (1-indexed, in registration order) - reordering this file
 * reorders the resulting showIds.
 *
 * Each dummy organizer gets a small amount of native gas funded from the
 * deployer so it can submit its own registerShow calls directly. That's
 * only because this script has no relayer of its own - it isn't how a real
 * organizer would work in production (see the "왜 커스터디얼인가" section of
 * the README: their transactions would go through the backend, and they'd
 * never hold or need gas at all).
 */

interface DummyShow {
  facePriceEth: string;
  totalSeats: number;
  metadataURI: string;
}

interface DummyOrganizer {
  label: string;
  shows: DummyShow[];
}

const DUMMY_ORGANIZERS: DummyOrganizer[] = dummyShowsData.organizers;

const ORGANIZER_FUNDING = ethers.parseEther("0.02");

async function main() {
  // Same ADMIN_PRIVATE_KEY/ADMIN_ADDRESS/CUSTODY_VAULT_ADDRESS resolution as
  // deploy.ts's own main() - this script deploys just as much as deploy.ts
  // does, so it needs the same "don't deploy as a well-known Hardhat account
  // when the RPC is reachable over a network" guard.
  const deployer = await resolveDeployer();
  const deployerAddress = await deployer.getAddress();
  const admin = process.env.ADMIN_ADDRESS ?? deployerAddress;
  const custodyVaultAddress = process.env.CUSTODY_VAULT_ADDRESS ?? admin;
  process.env.WALLET_MASTER_KEY ??= randomBytes(32).toString("hex");

  console.log("Deploying contracts...");
  const { showRegistry, ticketNFT, ticketVault, marketplace } = await deployContracts(admin, custodyVaultAddress, deployer);
  console.log("  ShowRegistry:", await showRegistry.getAddress());
  console.log("  TicketNFT:   ", await ticketNFT.getAddress());
  console.log("  TicketVault: ", await ticketVault.getAddress());
  console.log("  Marketplace: ", await marketplace.getAddress());

  const latestBlock = await ethers.provider.getBlock("latest");
  const now = latestBlock!.timestamp;
  const saleOpenTime = now - 3600; // already open, so booking demos work immediately
  const showTime = now + 30 * 24 * 3600; // 30 days out

  console.log("\nSeeding dummy organizers + shows...");
  let nextShowId = 1; // ShowRegistry's own auto-increment - registration order below must match

  for (const org of DUMMY_ORGANIZERS) {
    const custodial = await createCustodialWallet(org.label);
    const orgWallet = (await loadCustodialWallet(custodial)).connect(ethers.provider);

    await (await deployer.sendTransaction({ to: orgWallet.address, value: ORGANIZER_FUNDING })).wait();
    await (await showRegistry.grantRole(await showRegistry.ORGANIZER_ROLE(), orgWallet.address)).wait();
    await (await ticketNFT.grantRole(await ticketNFT.ORGANIZER_ROLE(), orgWallet.address)).wait();

    console.log(`\n${org.label}: ${orgWallet.address}`);

    for (const show of org.shows) {
      // Legacy demo data only has one price per show (facePriceEth) - repeat
      // it across all 5 sections rather than inventing per-section demo
      // numbers this file was never designed to carry.
      const price = ethers.parseEther(show.facePriceEth);
      await (
        await showRegistry
          .connect(orgWallet)
          .registerShow([price, price, price, price, price], show.totalSeats, saleOpenTime, showTime, show.metadataURI)
      ).wait();
      console.log(`  showId ${nextShowId}: ${show.metadataURI} (${show.facePriceEth} ETH, ${show.totalSeats} seats)`);
      nextShowId++;
    }
  }

  console.log("\nDone. All shows' sale windows are already open.");
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
