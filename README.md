# LoopFi Prelaunch Point Contracts

![](./img/icon-loop.png)

## Description

Users can stake ETH into this contract, which will emit events tracked on a backed to calculate their corresponding amount of points. When staking, users can use a referral code encoded as `bytes32` that will give the referral extra points.

When Loop contracts are launched, the owner of the contract can call only once `setLoopAddresses` to set the `lpETH` contract as well as the staking vault for this token. This activation date is stored at `loopActivation`.

Once these addresses are set, all ETH deposits are paused and users have `7 days` to withdraw their ETH in case they changed their mind, or they detected a malicious contract being set. On withdrawal, users loose all their points.

After these `7 days` the owner can call `convertAll`, that converts all ETH in the contract for `lpETH`. This conversion has the timestamp `startClaimDate`.

After this conversion, users can start claiming their `lpETH` or claiming and staking them in a vault for extra rewards. The amount of `lpETH` they receive is proportional to their staked ETH amount.

Note: On deployment the variable `loopActivation` is set to be 120 days into the future. If owner does not set the Loop contracts before this date, the contract becomes unusable except for users to withdraw their ETH from this contract.

## Initialization

To compile the contracts run

```
forge build
```

To run the tests

```
forge test
```
