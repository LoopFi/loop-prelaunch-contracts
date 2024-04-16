import { expect } from "chai"
import hre, { ethers } from "hardhat"
import {
  time,
  impersonateAccount,
  setBalance,
} from "@nomicfoundation/hardhat-toolbox/network-helpers"
import fetch from "node-fetch"
import "dotenv/config"
import {
  IERC20,
  MockLpETH,
  MockLpETHVault,
  PrelaunchPoints,
} from "../typechain"
import { parseEther } from "ethers"

const ZEROX_API_KEY = process.env.ZEROX_API_KEY || ""

const tokens = [
  {
    name: "WETH",
    address: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    whale: "0x2fEb1512183545f48f6b9C5b4EbfCaF49CfCa6F3",
  },
  {
    name: "weETH",
    address: "0xcd5fe23c85820f7b72d0926fc9b05b43e359b7ee",
    whale: "0x1C3DC4F4eE50D483289beF519C598847cd447A19",
  },
  {
    name: "ezETH",
    address: "0xbf5495Efe5DB9ce00f80364C8B423567e58d2110",
    whale: "0x267ed5f71EE47D3E45Bb1569Aa37889a2d10f91e",
  },
  {
    name: "pufETH",
    address: "0xD9A442856C234a39a81a089C06451EBAa4306a72",
    whale: "0x176F3DAb24a159341c0509bB36B833E7fdd0a132",
  },
  {
    name: "rsETH",
    address: "0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7",
    whale: "0x22162DbBa43fE0477cdC5234E248264eC7C6EA7c",
  },
  {
    name: "rswETH",
    address: "0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0",
    whale: "0x22162DbBa43fE0477cdC5234E248264eC7C6EA7c",
  },
  {
    name: "uniETH",
    address: "0xF1376bceF0f78459C0Ed0ba5ddce976F1ddF51F4",
    whale: "0x934f719cd3fADeF7bB30E297F6687Ad978A076B7",
  },
]

