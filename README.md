# LoopFi Prelaunch Point Contracts

![](./img/icon-loop.png)

## Description

### Epoch 1:

Users can lock WBTC and wrapped Bitcoin LRTs into this contract, which will emit events tracked on a backed to calculate their corresponding amount of points. When staking, users can use a referral code encoded as `bytes32` that will give the referral extra points. User can withdraw freely during this first epoch, but they will be penalized in the points accounting.

When Loop contracts are launched, the owner of the contract can call only once `setLoopAddresses` to set the `lpBTC` contract as well as the staking vault for this token. This activation date is stored at `loopActivation`.

Once these addresses are set, users have `7 days` to detected a malicious contract being set and withdraw their tokens.

### Epoch 2:

After these `7 days` the owner can call `convertAllBTC`, that converts all BTC in the contract for `lpBTC`. This conversion has the timestamp `startClaimDate`. The conversion for WBTC and LRTs happens on each claim by using Kyberswap API. This is triggered by each user. After `startClaimDate` all deposits and withdrawals are disabled and users can only claim lpBTC.

After the global WBTC conversion, users can start claiming their `lpBTC` or claiming and staking them in a vault for extra rewards. The amount of `lpBTC` they receive is proportional to their locked WBTC amount or the amount given by the conversion by Kyberswap API. The minimum amount to receive is determined offchain and controlled by a slippage parameter in the frontend dApp.

### Notes:

- On deployment the variable `loopActivation` is set to be 120 days into the future. If owner does not set the Loop contracts before this date, the contract becomes unusable by the owner and users can withdraw their BTC and other locked tokens from this contract.
- There is an emergency mode that allows users to withdraw without any time restriction. If WBTC was converted already users can call `claim` instead. This mode ensures that LRTs are not locked in the contract in case Kyberswap stops working as intended.

## Initialization

To compile the contracts run

```
forge build
```

To run the unit tests

```
forge test
```

To run the integration tests with Kyberswap API, first create and fill a `.env` file with the keys of `.env.example`. Then, run

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

If verification fails you can manually submit by using

```
forge verify-contract --chain mainnet --constructor-args-path constructor-args.txt --etherscan-api-key $ETHERSCAN_API_KEY <contract_address> PrelaunchPoints
```

## Audit metrics

To get some metrics pre audit, run

```
yarn solidity-code-metrics src/PrelaunchPoints.sol > metrics.md
```

## References

- LoopFi Documentation: https://docs.loopfi.xyz
