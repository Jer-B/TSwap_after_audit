T Swap invariant

The ratios of tokens should always stay the same.
`x * y = k`
-> But K could increase, because of the fees.

- x = Token Balance X
- y = Token Balance Y
- k = The constant ratio between X & Y

(The product should always be the same, X \* Y should always be equal to the same K)

Weird ERC exploit

If a pool has no liquidity at all when making a deposit, there is a logic that the first deposit will be considered as "adding liquidity". The pool ratio will then be determined by the first deposit. This is a weird behavior, and it is not clear if this is a bug or a feature.

````solidity
deposit function; line 134

```solidity
else {
            // This will be the "initial" funding of the protocol. We are starting from blank here!
            // We just have them send the tokens in, and we mint liquidity tokens based on the weth
            _addLiquidityMintAndTransfer(wethToDeposit, maximumPoolTokensToDeposit, wethToDeposit);
            liquidityTokensToMint = wethToDeposit;
        }
````

minimum weth valid for deposit ; line 36
uint256 private constant MINIMUM_WETH_LIQUIDITY = 1_000_000_000; // 0,000000001 ether

skill sheet update ?
kibiki ni tsuite,
