import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-ethers"
import "@nomicfoundation/hardhat-toolbox"
import "@nomicfoundation/hardhat-foundry"
import "hardhat-tracer"

import "dotenv/config"

const RPC_URL = process.env.RPC_URL || "https://ethereum-rpc.publicnode.com"

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
      forking: {
        url: RPC_URL,
      },
    },
  },

  typechain: {
    outDir: "typechain",
    target: "ethers-v6",
  },
}

export default config
