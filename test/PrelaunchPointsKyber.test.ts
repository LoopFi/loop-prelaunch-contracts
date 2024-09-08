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

const CLIENT_ID = process.env.CLIENT_ID || ""

const tokens = [
  {
    name: "ynETH",
    address: "0x09db87A538BD693E9d08544577d5cCfAA6373A48",
    whale: "0xB9779AeC32f4cbF376F325d8c393B0D2711874eD",
  },
]

describe("Kyberswap API integration", function () {
  const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
  const exchangeProxy = "0x6131B5fae19EA4f9D964eAc0408E4408b66337b5"

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
      WETH,
      tokens.map((token) => token.address),
      [parseEther("100")].concat(tokens.map((token) => parseEther("100")))
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
      const claimToken = token.address
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

      // Get Quote from Kyber API
      const headers = { "x-client-id": CLIENT_ID }
      const routesResponse = await fetch(
        `https://aggregator-api.kyberswap.com/ethereum/api/v1/routes?tokenIn=${token.address}&tokenOut=${WETH}&amountIn=${sellAmount}&source=${CLIENT_ID}`,
        { headers }
      )
      const route = await routesResponse.json()
      console.log(route)

      const quoteResponse = await fetch(
        "https://aggregator-api.kyberswap.com/ethereum/api/v1/route/build",
        {
          method: "POST",
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            routeSummary: route.data.routeSummary,
            sender: await prelaunchPoints.getAddress(),
            recipient: await prelaunchPoints.getAddress(),
            slippageTolerance: 1000, // 10%
            deadline: Date.now() + 200000,
            source: CLIENT_ID,
          }),
        }
      )

      // Check for error from Kyber API
      if (quoteResponse.status !== 200) {
        const body = await quoteResponse.text()
        throw new Error(body)
      }
      const quote = await quoteResponse.json()

      // console.log(quote)
      const exchangeSelector = quote.data.data.slice(0, 10)
      const exchangeCode = exchangeSelector == "0xe21fd0e9" ? 0 : 1

      // Claim
      await prelaunchPoints
        .connect(depositor)
        .claim(claimToken, 100, exchangeCode, quote.data.data)

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
      const claimToken = token.address
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

      // Get Quote from Kyber API
      const headers = { "x-client-id": CLIENT_ID }
      const routesResponse = await fetch(
        `https://aggregator-api.kyberswap.com/ethereum/api/v1/routes?tokenIn=${token.address}&tokenOut=${WETH}&amountIn=${sellAmount}&source=${CLIENT_ID}`,
        { headers }
      )
      const route = await routesResponse.json()
      // console.log(route)

      const quoteResponse = await fetch(
        "https://aggregator-api.kyberswap.com/ethereum/api/v1/route/build",
        {
          method: "POST",
          headers: {
            ...headers,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            routeSummary: route.data.routeSummary,
            sender: await prelaunchPoints.getAddress(),
            recipient: await prelaunchPoints.getAddress(),
            slippageTolerance: 1000, // 10%
            deadline: Date.now() + 200000,
            source: CLIENT_ID,
          }),
        }
      )

      // Check for error from Kyber API
      if (quoteResponse.status !== 200) {
        const body = await quoteResponse.text()
        throw new Error(body)
      }
      const quote = await quoteResponse.json()

      // console.log(quote)

      const exchangeSelector = quote.data.data.slice(0, 10)
      const exchangeCode = exchangeSelector == "0xe21fd0e9" ? 0 : 1

      // Claim
      await prelaunchPoints
        .connect(depositor)
        .claimAndStake(claimToken, 100, exchangeCode, 0, quote.data.data)

      expect(await prelaunchPoints.balances(depositor, token.address)).to.be.eq(
        0
      )

      const balanceLpETHAfter = await lpETHVault.balanceOf(depositor)
      expect(balanceLpETHAfter).to.be.gt((sellAmount * 95n) / 100n)
    })
  })
})
