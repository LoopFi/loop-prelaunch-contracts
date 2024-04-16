# LoopFi Prelaunch Point Contracts

![](./img/icon-loop.png)

## Description

Users can lock ETH, WETH and wrapped LRTs into this contract, which will emit events tracked on a backed to calculate their corresponding amount of points. When staking, users can use a referral code encoded as `bytes32` that will give the referral extra points.

When Loop contracts are launched, the owner of the contract can call only once `setLoopAddresses` to set the `lpETH` contract as well as the staking vault for this token. This activation date is stored at `loopActivation`.

Once these addresses are set, all deposits are paused and users have `7 days` to withdraw their tokens in case they changed their mind, or they detected a malicious contract being set. On withdrawal, users loose all their points.

After these `7 days` the owner can call `convertAllETH`, that converts all ETH in the contract for `lpETH`. This conversion has the timestamp `startClaimDate`. The conversion for WETH and LRTs happens on each claim by using 0x API. This is triggered by each user.

After the global ETH conversion, users can start claiming their `lpETH` or claiming and staking them in a vault for extra rewards. The amount of `lpETH` they receive is proportional to their locked ETH amount or the amount given by the conversion by 0x API. The minimum amount to receive is determined offchain and controlled by a slippage parameter in the frontend dApp.

### Notes:

- On deployment the variable `loopActivation` is set to be 120 days into the future. If owner does not set the Loop contracts before this date, the contract becomes unusable except for users to withdraw their ETH and other locked tokens from this contract.
- There is an emergency mode that allows users to withdraw without any time restriction. If ETH was converted already users can call `claim` instead. This mode ensures that LRTs are not locked in the contract in case 0x stops working as intended.

## Initialization

To compile the contracts run

```
forge build
```

To run the unit tests

```
forge test
```

To run the integration tests with 0x API, first create and fill a `.env` file with the keys of `.env.example`. Then, run

```
yarn hardhat test
```

## Deployment

First, set your environment variables in a `.env` file as in `.env.example`. To load these variables run

```
source .env
```

To deploy and verify the `PrelaunchPoints` contract run

```
forge script script/PrelaunchPoints.s.sol --rpc-url $RPC_URL --broadcast --verify
```

## Audit metrics

To get some metrics pre audit, run

```
yarn solidity-code-metrics src/PrelaunchPoints.sol > metrics.md
```
