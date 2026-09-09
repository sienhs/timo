import { expect } from "chai";
import { ethers } from "ethers";
import { randomBytes } from "crypto";
import { createCustodialWallet, loadCustodialWallet } from "../../src/wallet/custodialWallet";

const VALID_MASTER_KEY = randomBytes(32).toString("hex");

describe("custodialWallet", () => {
  beforeEach(() => {
    process.env.WALLET_MASTER_KEY = VALID_MASTER_KEY;
  });

  it("creates a wallet with a valid checksummed address", async () => {
    const wallet = await createCustodialWallet("user-1");
    expect(ethers.isAddress(wallet.address)).to.equal(true);
    expect(wallet.userId).to.equal("user-1");
  });

  it("generates a different address per user", async () => {
    const a = await createCustodialWallet("user-a");
    const b = await createCustodialWallet("user-b");
    expect(a.address).to.not.equal(b.address);
  });

  it("wraps a different random DEK per wallet, even under the same master key", async () => {
    const a = await createCustodialWallet("user-x");
    const b = await createCustodialWallet("user-y");
    expect(a.wrappedDek).to.not.equal(b.wrappedDek);
  });

  it("round-trips through encryption back to the same address", async () => {
    const wallet = await createCustodialWallet("user-2");
    const reloaded = await loadCustodialWallet(wallet);
    expect(reloaded.address).to.equal(wallet.address);
  });

  it("the reloaded wallet can sign (proves we hold the real private key)", async () => {
    const wallet = await createCustodialWallet("user-3");
    const reloaded = await loadCustodialWallet(wallet);
    const signature = await reloaded.signMessage("entry-verification-challenge");
    const recovered = ethers.verifyMessage("entry-verification-challenge", signature);
    expect(recovered).to.equal(wallet.address);
  });

  it("fails to unwrap the DEK with the wrong master key", async () => {
    const wallet = await createCustodialWallet("user-4");
    process.env.WALLET_MASTER_KEY = randomBytes(32).toString("hex"); // a different, still well-formed key
    await expectRejection(loadCustodialWallet(wallet));
  });

  it("fails if the wrapped DEK has been tampered with (GCM auth tag catches it)", async () => {
    const wallet = await createCustodialWallet("user-tamper");
    const tampered = { ...wallet, wrappedDek: flipLastByte(wallet.wrappedDek) };
    await expectRejection(loadCustodialWallet(tampered));
  });

  it("throws a clear error when WALLET_MASTER_KEY is missing", async () => {
    delete process.env.WALLET_MASTER_KEY;
    await expectRejection(createCustodialWallet("user-5"), "WALLET_MASTER_KEY");
  });

  it("throws a clear error when WALLET_MASTER_KEY isn't a 64-character hex string", async () => {
    process.env.WALLET_MASTER_KEY = "too-short";
    await expectRejection(createCustodialWallet("user-6"), "WALLET_MASTER_KEY");
  });
});

async function expectRejection(promise: Promise<unknown>, messageIncludes?: string): Promise<void> {
  try {
    await promise;
    expect.fail("expected the promise to reject");
  } catch (err) {
    if (messageIncludes) {
      expect((err as Error).message).to.include(messageIncludes);
    } else {
      expect(err).to.be.instanceOf(Error);
    }
  }
}

function flipLastByte(base64: string): string {
  const buf = Buffer.from(base64, "base64");
  buf[buf.length - 1] ^= 0xff;
  return buf.toString("base64");
}
