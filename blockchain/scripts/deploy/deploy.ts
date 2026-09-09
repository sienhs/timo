import { ethers, network } from "hardhat";
import * as fs from "fs";
import * as path from "path";
import { ShowRegistry, TicketNFT, TicketVault, Marketplace } from "../../typechain-types";

export interface DeployedContracts {
  showRegistry: ShowRegistry;
  ticketNFT: TicketNFT;
  ticketVault: TicketVault;
  marketplace: Marketplace;
}

/**
 * Deploys all four contracts and wires Marketplace's MARKETPLACE_ROLE onto
 * TicketNFT/TicketVault (the one-time setup both README sections call out
 * as required before Marketplace.buy can work).
 *
 * Role-granting calls are sent by whoever is running this script, so they
 * only succeed automatically when `admin` is that same account (true for
 * local/dev). Deploying with a different `admin` (e.g. a multisig on a real
 * network) still deploys everything correctly, but that admin has to run
 * the grantRole calls itself afterwards - this function logs a reminder
 * instead of silently failing.
 */
export async function deployContracts(admin: string, custodyVaultAddress: string): Promise<DeployedContracts> {
  const [deployer] = await ethers.getSigners();

  const ShowRegistryFactory = await ethers.getContractFactory("ShowRegistry");
  const showRegistry = await ShowRegistryFactory.deploy(admin);
  await showRegistry.waitForDeployment();

  const TicketNFTFactory = await ethers.getContractFactory("TicketNFT");
  const ticketNFT = await TicketNFTFactory.deploy(admin, custodyVaultAddress, await showRegistry.getAddress());
  await ticketNFT.waitForDeployment();

  const TicketVaultFactory = await ethers.getContractFactory("TicketVault");
  const ticketVault = await TicketVaultFactory.deploy(admin);
  await ticketVault.waitForDeployment();

  const MarketplaceFactory = await ethers.getContractFactory("Marketplace");
  const marketplace = await MarketplaceFactory.deploy(admin, await ticketNFT.getAddress(), await ticketVault.getAddress());
  await marketplace.waitForDeployment();

  if (admin.toLowerCase() === deployer.address.toLowerCase()) {
    const marketplaceAddress = await marketplace.getAddress();
    await (await ticketNFT.grantRole(await ticketNFT.MARKETPLACE_ROLE(), marketplaceAddress)).wait();
    await (await ticketVault.grantRole(await ticketVault.MARKETPLACE_ROLE(), marketplaceAddress)).wait();
    console.log("Granted MARKETPLACE_ROLE to Marketplace on TicketNFT + TicketVault");
  } else {
    console.log(
      `admin (${admin}) is not the deploying account - grant MARKETPLACE_ROLE to ${await marketplace.getAddress()} ` +
        "on TicketNFT and TicketVault manually before Marketplace.buy will work"
    );
  }

  await writeDeploymentInfo({ showRegistry, ticketNFT, ticketVault, marketplace });

  return { showRegistry, ticketNFT, ticketVault, marketplace };
}

/**
 * Drops the freshly deployed addresses into tmp/deployment.json so other
 * one-off scripts (e.g. listTickets.ts) can find "whatever was deployed
 * most recently" without the caller having to copy-paste addresses by
 * hand. Only meaningful against a persistent network (`--network
 * localhost`) - on the default ephemeral network the file is still
 * written, but the chain (and therefore the addresses) disappear the
 * moment the process exits.
 */
async function writeDeploymentInfo(contracts: DeployedContracts): Promise<void> {
  const info = {
    network: network.name,
    deployedAt: new Date().toISOString(),
    showRegistry: await contracts.showRegistry.getAddress(),
    ticketNFT: await contracts.ticketNFT.getAddress(),
    ticketVault: await contracts.ticketVault.getAddress(),
    marketplace: await contracts.marketplace.getAddress(),
  };
  const outDir = path.join(__dirname, "../../tmp");
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(path.join(outDir, "deployment.json"), JSON.stringify(info, null, 2));
}

async function main() {
  const [deployer] = await ethers.getSigners();
  const admin = process.env.ADMIN_ADDRESS ?? deployer.address;
  const custodyVaultAddress = process.env.CUSTODY_VAULT_ADDRESS ?? deployer.address;

  console.log("Deployer:", deployer.address);
  console.log("Admin:", admin);
  console.log("Custody vault (holds revoked tickets):", custodyVaultAddress);

  const { showRegistry, ticketNFT, ticketVault, marketplace } = await deployContracts(admin, custodyVaultAddress);

  console.log("\nDeployed:");
  console.log("  ShowRegistry:", await showRegistry.getAddress());
  console.log("  TicketNFT:   ", await ticketNFT.getAddress());
  console.log("  TicketVault: ", await ticketVault.getAddress());
  console.log("  Marketplace: ", await marketplace.getAddress());
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
  });
}
