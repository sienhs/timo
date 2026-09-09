import { expect } from "chai";
import { Wallet } from "ethers";
import { generateDynamicCode, signEntryQr, verifyEntryQr } from "../../src/entry/entryVerification";

describe("entryVerification", () => {
  const TOKEN_ID = "1";

  it("allows entry when the code is fresh and the signer is the current owner", async () => {
    const owner = Wallet.createRandom();
    const dynamicCode = generateDynamicCode(TOKEN_ID);
    const payload = await signEntryQr(owner, dynamicCode);

    const result = verifyEntryQr(payload, owner.address, new Set());

    expect(result.allowed).to.equal(true);
    expect(result.recoveredAddress).to.equal(owner.address);
  });

  it("rejects an expired code", async () => {
    const owner = Wallet.createRandom();
    const dynamicCode = generateDynamicCode(TOKEN_ID, -1); // already expired
    const payload = await signEntryQr(owner, dynamicCode);

    const result = verifyEntryQr(payload, owner.address, new Set());

    expect(result.allowed).to.equal(false);
    expect(result.reason).to.include("만료");
  });

  it("rejects a replayed (already-scanned) QR, e.g. a screenshot", async () => {
    const owner = Wallet.createRandom();
    const dynamicCode = generateDynamicCode(TOKEN_ID);
    const payload = await signEntryQr(owner, dynamicCode);
    const consumedCodes = new Set<string>();

    const first = verifyEntryQr(payload, owner.address, consumedCodes);
    expect(first.allowed).to.equal(true);

    const second = verifyEntryQr(payload, owner.address, consumedCodes);
    expect(second.allowed).to.equal(false);
    expect(second.reason).to.include("이미 사용된 코드");
  });

  it("rejects when the signer is not the ticket's current owner (e.g. ticket was resold since)", async () => {
    const previousOwner = Wallet.createRandom();
    const currentOwner = Wallet.createRandom();
    const dynamicCode = generateDynamicCode(TOKEN_ID);
    const payload = await signEntryQr(previousOwner, dynamicCode);

    const result = verifyEntryQr(payload, currentOwner.address, new Set());

    expect(result.allowed).to.equal(false);
    expect(result.reason).to.include("불일치");
  });

  it("rejects a tampered payload (code changed after signing)", async () => {
    const owner = Wallet.createRandom();
    const dynamicCode = generateDynamicCode(TOKEN_ID);
    const payload = await signEntryQr(owner, dynamicCode);
    const tampered = { ...payload, code: "attacker-supplied-code" };

    const result = verifyEntryQr(tampered, owner.address, new Set());

    expect(result.allowed).to.equal(false);
    expect(result.reason).to.include("불일치");
  });

  it("does not mark the code as consumed when a check before signature recovery already failed", async () => {
    const owner = Wallet.createRandom();
    const dynamicCode = generateDynamicCode(TOKEN_ID, -1); // expired
    const payload = await signEntryQr(owner, dynamicCode);
    const consumedCodes = new Set<string>();

    verifyEntryQr(payload, owner.address, consumedCodes);

    expect(consumedCodes.has(payload.code)).to.equal(false);
  });
});
