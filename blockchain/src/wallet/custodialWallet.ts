import { ethers } from "ethers";
import { createCipheriv, createDecipheriv, randomBytes } from "crypto";

/**
 * A per-user custodial EOA, protected by envelope encryption: a random
 * per-wallet key (the DEK) encrypts the private key via ethers' standard V3
 * keystore, and that DEK is itself "wrapped" (encrypted) by a single master
 * key. Two upgrades this buys over a single shared passphrase:
 *   - every wallet has its own encryption key, not one secret shared by all
 *   - swapping getMasterKey() below for a real KMS call (AWS KMS Decrypt,
 *     GCP KMS, Vault, ...) is the only change needed to stop the master key
 *     ever living in application memory/env at all - no call site changes.
 */
export interface CustodialWallet {
  userId: string;
  address: string;
  /** Ethereum V3 keystore JSON, encrypted with this wallet's own random DEK. */
  encryptedKeystoreJson: string;
  /** This wallet's DEK, wrapped (encrypted) with the master key. */
  wrappedDek: string;
}

const DEK_ALGORITHM = "aes-256-gcm";
const DEK_LENGTH_BYTES = 32;
const IV_LENGTH_BYTES = 12;
const AUTH_TAG_LENGTH_BYTES = 16;

/**
 * Generates a new EOA for a user and returns it already encrypted - callers
 * should never see or log the raw private key or the raw DEK.
 */
export async function createCustodialWallet(userId: string): Promise<CustodialWallet> {
  const wallet = ethers.Wallet.createRandom();
  const dek = randomBytes(DEK_LENGTH_BYTES);

  const encryptedKeystoreJson = await wallet.encrypt(dek.toString("hex"));
  const wrappedDek = wrapDek(dek, getMasterKey());

  return { userId, address: wallet.address, encryptedKeystoreJson, wrappedDek };
}

/**
 * Unwraps the DEK with the master key, then uses it to decrypt the keystore
 * back into a signer - e.g. to produce the entry-verification signature
 * described in the spec (an off-chain message signature, not a
 * transaction, so this never needs gas).
 */
export async function loadCustodialWallet(
  stored: Pick<CustodialWallet, "encryptedKeystoreJson" | "wrappedDek">
): Promise<ethers.Wallet> {
  const dek = unwrapDek(stored.wrappedDek, getMasterKey());
  const wallet = await ethers.Wallet.fromEncryptedJson(stored.encryptedKeystoreJson, dek.toString("hex"));
  return wallet as ethers.Wallet;
}

function wrapDek(dek: Buffer, masterKey: Buffer): string {
  const iv = randomBytes(IV_LENGTH_BYTES);
  const cipher = createCipheriv(DEK_ALGORITHM, masterKey, iv);
  const ciphertext = Buffer.concat([cipher.update(dek), cipher.final()]);
  // iv + authTag + ciphertext, all bundled into one portable base64 blob.
  return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]).toString("base64");
}

function unwrapDek(wrapped: string, masterKey: Buffer): Buffer {
  const data = Buffer.from(wrapped, "base64");
  const iv = data.subarray(0, IV_LENGTH_BYTES);
  const authTag = data.subarray(IV_LENGTH_BYTES, IV_LENGTH_BYTES + AUTH_TAG_LENGTH_BYTES);
  const ciphertext = data.subarray(IV_LENGTH_BYTES + AUTH_TAG_LENGTH_BYTES);

  const decipher = createDecipheriv(DEK_ALGORITHM, masterKey, iv);
  decipher.setAuthTag(authTag); // wrong master key -> this throws (GCM auth failure), never a silent bad decrypt
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
}

/**
 * WALLET_MASTER_KEY is still a single env var for this prototype - the real
 * fix (per the module doc comment above) is a real KMS. But unlike the
 * previous version of this function, at least a malformed/weak value fails
 * loudly here instead of silently "working" with whatever string happened
 * to be set.
 */
function getMasterKey(): Buffer {
  const raw = process.env.WALLET_MASTER_KEY;
  if (!raw || !/^[0-9a-fA-F]{64}$/.test(raw)) {
    throw new Error(
      "WALLET_MASTER_KEY must be set to a 64-character hex string (32 bytes). " +
        'Generate one with: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"'
    );
  }
  return Buffer.from(raw, "hex");
}
