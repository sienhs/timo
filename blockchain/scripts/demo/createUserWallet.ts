import { createCustodialWallet, loadCustodialWallet } from "../../src/wallet/custodialWallet";

/**
 * Demonstrates the custodial wallet flow end to end: generate a wallet for
 * a user, confirm it can be decrypted back, and show what a backend would
 * persist (never the raw private key). Run with `npm run wallet:create`.
 * userId is hardcoded here for the demo; real callers are the backend's
 * signup flow, not this CLI script.
 */
async function main() {
  const userId = "demo-user-1";

  const wallet = await createCustodialWallet(userId);
  console.log("Created custodial wallet:");
  console.log("  userId:", wallet.userId);
  console.log("  address:", wallet.address);
  console.log("  encryptedKeystoreJson + wrappedDek (this is what gets stored):");
  console.log("   ", wallet.encryptedKeystoreJson);
  console.log("   ", wallet.wrappedDek);

  const reloaded = await loadCustodialWallet(wallet);
  console.log("\nDecrypted back for signing - address matches:", reloaded.address === wallet.address);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