describe("0x API integration", function () {
  const ETH = "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
  const exchangeProxy = "0xdef1c0ded9bec7f1a1670819833240f027b25eff"

  const sellAmount = ethers.parseEther("1")
  const referral = ethers.encodeBytes32String("")

  // Contracts
  let lockToken: IERC20
  let prelaunchPoints: PrelaunchPoints
  let lpETH: MockLpETH
  let lpETHVault: MockLpETHVault

  before(async () => {
    const LpETH = await hre.ethers.getContractFactory("MockLpETH")
    lpETH = (await LpETH.deploy()) as unknown as MockLpETH

    const LpETHVault = await hre.ethers.getContractFactory("MockLpETHVault")
    lpETHVault = (await LpETHVault.deploy()) as unknown as MockLpETHVault
  })

  beforeEach(async () => {
    const PrelaunchPoints = await hre.ethers.getContractFactory(
      "PrelaunchPoints"
    )
    prelaunchPoints = (await PrelaunchPoints.deploy(
      exchangeProxy,
      tokens[0].address,
      tokens.slice(1).map((token) => token.address)
    )) as unknown as PrelaunchPoints
  })

  tokens.forEach((token) => {
    it(`it should be able to claim after ${token.name} deposit`, async function () {
      lockToken = (await ethers.getContractAt(
        "IERC20",
        token.address
      )) as unknown as IERC20

      // Impersonate whale
      const depositorAddress = token.whale
      await impersonateAccount(depositorAddress)
      const depositor = await ethers.getSigner(depositorAddress)
      await setBalance(depositorAddress, parseEther("100"))

      // Get pre-lock balances
      const tokenBalanceBefore = await lockToken.balanceOf(depositor)

      // Lock token in Prelaunch
      await lockToken.connect(depositor).approve(prelaunchPoints, sellAmount)
      await prelaunchPoints
        .connect(depositor)
        .lock(token.address, sellAmount, referral)

      // Get post-lock balances
      const tokenBalanceAfter = await lockToken.balanceOf(depositor)
      const claimToken = token.name == "WETH" ? ETH : token.address
      const lockedBalance = await prelaunchPoints.balances(
        depositor.address,
        claimToken
      )
      expect(tokenBalanceAfter).to.be.eq(tokenBalanceBefore - sellAmount)
      expect(lockedBalance).to.be.eq(sellAmount)

      // Activate claiming
      await prelaunchPoints.setLoopAddresses(lpETH, lpETHVault)
      const newTime =
        (await prelaunchPoints.loopActivation()) +
        (await prelaunchPoints.TIMELOCK()) +
        1n
      await time.increaseTo(newTime)
      await prelaunchPoints.convertAllETH()

      // Get Quote from 0x API
      const headers = { "0x-api-key": ZEROX_API_KEY }
      const quoteResponse = await fetch(
        `https://api.0x.org/swap/v1/quote?buyToken=${ETH}&sellAmount=${sellAmount}&sellToken=${token.address}`,
        { headers }
      )

      // Check for error from 0x API
      if (quoteResponse.status !== 200) {
        const body = await quoteResponse.text()
        throw new Error(body)
      }
      const quote = await quoteResponse.json()

      // console.log(quote)

      const exchange = quote.orders[0] ? quote.orders[0].source : ""
      const exchangeCode = exchange == "Uniswap_V3" ? 0 : 1

      // Claim
      await prelaunchPoints
        .connect(depositor)
        .claim(claimToken, 100, exchangeCode, quote.data)

      expect(await prelaunchPoints.balances(depositor, token.address)).to.be.eq(
        0
      )

      const balanceLpETHAfter = await lpETH.balanceOf(depositor)
      expect(balanceLpETHAfter).to.be.gt((sellAmount * 95n) / 100n)
    })
    it(`it should be able to claimAndStake ${token.name} deposit`, async function () {
      lockToken = (await ethers.getContractAt(
        "IERC20",
        token.address
      )) as unknown as IERC20

      // Impersonate whale
      const depositorAddress = token.whale
      await impersonateAccount(depositorAddress)
      const depositor = await ethers.getSigner(depositorAddress)
      await setBalance(depositorAddress, parseEther("100"))

      // Get pre-lock balances
      const tokenBalanceBefore = await lockToken.balanceOf(depositor)

      // Lock token in Prelaunch
      await lockToken.connect(depositor).approve(prelaunchPoints, sellAmount)
      await prelaunchPoints
        .connect(depositor)
        .lock(token.address, sellAmount, referral)

      // Get post-lock balances
      const tokenBalanceAfter = await lockToken.balanceOf(depositor)
      const claimToken = token.name == "WETH" ? ETH : token.address
      const lockedBalance = await prelaunchPoints.balances(
        depositor.address,
        claimToken
      )
      expect(tokenBalanceAfter).to.be.eq(tokenBalanceBefore - sellAmount)
      expect(lockedBalance).to.be.eq(sellAmount)

      // Activate claiming
      await prelaunchPoints.setLoopAddresses(lpETH, lpETHVault)
      const newTime =
        (await prelaunchPoints.loopActivation()) +
        (await prelaunchPoints.TIMELOCK()) +
        1n
      await time.increaseTo(newTime)
      await prelaunchPoints.convertAllETH()

      // Get Quote from 0x API
      const headers = { "0x-api-key": ZEROX_API_KEY }
      const quoteResponse = await fetch(
        `https://api.0x.org/swap/v1/quote?buyToken=${ETH}&sellAmount=${sellAmount}&sellToken=${token.address}`,
        { headers }
      )

      // Check for error from 0x API
      if (quoteResponse.status !== 200) {
        const body = await quoteResponse.text()
        throw new Error(body)
      }
      const quote = await quoteResponse.json()

      // console.log(quote)

      const exchange = quote.orders[0] ? quote.orders[0].source : ""
      const exchangeCode = exchange == "Uniswap_V3" ? 0 : 1

      // Claim
      await prelaunchPoints
        .connect(depositor)
        .claimAndStake(claimToken, 100, exchangeCode, quote.data)

      expect(await prelaunchPoints.balances(depositor, token.address)).to.be.eq(
        0
      )

      const balanceLpETHAfter = await lpETHVault.balanceOf(depositor)
      expect(balanceLpETHAfter).to.be.gt((sellAmount * 95n) / 100n)
    })
  })
})
