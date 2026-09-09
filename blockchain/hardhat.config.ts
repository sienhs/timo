import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

// Only wired up when actually selected with --network amoy; the in-memory
// "hardhat" network (default) and "localhost" (against `npm run node`) need
// none of this. See README.md before deploying to a real testnet.
const AMOY_RPC_URL = process.env.AMOY_RPC_URL ?? "";
const OPERATOR_PRIVATE_KEY = process.env.OPERATOR_PRIVATE_KEY ?? "";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      // OpenZeppelin 5.6's Bytes.sol uses the mcopy opcode (EIP-5656,
      // Cancun). solc 0.8.24 can compile for Cancun but doesn't default to
      // it, so this has to be explicit.
      evmVersion: "cancun",
    },
  },
  networks: {
    hardhat: {},
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    amoy: {
      url: AMOY_RPC_URL || "https://rpc-amoy.polygon.technology",
      accounts: OPERATOR_PRIVATE_KEY ? [OPERATOR_PRIVATE_KEY] : [],
    },
  },
};

export default config;
