import { ethers, network } from "hardhat";
import { Signer } from "ethers";
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
 *
 * `deployerSigner` defaults to Hardhat's first configured account (its
 * behavior before this parameter existed). Pass a dedicated wallet here to
 * deploy from - and become admin of - a key that isn't one of Hardhat's 20
 * well-known accounts. That matters the moment this chain is reachable over
 * a network (e.g. hosted on an EC2 instance): Hardhat's default accounts are
 * unlocked *on the node itself*, so anyone who can reach the RPC endpoint
 * can send transactions "as" account #0 without ever knowing its private
 * key. A dedicated wallet's key never touches the node - it signs locally
 * and only the already-signed transaction is submitted - so RPC access
 * alone can't impersonate it.
 */
export async function deployContracts(
  admin: string,
  custodyVaultAddress: string,
  deployerSigner?: Signer
): Promise<DeployedContracts> {
  const deployer = deployerSigner ?? (await ethers.getSigners())[0];
  const deployerAddress = await deployer.getAddress();

  const ShowRegistryFactory = await ethers.getContractFactory("ShowRegistry", deployer);
  const showRegistry = await ShowRegistryFactory.deploy(admin);
  await showRegistry.waitForDeployment();

  const TicketNFTFactory = await ethers.getContractFactory("TicketNFT", deployer);
  const ticketNFT = await TicketNFTFactory.deploy(admin, custodyVaultAddress, await showRegistry.getAddress());
  await ticketNFT.waitForDeployment();

  const TicketVaultFactory = await ethers.getContractFactory("TicketVault", deployer);
  const ticketVault = await TicketVaultFactory.deploy(admin);
  await ticketVault.waitForDeployment();

  const MarketplaceFactory = await ethers.getContractFactory("Marketplace", deployer);
  const marketplace = await MarketplaceFactory.deploy(admin, await ticketNFT.getAddress(), await ticketVault.getAddress());
  await marketplace.waitForDeployment();

  if (admin.toLowerCase() === deployerAddress.toLowerCase()) {
    const marketplaceAddress = await marketplace.getAddress();
    await (await ticketNFT.grantRole(await ticketNFT.MARKETPLACE_ROLE(), marketplaceAddress)).wait();
    await (await ticketVault.grantRole(await ticketVault.MARKETPLACE_ROLE(), marketplaceAddress)).wait();
    console.log("Granted MARKETPLACE_ROLE to Marketplace on TicketNFT + TicketVault");

    // The backend signs every routine call (registerShow/mintTicket/chargeForBooking/deposit/
    // refund/revoke) as this same admin address. DEFAULT_ADMIN_ROLE (set on admin by each
    // contract's constructor) only lets it manage other roles - it doesn't satisfy onlyRole
    // checks for ORGANIZER_ROLE/OPERATOR_ROLE, so those have to be granted explicitly too.
    await (await showRegistry.grantRole(await showRegistry.ORGANIZER_ROLE(), admin)).wait();
    await (await showRegistry.grantRole(await showRegistry.OPERATOR_ROLE(), admin)).wait();
    await (await ticketNFT.grantRole(await ticketNFT.ORGANIZER_ROLE(), admin)).wait();
    await (await ticketNFT.grantRole(await ticketNFT.OPERATOR_ROLE(), admin)).wait();
    await (await ticketVault.grantRole(await ticketVault.OPERATOR_ROLE(), admin)).wait();
    console.log("Granted ORGANIZER_ROLE/OPERATOR_ROLE to admin on ShowRegistry, TicketNFT, TicketVault");
  } else {
    console.log(
      `admin (${admin}) is not the deploying account - grant MARKETPLACE_ROLE to ${await marketplace.getAddress()} ` +
        "on TicketNFT and TicketVault, and ORGANIZER_ROLE/OPERATOR_ROLE to admin, manually before the backend will work"
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

/**
 * ADMIN_PRIVATE_KEY, when set, deploys from - and makes admin - a wallet
 * that isn't one of Hardhat's 20 well-known accounts (see the warning on
 * deployContracts). On hardhat/localhost this wallet also gets its balance
 * set directly via hardhat_setBalance, since there's no faucet for a chain
 * we control ourselves. Falls back to Hardhat's first default account when
 * unset, so quick local experiments still work with zero setup.
 */
export async function resolveDeployer(): Promise<Signer> {
  const adminPrivateKey = process.env.ADMIN_PRIVATE_KEY;
  if (!adminPrivateKey) {
    return (await ethers.getSigners())[0];
  }

  const wallet = new ethers.Wallet(adminPrivateKey, ethers.provider);

  if (network.name === "hardhat" || network.name === "localhost") {
    const oneMillionEthInWei = ethers.parseEther("1000000");
    await network.provider.send("hardhat_setBalance", [wallet.address, ethers.toBeHex(oneMillionEthInWei)]);
  }

  return wallet;
}

async function main() {
  const deployer = await resolveDeployer();
  const deployerAddress = await deployer.getAddress();
  const admin = process.env.ADMIN_ADDRESS ?? deployerAddress;
  const custodyVaultAddress = process.env.CUSTODY_VAULT_ADDRESS ?? admin;

  console.log("Deployer:", deployerAddress);
  console.log("Admin:", admin);
  console.log("Custody vault (holds revoked tickets):", custodyVaultAddress);

  const { showRegistry, ticketNFT, ticketVault, marketplace } = await deployContracts(admin, custodyVaultAddress, deployer);

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
