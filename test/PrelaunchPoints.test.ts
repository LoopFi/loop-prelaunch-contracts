import { expect } from "chai"
import hre, { ethers, network } from "hardhat"
import {
  time,
  loadFixture,
  impersonateAccount,
} from "@nomicfoundation/hardhat-toolbox/network-helpers"
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs"
import fetch from "node-fetch"
import "dotenv/config"
import { IERC20 } from "../typechain"

const ZEROX_API_KEY = process.env.ZEROX_API_KEY || ""

describe.only("0x API integration", function () {
  it("it should be able to use a 0x API mainnet quote", async function () {
    // Config
    const provider = ethers.getDefaultProvider()

    // Quote parameters
    const sellToken = "0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0"
    //"0xcd5fe23c85820f7b72d0926fc9b05b43e359b7ee" // weETH
    const buyToken = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee" // ETH
    const sellAmount = ethers.parseEther("1")
    const exchangeProxy = "0xdef1c0ded9bec7f1a1670819833240f027b25eff"

    const takerAddress = "0x43fC188f003e444e9e538189Fc675acDfB8f5d12"

    //"0x1C3DC4F4eE50D483289beF519C598847cd447A19" // An account with sufficient weETH balance on mainnet

    // Send ETH to account
    const [signer] = await ethers.getSigners()
    const tx = {
      to: takerAddress,
      value: ethers.parseEther("10"),
    }
    await signer.sendTransaction(tx)

    // Give weETH to user
    await impersonateAccount(takerAddress)
    const taker = await ethers.getSigner(takerAddress)
    const weETH = (await ethers.getContractAt(
      "IERC20",
      sellToken
    )) as unknown as IERC20

    // Approve weETH
    await weETH.connect(taker).approve(exchangeProxy, ethers.MaxUint256)
    const allowance = await weETH.allowance(takerAddress, exchangeProxy)
    console.log(allowance)

    const headers = { "0x-api-key": ZEROX_API_KEY }
    const quoteResponse = await fetch(
      `https://api.0x.org/swap/v1/price?buyToken=${buyToken}&sellAmount=${sellAmount}&sellToken=${sellToken}&takerAddress=${takerAddress}`,
      { headers }
    )
    // Check for error from 0x API
    if (quoteResponse.status !== 200) {
      const body = await quoteResponse.text()
      throw new Error(body)
    }

    const quote = await quoteResponse.json()

    console.log(quote)

    // Get pre-swap balances for comparison
    const weETHBalalanceBefore = await weETH.balanceOf(taker)
    const etherBalanceBefore = await provider.getBalance(taker)

    // Approve weETH
    // weETH.connect(taker).approve(quote.to, sellAmount)

    // Send the transaction
    const txResponse = await taker.sendTransaction({
      from: quote.from,
      to: quote.to,
      data: quote.data,
      value: 0,
      gasPrice: BigInt(quote.gasPrice),
      gasLimit: BigInt(quote.gas),
    })
    // Wait for transaction to confirm
    const txReceipt = await txResponse.wait()

    // Verify that the transaction was successful
    expect(txReceipt?.status).to.equal(1, "successful swap transaction")

    // Get post-swap balances
    const weETHBalanceAfter = await weETH.balanceOf(taker)
    const etherBalanceAfter = await provider.getBalance(taker)

    // ≈ 1 ETH was spent in the transaction
    expect(etherBalanceBefore - etherBalanceAfter).to.be.gte(sellAmount)

    // Our account has less weETH after the swap than before
    expect(weETHBalanceAfter).to.be.lt(weETHBalalanceBefore)

    console.log("--------BALANCES (before -> after)---------------------------")
    console.log(
      `ETH: ${etherBalanceBefore.toString()} -> ${etherBalanceAfter.toString()}`
    )
    console.log(
      `weETH: ${weETHBalalanceBefore.toString()} -> ${weETHBalanceAfter.toString()}`
    )
    console.log("-------------------------------------------------------------")
  })
})

describe("Lock", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployOneYearLockFixture() {
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60
    const ONE_GWEI = 1_000_000_000

    const lockedAmount = ONE_GWEI
    const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS

    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners()

    const Lock = await hre.ethers.getContractFactory("Lock")
    const lock = await Lock.deploy(unlockTime, { value: lockedAmount })

    return { lock, unlockTime, lockedAmount, owner, otherAccount }
  }

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { lock, unlockTime } = await loadFixture(deployOneYearLockFixture)

      expect(await lock.unlockTime()).to.equal(unlockTime)
    })

    it("Should set the right owner", async function () {
      const { lock, owner } = await loadFixture(deployOneYearLockFixture)

      expect(await lock.owner()).to.equal(owner.address)
    })

    it("Should receive and store the funds to lock", async function () {
      const { lock, lockedAmount } = await loadFixture(deployOneYearLockFixture)

      expect(await hre.ethers.provider.getBalance(lock.target)).to.equal(
        lockedAmount
      )
    })

    it("Should fail if the unlockTime is not in the future", async function () {
      // We don't use the fixture here because we want a different deployment
      const latestTime = await time.latest()
      const Lock = await hre.ethers.getContractFactory("Lock")
      await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
        "Unlock time should be in the future"
      )
    })
  })

  describe("Withdrawals", function () {
    describe("Validations", function () {
      it("Should revert with the right error if called too soon", async function () {
        const { lock } = await loadFixture(deployOneYearLockFixture)

        await expect(lock.withdraw()).to.be.revertedWith(
          "You can't withdraw yet"
        )
      })

      it("Should revert with the right error if called from another account", async function () {
        const { lock, unlockTime, otherAccount } = await loadFixture(
          deployOneYearLockFixture
        )

        // We can increase the time in Hardhat Network
        await time.increaseTo(unlockTime)

        // We use lock.connect() to send a transaction from another account
        await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
          "You aren't the owner"
        )
      })

      it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
        const { lock, unlockTime } = await loadFixture(deployOneYearLockFixture)

        // Transactions are sent using the first signer by default
        await time.increaseTo(unlockTime)

        await expect(lock.withdraw()).not.to.be.reverted
      })
    })

    describe("Events", function () {
      it("Should emit an event on withdrawals", async function () {
        const { lock, unlockTime, lockedAmount } = await loadFixture(
          deployOneYearLockFixture
        )

        await time.increaseTo(unlockTime)

        await expect(lock.withdraw())
          .to.emit(lock, "Withdrawal")
          .withArgs(lockedAmount, anyValue) // We accept any value as `when` arg
      })
    })

    describe("Transfers", function () {
      it("Should transfer the funds to the owner", async function () {
        const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
          deployOneYearLockFixture
        )

        await time.increaseTo(unlockTime)

        await expect(lock.withdraw()).to.changeEtherBalances(
          [owner, lock],
          [lockedAmount, -lockedAmount]
        )
      })
    })
  })
})
