import { expect } from "chai";
import { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { deployContracts } from "../scripts/deploy/deploy";

/**
 * Exercises deployContracts() itself, not a hand-rolled substitute of it.
 *
 * The other test files (TicketNFT.test.ts, Marketplace.test.ts, ...) grant
 * every role their beforeEach needs by hand, so a role deploy.ts forgets to
 * grant to admin never shows up there - that's exactly how the missing
 * GATE_ROLE and Marketplace OPERATOR_ROLE grants went unnoticed. This file
 * is the only place that actually calls deployContracts() and checks what
 * it wired up.
 */
describe("deployContracts", () => {
  let admin: HardhatEthersSigner;
  let custodyVault: HardhatEthersSigner;

  beforeEach(async () => {
    [admin, custodyVault] = await ethers.getSigners();
  });

  it("grants admin every role the backend needs to sign as a single wallet", async () => {
    const { showRegistry, ticketNFT, ticketVault, marketplace } = await deployContracts(
      admin.address,
      custodyVault.address,
      admin
    );

    expect(await showRegistry.hasRole(await showRegistry.ORGANIZER_ROLE(), admin.address)).to.be.true;
    expect(await showRegistry.hasRole(await showRegistry.OPERATOR_ROLE(), admin.address)).to.be.true;
    expect(await ticketNFT.hasRole(await ticketNFT.ORGANIZER_ROLE(), admin.address)).to.be.true;
    expect(await ticketNFT.hasRole(await ticketNFT.OPERATOR_ROLE(), admin.address)).to.be.true;
    expect(await ticketNFT.hasRole(await ticketNFT.GATE_ROLE(), admin.address)).to.be.true;
    expect(await ticketVault.hasRole(await ticketVault.OPERATOR_ROLE(), admin.address)).to.be.true;
    expect(await marketplace.hasRole(await marketplace.OPERATOR_ROLE(), admin.address)).to.be.true;
  });

  it("grants the Marketplace contract MARKETPLACE_ROLE on TicketNFT and TicketVault", async () => {
    const { ticketNFT, ticketVault, marketplace } = await deployContracts(admin.address, custodyVault.address, admin);
    const marketplaceAddress = await marketplace.getAddress();

    expect(await ticketNFT.hasRole(await ticketNFT.MARKETPLACE_ROLE(), marketplaceAddress)).to.be.true;
    expect(await ticketVault.hasRole(await ticketVault.MARKETPLACE_ROLE(), marketplaceAddress)).to.be.true;
  });
});
