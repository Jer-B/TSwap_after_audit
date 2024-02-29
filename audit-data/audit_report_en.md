---
title: T-Swap Audit Report
author: Jeremy Bru
date: Feb 29, 2024
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
\centering
\begin{figure}[h]
\centering
\includegraphics[width=0.5\textwidth]{./audit-data/logo.png}
\end{figure}
\vspace{2cm}
{\Huge\bfseries T-Swap Audit Report\par}
\vspace{1cm}
{\Large Version 1.0\par}
\vspace{2cm}
{\Large\itshape Jeremy Bru\par}
\vfill
{\large \today\par}
\end{titlepage}

\maketitle

<!-- @format -->

# Minimal Audit Report - T-Swap

Prepared by: [Jeremy Bru (Link)](https://jer-b.github.io/portofolio.html) <br />
Lead Security Researcher: <br />

- Jeremy Bru

Contact: --

# Table of Contents

- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
  - [Scope](#scope)
  - [Roles](#roles)
- [Executive Summary](#executive-summary)
  - [Issues found](#issues-found)
- [Findings](#findings)
  - [High](#high)
  - [Medium](#medium)
  - [Low](#low)
  - [Informational](#informational)
  - [Gas](#gas)

# Protocol Summary

From my understanding,
This project is meant to be a permissionless way for users to swap assets between each other at a fair price. The protocol is an AMM (Automated Market Maker) that should do the following:

- Respect the constant formula `x * y = k` for each pools.

  - The ratios of tokens should always stay the same.

- In order for the protocol to work, it needs to have liquidity providers.

  - Their shares are represented by an `LP` ERC20 tokens. ie `T-SwapWeth` .
  - They gain a 0.3% fee every time a swap is made.
  - The generated gain to the liquidity providers will be based in the form of a liquidity pool token (`LP`s) number increasing.

- Liquidity can be deposited, added and withdrawn by those 2 functions:
  - `TSwapPool::deposit`
  - `TSwapPool::withdraw`
  - Note: If there is a deposit of liquidity from a user already in place, the deposit function will be considered as `adding liquidity`.

`PoolFactory` contract is the contract used to create new "pools" of tokens via the `PoolFactory::createPool` function. It helps make sure every pool token uses the correct logic.

- Pools are made of 2 assets a Token A (x) and the WETH token (y).
- Allows swapping of assets between each other at a fair price.

There are 2 functions users can call to swap tokens in the pool, from the `TSwapPool` contract:

- `TSwapPool::swapExactInput`
- `TSwapPool::swapExactOutput`
- Users are able to swap tokens based on the amount of tokens they want to receive or the amount of tokens they want to give in exchange of the desired asset.

The chain to which it is gonna be deployed is `Ethereum` and `any ERC20` token can be used with WETH as a paired token to create pools.

# Disclaimer

I, Jeremy Bru, did makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

Uses the [CodeHawks (Link)](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details

Commit Hash: `e643a8d4c2c802490976b538dd009b351b1c8dda`

## Scope

```
./src/
#-- PoolFactory.sol
#-- TSwapPool.sol
```

## Roles

- Swapper - Users that swapping between 2 assets in a pool.
- Liquidity Providers - Users that initialize and provide liquidity in pools for users to be able to swap their assets. Gaining fees on each swap based on their shares.

# Executive Summary

Used `Forge Foundry`, `Aderyn`, `Slither`, Stateful Fuzzing with Handler and manual review to find the following issues and wrote test cases to show the issues.

# Issues found

| Severyity | Number of findings |
| --------- | ------------------ |
|           |                    |
| High      | 6                  |
| Medium    | 2                  |
| Low       | 3                  |
| Infos     | 10                 |
| --------- | ------------------ |
| Total     | 21                 |

\pagebreak

# Findings

## High

### [S-H1] Core Invariant `x * y = k` is broken by the `_swap` function incentives, pool ratio is broken.

**Description:**<br />

The protocol is giving extra incentive to users who are swapping, `swappers`, in WETH tokens every 10 transactions. This, to keep users exchanging their assets on the protocol.

The incentive is about `1WETH` every `10 transactions`.

So, the invariant `x * y = k`, that should conserves a constant ratio between the two assets, breaks due to the above incentive.

The pool ratio is completly broken, as users are getting more from the pool as they should.

**Impact:**<br />

- The pool can be drained to 0 by `swappers` without big effort.
- And this every 10th transaction per users.

**Proof of Concept:**<br />

- In the test folder there is a test case using a Stateful Fuzzing with Handler method to show the issue.
- Also adding a third test not based on the fuzzing method, by just doing 10 swaps.

The first test:

- `test/Invariant.t.sol::statefulFuzz_constantProductFormulaStaysTheSameTokenA`
- It checks for equality of what was deposited and the difference in change of the amount in the pool based on the first paired token.
- Equality matches.

run the test with:

```
forge test --mt statefulFuzz_constantProductFormulaStaysTheSameTokenA -vvvv
```

\pagebreak

The second test, aims for the same verification but on the Weth token.

- `test/Invariant.t.sol::statefulFuzz_constantProductFormulaStaysTheSameWeth`
- Equality does not match due to the incentive.
  run the test with:

```
forge test --mt statefulFuzz_constantProductFormulaStaysTheSameWeth -vvvv
```

The incentive `TSwapPool::_swap`:
Dev Comments: `* @dev Every 10 swaps, we give the caller an extra token as an extra incentive to keep trading on T-Swap.
`

```javascript
swap_count++;
if (swap_count >= SWAP_COUNT_MAX) {
  swap_count = 0;
  outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
}
```

Third test `TSwapPool.t.sol`:

<details>
<summary>Proof of Code</summary>

```javascript

    function testDepositSwapAudit() public {
        uint256 swapOutput = 1e17;

        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 1000e18);
        for (uint256 i = 0; i < 8; i++) {
            console.log("Swap number: ", i);
            pool.swapExactOutput(poolToken, weth, swapOutput, uint64(block.timestamp));
        }

        int256 startingWethBalance = int256(weth.balanceOf(address(pool)));
        int256 expectedWethBalanceChange = int256(-1) * int256(swapOutput);

        console.log("Swap number: 9");
        pool.swapExactOutput(poolToken, weth, swapOutput, uint64(block.timestamp));

        // comment swap number 10 and the test will pass
        // the purpose of this test is to show the invariant breaking due to the incentives coming in on the 10th swap
        console.log("Swap number: 10"); // when incentive comes in
        pool.swapExactOutput(poolToken, weth, swapOutput, uint64(block.timestamp));

        vm.stopPrank();

        uint256 endingWethBalance = weth.balanceOf(address(pool));
        int256 actualWethBalanceChange = int256(endingWethBalance) - int256(startingWethBalance);

        assertEq(actualWethBalanceChange, expectedWethBalanceChange);
    }
```

</details>

**Recommended Mitigation:**<br />

- Change the incentive logic, or remove it. It is breaking the pool ratio and the core invariant of the protocol.
- Users could be rewarded in TSwap tokens, a token made for the protocol, earned and mint initially only by swappers. Then a TSwap / Weth pool could be created to allow users to swap their TSwap tokens for Weth tokens.
- Lower the incentive amount to avoid any mathematical issue with the minimum required for a swap or / and for the minimum required to be a liquidity provider.

#

\pagebreak

### [S-H2] Grief attack on swap incentives, users == `swappers` can drained pools and the protocol won't survive the loss.

**Description:**<br />

- The minimum required for `liquidity providers` to deposit liquidity of WETH is `1_000_000_000` wei.
- Every 10 swaps, `swappers` are rewarded with `1_000_000_000_000_000_000` wei of WETH.
- `Liquidity providers` needs to put in at least 0,000000001 weth <--> `swappers` get 1WETH

Just by swapping at least 10 times, `swappers` can drain the pool to 0.

**Impact:**<br />

- Swappers can drain any pools to 0.

**Proof of Concept:**<br />

Incentives code from `TSwapPool::_swap`:

```javascript
swap_count++;
if (swap_count >= SWAP_COUNT_MAX) {
  swap_count = 0;
  outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
}
```

Minimum deposit checker from `TSwapPool::deposit`:

```javascript
if (wethToDeposit < MINIMUM_WETH_LIQUIDITY) {
    revert TSwapPool__WethDepositAmountTooLow(
        MINIMUM_WETH_LIQUIDITY,
        wethToDeposit
    );
}
```

The constant variable `MINIMUM_WETH_LIQUIDITY` from `TSwapPool.sol`:

```javascript
uint256 private constant MINIMUM_WETH_LIQUIDITY = 1_000_000_000;
```

\pagebreak

**Recommended Mitigation:**<br />

- Same as the first issue of this repport, see below:

- Change the incentive logic, or remove it. It is breaking the pool ratio and the core invariant of the protocol.
- Users could be rewarded in TSwap tokens, a token made for the protocol, earned and mint initially only by swappers. Then a TSwap / Weth pool could be created to allow users to swap their TSwap tokens for Weth tokens.
- Lower the incentive amount to avoid any mathematical issue with the minimum required for a swap or / and for the minimum required to be a liquidity provider.

#

### [S-H3] Unused parameter `deadline` in the `TSwapPool::deposit` function, disrupting logic that transaction should not go through if deadline is passed.

**Description:**<br />

If someone sets the deadline to a block to come, they can deposit at the current block and can still deposit until the deadline of the block they set. Whatever a user expects something, in the actual code, it is always the case.

- Modifier `revertIfDeadlinePassed` is also not used in the `TSwapPool::deposit` function.

- `uint64 deadline` parameter is not used in the `TSwapPool::deposit` function.

**Impact:**<br />

- If a user expects a deposit to fails due to the deadline, it won't. The transaction will go through. Whatever a user expects something, in the actual code, it is always the case.

- Users should be able to withdraw when they want. There is no vesting or minimum time to wait for a withdrawal that explains that.

\pagebreak

**Proof of Concept:**<br />

- The below is a simple test where `user` calls the `TSwapPool::deposit` function to deposit liquidity in a pool, using an already passed `deadline` at a time of where `deadline` is already `1000` seconds in the future.

- Deposit is successfull. But fails if the modifier checking for the deadline is set in the function signature like described in below `recommended mitigation`.

<details>
<summary>Proof Of Code</summary>

```javascript
    function testBlockTimestamp() public {
        uint256 minimumDeposit = 1e18;
        uint256 currentBalanceOfWethInPool = weth.balanceOf(address(pool));

        vm.getBlockTimestamp();
        uint64 currentBlock = uint64(block.timestamp);
        console.log("Current block timestamp: ", currentBlock);

        // increase timestamp
        vm.warp(1000);
        vm.assume(currentBlock != block.timestamp);
        require(currentBlock != block.timestamp);

        // as pool and liquidity already exist (see initial setup config)
        // prank with user for just depositing on the initial block.timestamp value when deposing at a time where the
        // blockchain is already at a different block forward.
        vm.startPrank(user);
        weth.approve(address(pool), minimumDeposit);
        poolToken.approve(address(pool), minimumDeposit);
        pool.deposit(minimumDeposit, 0, minimumDeposit, currentBlock);
        vm.stopPrank();

        //check deposit by checking that the liquidity pool has increased by the amount deposited by the user
        assertEq(weth.balanceOf(address(pool)), currentBalanceOfWethInPool + minimumDeposit); // ok
    }
```

</details>

\pagebreak

**Recommended Mitigation:**<br />

- Change the logic about the deadline, or remove it, or adapt functions and parameters correctly for its use.

- Review restrictions based on the `deadline` logic.
- Can consider following change for the `TSwapPool::deposit` function, using the deadline modifier:

```diff
    function deposit(
        uint256 wethToDeposit,
        uint256 minimumLiquidityTokensToMint,
        uint256 maximumPoolTokensToDeposit,
        uint64 deadline
    )
        external
+       revertIfDeadlinePassed(deadline)
        revertIfZero(wethToDeposit)
        returns (uint256 liquidityTokensToMint)
```

#

### [S-H4] Fees math in `TSwapPool::getInputAmountBasedOnOutput` is wrong, it is set to 10.13% instead of 0.03% as it should be.

**Description:**<br />

`10000` is used instead of `1000` in the calculation of the return value.

- Might be due to the fact of dealing with magic numbers instead of constant variable names.

**Impact:**<br />

- Calculate 10.13% instead of 0.03%
- Users are charged 10.13% instead of 0.03% of the swap amount each time.
- Users not getting the expected amount of tokens in return, because they are charged too much when paying the swap.
- The extra paid by users will be withdrawn by liquidity providers.

\pagebreak

**Proof of Concept:**<br />

- In the test case below, available that can be added to the protocol test suite `TSwapPool.t.sol`, here what is happening:

1. `Liquidity provider` provide liquidity for a pool at a ratio 1:1.
2. `user` == `swapper` wishing to swap 1 Token for 1 Weth, calls the `TSwapPool::swapExactOutput` function.
3. Checking balance before / after of the `swapper` and `pool`.
4. `swapper` balance paid 10.13 tokens instead of 1 for getting 1 weth.
5. `liquidity provider` withdraw all liquidity from the pool + the extra from miscalculation.

<details>
<summary>Proof of Code</summary>

```javascript
    // test based on getInputAmountBasedOnOutput function and fee miscalculation
    function testCalculationFee() public {
        uint256 liquidityFromProvider = 100e18;

        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), liquidityFromProvider);
        poolToken.approve(address(pool), liquidityFromProvider);

        // deposit liquidity into a pool
        //    function deposit(uint256 wethToDeposit, uint256 minimumLiquidityTokensToMint, uint256
        // maximumPoolTokensToDeposit, uint64 deadline)
        pool.deposit(liquidityFromProvider, 0, liquidityFromProvider, uint64(block.timestamp));

        vm.stopPrank(); // end prank liquidity provider

        // liquidity deposited checkers
        assertEq(pool.balanceOf(liquidityProvider), liquidityFromProvider);
        console.log("Pool balance of Token A from liquidity provider: ", poolToken.balanceOf(address(pool)));
        console.log("Pool balance of Weth from liquidity provider: ", weth.balanceOf(address(pool)));

        // start prank user
        vm.startPrank(user); // mint 100e18 in setup == 100 Token A - LP / 100 Weth
        uint256 userStartingWethBalance = weth.balanceOf(user);
        uint256 userStartingTokenABalance = poolToken.balanceOf(user);
        console.log("User starting Weth balance: ", userStartingWethBalance);
        console.log("User starting Token A balance: ", userStartingTokenABalance);

        // approve token A to be used for swap
        poolToken.approve(address(pool), type(uint256).max);

        // get 1 Weth in exchange
        pool.swapExactOutput(poolToken, weth, 1e18, uint64(block.timestamp));

        uint256 userEndingWethBalanceAfterSwap = weth.balanceOf(user);
        uint256 userEndingTokenABalanceAfterSwap = poolToken.balanceOf(user);

        vm.stopPrank(); // end prank user

        // Weth balance of Weth should have increase by one
        assertEq(userEndingWethBalanceAfterSwap, userStartingWethBalance + 1e18);
        console.log("User balance of Weth after swap: ", userEndingWethBalanceAfterSwap);

        // As pool initial ratio is 1:1, when buying 1 Weth, 1 Token A should be removed from the pool
        // so user balance of Token A should decrease by 1
        assertEq(userEndingTokenABalanceAfterSwap, userStartingTokenABalance - 1e18);
        console.log("User balance of Token A after swap: ", userEndingTokenABalanceAfterSwap);
        // for 1 weth
        // Token A before                100,000000000000000000
        // Token A Expected after swap    99,000000000000000000
        // Actual Token A balance after   89,868595686048043120
        //WHAAAAAT nearly - 10.14 tokens instead of -1 ??

        //so the pool is ...
        console.log("Pool balance after user swap: ", poolToken.balanceOf(address(pool)));
        // Pool Token A after swap       110,131404313951956880
        // + 10.13....
        console.log("Pool Weth after swap ", weth.balanceOf(address(pool)));
        // Pool Weth after swap           99,000000000000000000

        // Give place to the liquidity provider to rug the pool including the extra of Token A
        vm.startPrank(liquidityProvider);
        pool.withdraw(
            pool.balanceOf(liquidityProvider),
            1, // minWethToWithdraw
            1, // minPoolTokensToWithdraw
            uint64(block.timestamp)
        );

        console.log(
            "Pool balance of Token A after liquidity provider withdraw all: ", poolToken.balanceOf(address(pool))
        );
        console.log("Pool balance of Weth after liquidity provider withdraw all: ", weth.balanceOf(address(pool)));

        // new balance of liquidity provider
        console.log("Liquidity provider balance of Weth after withdraw all: ", weth.balanceOf(liquidityProvider));
        console.log(
            "Liquidity provider balance of Token A after withdraw all: ", poolToken.balanceOf(liquidityProvider)
        );
        // loosing 1 weth but gained 10 token A instead of 1

        assertEq(weth.balanceOf(address(pool)), 0);
        assertEq(poolToken.balanceOf(address(pool)), 0);
    }

```

</details>

**Recommended Mitigation:**<br />

- Change `10000` for `1000` in the calculation of the return value.

```diff
    {
-        return ((inputReserves * outputAmount) * 10000) / ((outputReserves - outputAmount) * 997);
+        return ((inputReserves * outputAmount) * 1_000) / ((outputReserves - outputAmount) * 997);
    }
```

#

### [S-H5] No slippage protection in `TSwapPool::swapExactOutput`, in the case of a price spike or huge movement of money in the liquidity pool users are not protected.

**Description:**<br />

Price spike or massive transaction to the pool can occur any time and affects users on slippage as there is no slippage protection in `TSwapPool::swapExactOutput`, like it is existing in `TSwapPool::swapExactInput`.

Can lead to pay for a fraction of what the users should get in returns in an instant.

\pagebreak

**Impact:**<br />

- Price spike or massive transaction to the pool can occur any time and affects users on slippage.

- Also an MEV (Miner Extractable Value) attack can occur.

**Recommended Mitigation:**<br />

- Needs an extra parameter in the function declaration checking for a maximum output and a new error statement for it.

```diff
+ error TSwapPool__OutputTooBig(uint256 actual, uint256 max);

    function swapExactOutput(
        IERC20 inputToken,
        IERC20 outputToken,
+       uint256 maxOutputAmount,
        uint256 outputAmount,
        uint64 deadline
    )
        public
        revertIfZero(outputAmount)
        revertIfDeadlinePassed(deadline)
        returns (uint256 inputAmount)
    {
        uint256 inputReserves = inputToken.balanceOf(address(this));
        uint256 outputReserves = outputToken.balanceOf(address(this));

        inputAmount = getInputAmountBasedOnOutput(outputAmount, inputReserves, outputReserves);

+       if (outputAmount > maxOutputAmount) {
+           revert TSwapPool__OutputTooBig(outputAmount, maxOutputAmount);
+       }

        _swap(inputToken, inputAmount, outputToken, outputAmount);
    }
```

#

\pagebreak

### [S-H6] In `TSwapPool::sellPoolTokens` function, users receives incorrect amount of tokens.

**Description:**<br />

- Business logic, wrong function used in the return statement and wrong parameters.
- The function `swapExactOutput` is used instead of `swapExactInput` in the return statement.
- Wrong maths and lacks of slippage protection as stated in another issues of this report, leading to users suffering big losses when swapping tokens for `Weth`.
- The ratio 1:1 is not respected.

**Impact:**<br />

- Due to the wrong logic as described above users are not getting the expected amount of tokens in return, because they are charged too much when paying the swap, suffering an enormous loss.

**Proof of Concept:**<br />

- The below is a simple test where `user` calls the `TSwapPool::sellPoolTokens` function to sell pool tokens for Weth.

- Amount of tokens to sell is `3`.

- `32` tokens disappeared in the process, instead of `3` tokens.

```javascript
    function testSellPoolTokens() public {
        //result
        //   amount sold: 3 ether                       3000000000000000000
        //   User balance of pool token before sell:  100000000000000000000
        //   User balance of weth before sell:        100000000000000000000
        //   User balance of pool token after sell:    68979102255219266046  // 32 tokens disappeared instead of 3
        //   User balance of weth after sell:         103000000000000000000
        //   Error: a == b not satisfied [uint]
        //         Left: 68979102255219266046
        //        Right: 97000000000000000000
        uint256 liquidityFromProvider = 100e18;
        uint256 amountOfTokenToSell = 3 ether;

        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), liquidityFromProvider);
        poolToken.approve(address(pool), liquidityFromProvider);

        pool.deposit(liquidityFromProvider, 0, liquidityFromProvider, uint64(block.timestamp));

        vm.stopPrank();

        // Use another user trying to sell pool tokens for weth
        vm.startPrank(user);
        uint256 poolTokenBalanceBeforeSell = poolToken.balanceOf(user);
        uint256 wethBalanceBeforeSell = weth.balanceOf(user);
        console.log("User balance of pool token before sell: ", poolTokenBalanceBeforeSell);
        console.log("User balance of weth before sell: ", wethBalanceBeforeSell);

        poolToken.approve(address(pool), liquidityFromProvider);
        pool.sellPoolTokens(amountOfTokenToSell);

        uint256 poolTokenBalanceAfterSell = poolToken.balanceOf(user);
        uint256 wethBalanceAfterSell = weth.balanceOf(user);
        console.log("User balance of pool token after sell: ", poolTokenBalanceAfterSell);
        console.log("User balance of weth after sell: ", wethBalanceAfterSell);

        vm.stopPrank();

        assertLt(poolTokenBalanceAfterSell, poolTokenBalanceBeforeSell); // ok
        assertGt(wethBalanceAfterSell, wethBalanceBeforeSell); // ok
        assertEq(wethBalanceAfterSell, wethBalanceBeforeSell + amountOfTokenToSell); // ok

        //The below fail, 32 tokens disappeared... for 1 weth:
        // |- emit log_named_uint(key: "      Left", val: 68979102255219266046 [6.897e19])
        // |- emit log_named_uint(key: "     Right", val: 97000000000000000000 [9.7e19])
        assertEq(poolTokenBalanceAfterSell, poolTokenBalanceBeforeSell - amountOfTokenToSell); // not ok
    }
```

\pagebreak

**Recommended Mitigation:**<br />

- Please review other function issue of this report and adapt with the below recommandation:
  - Change the function used in the return statement:

```diff
    function sellPoolTokens(uint256 poolTokenAmount) external  returns (uint256 wethAmount) {
-       return swapExactOutput(i_poolToken, i_wethToken, poolTokenAmount, uint64(block.timestamp));
+       return swapExactInput(i_poolToken, poolTokenAmount, i_wethToken, poolWethAmount, uint64(block.timestamp));
    }
```

#

\pagebreak

## Medium

### [S-M1] Using `ERC721::_mint()` can be dangerous, replace with `_safeMint()` instead and a `nonreentrant` guard from openzeppelin.

**Description:**<br />

- In `TSwapPool::_addLiquidityMintAndTransfer`, using `ERC721::_mint()` can mint ERC721 tokens to addresses which don't support ERC721 tokens. If it happens, the tokens will be stuck forever.

- **Impact:**<br />

- using `ERC721::_mint()` can mint ERC721 tokens to addresses which don't support ERC721 tokens (not able to use ERC721 even if owning some).

- `_safeMint()` can also be used maliciously to allows reentrancy attacks. To prevent it, a `nonreentrant` guard from openzeppelin can be used.

**Recommended Mitigation:**<br />

- Use `_safeMint()` instead of `_mint()` for ERC721. To ensure that the receiver is a contract that can handle ERC721 tokens and able to use them.

- Use the modifier `nonReentrant` from openzeppelin to prevent reentrancy attacks as a re-entrancy guard, if a malicious contract tries to use `_safeMint()` to attack the protocol. [https://docs.openzeppelin.com/contracts/5.x/api/utils#ReentrancyGuard](https://docs.openzeppelin.com/contracts/5.x/api/utils#ReentrancyGuard)

The below is recommended:

`TSwapPool::_addLiquidityMintAndTransfer`:

```diff
+ import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

- contract TSwapPool is ERC20
+ contract TSwapPool is ERC20, ReentrancyGuard
.
.
.
    function _addLiquidityMintAndTransfer(
        uint256 wethToDeposit,
        uint256 poolTokensToDeposit,
        uint256 liquidityTokensToMint
    )
        private
+       nonReentrant
    {
-        _mint(msg.sender, liquidityTokensToMint);
+        _safeMint(msg.sender, liquidityTokensToMint);

.
,
,
    }
```

#

### [S-M2] Fee-on-transfert, rebase logics from weird ERC20s and ERC777 tokens breaks the invariant, due to extra tokens minted or reentrancy attack.

**Description:**<br />

Weird tokens, that can be rebase, or have a fee-on-transfert logic, can break the invariant of the protocol. There is also tokens with reentrancy problems.

Tokens having a compounding interest, or getting their number increased over time will break the pool ratio as the number of WETH doesn't increase over time.
So the ratio of 1:1 will be broken.

A list of weird ERC20 [https://github.com/d-xo/weird-erc20](https://github.com/d-xo/weird-erc20)

**Impact:**<br />

- Breaking pool ratio and possible reentrancy attack on various tokens.
- The `SafeErc20` library could not protect against all of those tokens.

\pagebreak

**Proof of Concept:**<br />

Example Using a basic weird token that use the `fee-on-transfer` logic:

- The fee is set to the number `1000`. So please, be careful to also look at last digits of numbers in the result below. Don't look only at first digits.

First here is the result:

```javascript
//   Liquidity provider balance of shitcoin:                        100000000000000000000
//   User balance of shitcoin:                                         999999999999999000
//   Liquidity provider balance of shitcoin after transfer to User:  99000000000000000000
//   Balance of Weth in the pool:                                     1000000000000000000
//   Balance of WeirdERC20 with fee on transfer:                       999999999999999000
//   Balance of Liquidity provider after deposit:                    98000000000000000000
//   Balance of Liquidity provider after withdraw:                   98999999999999998000
//   Balance of shitcoin in the pool after withdraw:                                    0
```

Steps taken for the above result:

1. Create the token, mint it to the `liquidity provider`. -> `100000000000000000000` tokens.
2. Transfer the equivalent of `1e18` of the token to `user`. -> To show in a more easy way, that `user` is not getting the expected amount of tokens. So the same will also happen if the `user` is the liquidity pool. -> `999999999999999000` tokens received.
3. Check the balance of the `liquidity provider` after the transfer. -> `99000000000000000000` tokens.
4. Create a liquidity pool and deposit tokens at a ratio of 1:1.
5. Check the balance of the pool after deposit -> `999999999999999000` tokens.
6. Balance of the `liquidity provider` after deposit -> `98000000000000000000` tokens.
7. Withdraw all liquidity from the pool.
8. Check the balance of the `liquidity provider` after withdraw -> `98999999999999998000` tokens.

\pagebreak

In the process, due to fees, when a transfer occur, tokens amount is decreasing by `1000`, `WETH` doesn't decrease by default, so the ratio is broken.

- requirements for the above test: requires an additional file to place in `./test/mocks/` called `ERC20MockFeeOnTransfer.sol` containing the below code:

<details>
<summary>ERC20MockFeeOnTransfer code</summary>

```javascript
// Copyright (C) 2017, 2018, 2019, 2020 dbrock, rain, mrchico, d-xo
// SPDX-License-Identifier: AGPL-3.0-only

// adapted from https://github.com/d-xo/weird-erc20/blob/main/src/TransferFee.sol

pragma solidity >=0.6.12;

contract Math {
// --- Math ---
function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
require((z = x + y) >= x);
}

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

}

contract WeirdERC20 is Math {
// --- ERC20 Data ---
string public name;
string public symbol;
uint8 public decimals;
uint256 public totalSupply;
bool internal allowMint = true;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Approval(address indexed src, address indexed guy, uint256 wad);
    event Transfer(address indexed src, address indexed dst, uint256 wad);

    // --- Init ---
    constructor(string memory _name, string memory _symbol, uint8 _decimalPlaces) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimalPlaces;
    }

    // --- Token ---
    function transfer(address dst, uint256 wad) public virtual returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint256 wad) public virtual returns (bool) {
        require(balanceOf[src] >= wad, "WeirdERC20: insufficient-balance");
        if (src != msg.sender && allowance[src][msg.sender] != type(uint256).max) {
            require(allowance[src][msg.sender] >= wad, "WeirdERC20: insufficient-allowance");
            allowance[src][msg.sender] = sub(allowance[src][msg.sender], wad);
        }
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);
        emit Transfer(src, dst, wad);
        return true;
    }

    function approve(address usr, uint256 wad) public virtual returns (bool) {
        allowance[msg.sender][usr] = wad;
        emit Approval(msg.sender, usr, wad);
        return true;
    }

    function mint(address to, uint256 _amount) public {
        require(allowMint, "WeirdERC20: minting is off");

        _mint(to, _amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "WeirdERC20: mint to the zero address");

        totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            balanceOf[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function burn(address from, uint256 _amount) public {
        _burn(from, _amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "WeirdERC20: burn from the zero address");

        uint256 accountBalance = balanceOf[account];
        require(accountBalance >= amount, "WeirdERC20: burn amount exceeds balance");
        unchecked {
            balanceOf[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);
    }

    function toggleMint() public {
        allowMint = !allowMint;
    }

}

contract ERC20MockFeeOnTransfer is WeirdERC20 {
uint256 private fee;

    // --- Init ---
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimalPlaces,
        uint256 _fee
    )
        WeirdERC20(_name, _symbol, _decimalPlaces)
    {
        fee = _fee;
    }

    // --- Token ---
    function transferFrom(address src, address dst, uint256 wad) public override returns (bool) {
        require(balanceOf[src] >= wad, "ERC20MockFeeOnTransfer: insufficient-balance");
        // don't worry about allowances for this mock
        //if (src != msg.sender && allowance[src][msg.sender] != type(uint).max) {
        //    require(allowance[src][msg.sender] >= wad, "ERC20MockFeeOnTransfer insufficient-allowance");
        //    allowance[src][msg.sender] = sub(allowance[src][msg.sender], wad);
        //}

        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], sub(wad, fee));
        balanceOf[address(0)] = add(balanceOf[address(0)], fee);

        emit Transfer(src, dst, sub(wad, fee));
        emit Transfer(src, address(0), fee);

        return true;
    }

}

```

</details>

- Add import and contract declaration / creation in the `TSwapPool.t.sol` , see below:

```diff
import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
+ import { ERC20MockFeeOnTransfer } from "../mocks/ERC20MockFeeOnTransfer.sol"; // ERC20MockFeeOnTransfer.sol for weird
    // token test

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;
+    ERC20MockFeeOnTransfer shitcoin; // ERC20MockFeeOnTransfer.sol for weird token test

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();

+        shitcoin = new ERC20MockFeeOnTransfer("FeeOnTransferCoin", "SHIT", 18, 1000); // ERC20MockFeeOnTransfer.sol
            // for
            // weird token test || parameters : name, symbol, decimals number, fee when transfer occur

        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        weth.mint(liquidityProvider, 200e18);
        poolToken.mint(liquidityProvider, 200e18);

        weth.mint(user, 100e18);
        poolToken.mint(user, 100e18);
    }
.
.
.
}

```

- Then add the following test case to `TSwapPool.t.sol`:

<details>
<summary>Test code</summary>

```javascript
    function testWeirdErc20WithFee() public {
        // fee set to 1000 at contract creation in setup

        //   Liquidity provider balance of shitcoin:                        100000000000000000000
        //   User balance of shitcoin:                                         999999999999999000
        //   Liquidity provider balance of shitcoin after transfer to User:  99000000000000000000
        //   Balance of Weth in the pool:                                     1000000000000000000
        //   Balance of WeirdERC20 with fee on transfer:                       999999999999999000
        //   Balance of Liquidity provider after deposit:                    98000000000000000000
        //   Balance of Liquidity provider after withdraw:                   98999999999999998000
        //   Balance of shitcoin in the pool after withdraw:                                    0
        uint256 amountUsedForInteraction = 1 ether;

        vm.startPrank(liquidityProvider);
        shitcoin.mint(address(liquidityProvider), 100e18);
        // balance of shitcoin in liquidity provider
        uint256 startingShitcoinBalance = shitcoin.balanceOf(liquidityProvider);
        console.log("Liquidity provider balance of shitcoin: ", startingShitcoinBalance);

        // transfer shitcoin token to user and check user balance, transfer 2e18 (2 ether value)
        shitcoin.transferFrom(address(liquidityProvider), address(user), amountUsedForInteraction);
        console.log("User balance of shitcoin: ", shitcoin.balanceOf(user));
        // 1 ether instead of 2 has been transferred, due to 1 ether fee.

        // check liquidity provider after transfer
        console.log(
            "Liquidity provider balance of shitcoin after transfer to User: ", shitcoin.balanceOf(liquidityProvider)
        );

        // now let deposit into a pool and withdraw from the pool
        // create the pool
        pool = new TSwapPool(address(shitcoin), address(weth), "SHIT/WETH", "SW");
        // approve token
        weth.approve(address(pool), amountUsedForInteraction);
        shitcoin.approve(address(pool), amountUsedForInteraction);

        //capture balance before deposit, as in this test a transfer to external user is also made, for easy
        // understanding.
        uint256 balanceBeforeDeposit = shitcoin.balanceOf(address(liquidityProvider));

        //deposit to the pool
        pool.deposit(amountUsedForInteraction, 0, amountUsedForInteraction, uint64(block.timestamp));

        // check deposited tokens
        console.log("Balance of Weth in the pool: ", weth.balanceOf(address(pool)));
        console.log("Balance of WeirdERC20 with fee on transfer: ", shitcoin.balanceOf(address(pool)));

        // capture the actual balance of shitcoin after deposit
        uint256 shitcoinBalanceAfterDeposit = shitcoin.balanceOf(address(liquidityProvider));
        console.log("Balance of Liquidity provider after deposit: ", shitcoinBalanceAfterDeposit);

        // withdraw tokens from the pool
        pool.withdraw(
            pool.balanceOf(liquidityProvider),
            1, // minWethToWithdraw
            1, // minPoolTokensToWithdraw
            uint64(block.timestamp)
        );

        // check if initial shitcoin balance and ending balance is equal
        uint256 shitcoinBalanceAfterWithdraw = shitcoin.balanceOf(liquidityProvider);
        console.log("Balance of Liquidity provider after withdraw: ", shitcoinBalanceAfterWithdraw);

        // pool balance
        console.log("Balance of shitcoin in the pool after withdraw: ", shitcoin.balanceOf(address(pool)));
        vm.stopPrank();

        assertLt(shitcoinBalanceAfterWithdraw, balanceBeforeDeposit);
    }
```

</details>

**Recommended Mitigation:**<br />

- Create a whitelist / blacklist array of tokens that can be used or not used in the protocol.
- restrict the use of such token if it is not well known token.
- Need manual review of such tokens.
- If a token is reviewed, whitelist it for other pool creation
- or stick to well known tokens only, like the AAVE protocol

#

\pagebreak

## Low

### [S-L1] `PoolCreated` event should be `indexed` for better searchability and filtering.

**Description:**<br />

- Since it is an AMM, better to index event for third party app to track the state of pools.

- `PoolFactory` contract is not indexed, which makes it difficult to search and filter for specific transactions and state changes in case you need to.

- Major events in `TSwapPool` using 3 parameters, are `indexed`.
- Note: Indexed event are stored more efficiently.

**Impact:**<br />

- Hard to retrieve and filter events. It is a low severity issue, but it is a good practice to index events for better searchability and filtering.

**Recommended Mitigation:**<br />

Add the `indexed` keyword:

```diff
-    event PoolCreated(address tokenAddress, address poolAddress);

+    event PoolCreated(address tokenAddress, address poolAddress) indexed;
```

#

### [S-L2] The returned value `uint256 output` declared in the function signature doesn't exist in the `TSwapPool::swapExactInput` function,

**Description:**<br />

- The returned value `uint256 output` doesn't exist in the `TSwapPool::swapExactInput` function, but it is declared in the function signature.

**Impact:**<br />

- Returned value will always be 0.
- The impact is low, but if logic is to have it output a value, it should be declared in the function.

\pagebreak

**Recommended Mitigation:**<br />

- I think the value that should be returned is `outputAmount` instead of `output`. If it is the case it also needs to be set inside the function itself to be returned.

#

### [S-L3] `TSwapPool::LiquidityAdded` event parameters in wrong order, returned information is erroneous.

**Description:**<br />

`uint256 poolTokensDeposited` and `uint256 wethDeposited` are inverted.

- Returned information is erroneous.

Emitted event:

```javascript
emit LiquidityAdded(msg.sender, poolTokensToDeposit, wethToDeposit);
```

Declared Event:

```diff
-    event LiquidityAdded(address indexed liquidityProvider, uint256 wethDeposited, uint256 poolTokensDeposited);
+    event LiquidityAdded(address indexed liquidityProvider, uint256 poolTokensDeposited, uint256 wethDeposited);
```

#

\pagebreak

## Informational

### [S-Info1] Magic Numbers

**Description:**<br />

All number literals should be replaced with constants. This makes the code more readable and easier to maintain. Numbers without context are called "magic numbers".

**Recommended Mitigation:**<br />

- Replace all magic numbers with constants.

`TSwapPool.sol` contract:

```diff
+       uint256 public constant WHATEVER_IS_997 = 997;
+       uint256 public constant WHATEVER_IS_1000 = 1000;
+       uint256 public constant WHATEVER_IS_10000 = 10000;
+       uint256 public constant WHATEVER_IS_1_000_000_000_000_000_000 = 1_000_000_000_000_000_000;
+       uint256 public constant WHATEVER_IS_1e18 = 1e18;
.
.
.
-       uint256 inputAmountMinusFee = inputAmount * 997;
-       uint256 denominator = (inputReserves * 1000) + inputAmountMinusFee;
+       uint256 inputAmountMinusFee = inputAmount * WHATEVER_IS_997;
+       uint256 denominator = (inputReserves * WHATEVER_IS_1000) + inputAmountMinusFee;
.
.
.
-        return ((inputReserves * outputAmount) * 10000) / ((outputReserves - outputAmount) * 997);
+        return ((inputReserves * outputAmount) * WHATEVER_IS_10000) / ((outputReserves - outputAmount) * WHATEVER_IS_997);
.
.
.
-        outputToken.safeTransfer(msg.sender, 1_000_000_000_000_000_000);
+        outputToken.safeTransfer(msg.sender, WHATEVER_IS_1_000_000_000_000_000_000);
.
.
.
-        getOutputAmountBasedOnInput(1e18, i_wethToken.balanceOf(address(this)), i_poolToken.balanceOf(address(this)));
+        getOutputAmountBasedOnInput(WHATEVER_IS_1e18, i_wethToken.balanceOf(address(this)), i_poolToken.balanceOf(address(this)));
.
.
.
-        getOutputAmountBasedOnInput(1e18, i_poolToken.balanceOf(address(this)), i_wethToken.balanceOf(address(this)));
+        getOutputAmountBasedOnInput(WHATEVER_IS_1e18, i_poolToken.balanceOf(address(this)), i_wethToken.balanceOf(address(this)));
```

#

### [S-Info2] The function `swapExactInput()` is never used in `TSwapPool` contract, remove it or change its use case.

**Description:**<br />

The function `swapExactInput()` is never used and should be removed or changed to `external` to be used. Or change the logic of its use case depending on the intended use of it.

```diff
   function swapExactInput(
        IERC20 inputToken,
        uint256 inputAmount,
        IERC20 outputToken,
        uint256 minOutputAmount,
        uint64 deadline
    )
-       public
+       external
        revertIfZero(inputAmount)
        revertIfDeadlinePassed(deadline)
        returns (uint256 output)
    {
        uint256 inputReserves = inputToken.balanceOf(address(this));
        uint256 outputReserves = outputToken.balanceOf(address(this));

        uint256 outputAmount = getOutputAmountBasedOnInput(
            inputAmount,
            inputReserves,
            outputReserves
        );

        if (outputAmount < minOutputAmount) {
            revert TSwapPool__OutputTooLow(outputAmount, minOutputAmount);
        }

        _swap(inputToken, inputAmount, outputToken, outputAmount);
    }
```

#

### [S-Info3] Solidity 0.8.20 by default target EVM version to `Shanghai` by default, `PUSH0` is not supported by all chains

**Description:**<br />

Solc compiler version 0.8.20 switches the default target EVM version to Shanghai, which means that the generated bytecode will include PUSH0 opcodes. Be sure to select the appropriate EVM version in case you intend to deploy on a chain other than mainnet like L2 chains that may not support PUSH0, otherwise deployment of your contracts will fail.

- Since the protocol is meant to be deployed on Ethereum, it is not an issue, more of an information just in case.

#

### [S-Info4] The variable `poolTokenReserves` is never used in `TSwapPool::deposit` function, remove it or change its use case.

**Description:**<br />

The variable `poolTokenReserves` is never used in `TSwapPool::deposit` function and should be removed or changed integrated following the logic explained in comments belows it. Or change the logic of it depending on the intended use of it.

```diff
        if (totalLiquidityTokenSupply() > 0) {
            uint256 wethReserves = i_wethToken.balanceOf(address(this));
-           uint256 poolTokenReserves = i_poolToken.balanceOf(address(this)); // @audit unused local variable
            // Our invariant says weth, poolTokens, and liquidity tokens must always have the same ratio after the
            // initial deposit
            // poolTokens / constant(k) = weth
            // weth / constant(k) = liquidityTokens
            // aka...
            // weth / poolTokens = constant(k)
            // To make sure this holds, we can make sure the new balance will match the old balance
            // (wethReserves + wethToDeposit) / (poolTokenReserves + poolTokensToDeposit) = constant(k)
            // (wethReserves + wethToDeposit) / (poolTokenReserves + poolTokensToDeposit) =
            // (wethReserves / poolTokenReserves)
            //
            // So we can do some elementary math now to figure out poolTokensToDeposit...
            // (wethReserves + wethToDeposit) / poolTokensToDeposit = wethReserves
            // (wethReserves + wethToDeposit)  = wethReserves * poolTokensToDeposit
            // (wethReserves + wethToDeposit) / wethReserves  =  poolTokensToDeposit
            uint256 poolTokensToDeposit = getPoolTokensToDepositBasedOnWeth(
                wethToDeposit
            );
            if (maximumPoolTokensToDeposit < poolTokensToDeposit) {
                revert TSwapPool__MaxPoolTokenDepositTooHigh(
                    maximumPoolTokensToDeposit,
                    poolTokensToDeposit
                );
            }

            // We do the same thing for liquidity tokens. Similar math.
            liquidityTokensToMint =
                (wethToDeposit * totalLiquidityTokenSupply()) /
                wethReserves;
            if (liquidityTokensToMint < minimumLiquidityTokensToMint) {
                revert TSwapPool__MinLiquidityTokensToMintTooLow(
                    minimumLiquidityTokensToMint,
                    liquidityTokensToMint
                );
            }
            _addLiquidityMintAndTransfer(
                wethToDeposit,
                poolTokensToDeposit,
                liquidityTokensToMint
            );
        }
```

#

### [S-Info5] Zero-check missing in constructors.

**Description:**<br />

Missing zero-check in `PoolFactory::constructor` and `TSwapPool::constructor` on `wethToken` parameter.

`TSwapPool::constructor`:

```diff
    constructor(
        address poolToken,
        address wethToken,
        string memory liquidityTokenName,
        string memory liquidityTokenSymbol
    ) ERC20(liquidityTokenName, liquidityTokenSymbol) {
+       if (poolToken == address(0) || wethToken == address(0)) {
+           revert TSwapPool__InvalidToken();
*       }
        i_wethToken = IERC20(wethToken);
        i_poolToken = IERC20(poolToken);
    }
```

`PoolFactory::constructor`:

```diff
+   error PoolFactory__ZeroAddress();

    constructor(address wethToken) {
+       if (wethToken == address(0)) {
+           revert PoolFactory__ZeroAddress();
+       }
        i_wethToken = wethToken;
    }

```

#

\pagebreak

### [S-Info6] IERC20 interface duplicate, same function available in `ERC20.sol` of OpenZeppelin using the latest version of solidity.

**Description:**<br />

Importing 2 `IERC20` interfaces, one from `OpenZeppelin` in `TSwapPool` contract and one from `Forge-Std` library in `PoolFactory` contract. The one from `OpenZeppelin` is enough and should be used.

`PoolFactory::IERC20`, the below function are available in the `ERC20.sol` library from `OpenZeppelin`:

```javascript
    /// @notice Returns the name of the token.
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token.
    function symbol() external view returns (string memory);

    /// @notice Returns the decimals places of the token.
    function decimals() external view returns (uint8);
```

Change could be made where `name()`, `symbol()` and `decimals()` are used in `PoolFactory` contract instead.

- Also the one from `Forge-Std` use a different solidity versions than others libraries used in the project.

```diff
	- [0.8.20](src/PoolFactory.sol#L15)
	- [0.8.20](src/TSwapPool.sol#L15)
-	- [>=0.6.2](lib/forge-std/src/interfaces/IERC20.sol#L2)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol#L3)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Address.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Context.sol#L4)

```

#

### [S-Info7] Wrong function used for grabbing the token symbol.

**Description:**<br />

Use of `.name()` instead of `.symbol()` in `PoolFactory::createPool` function, when concataining token symbols strings.

```javascript
-       string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
-       string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).symbol());
```

Change could be made where `name()`, `symbol()` and `decimals()` are used in `PoolFactory` contract instead.

#

### [S-Info8] `PoolFactory::PoolFactory__PoolDoesNotExist` unused error.

**Description:**<br />

Unused error declared `PoolFactory::PoolFactory__PoolDoesNotExist`, in `PoolFactory` contract.

```javascript
    error PoolFactory__PoolDoesNotExist();
```

#

\pagebreak

### [S-Info9] Changement of "state", even if not state variables should be set before an external call to follow CEI.

**Description:**<br />

In the else statement of the `TSwapPool::deposit` function, the `liquidityTokensToMint` variable should be set before the `_addLiquidityMintAndTransfer` function call to follow the Checks-Effects-Interactions pattern. Even if there is no re-entrancy danger in this case, it is good habits.

```diff
else {
            // This will be the "initial" funding of the protocol. We are starting from blank here!
            // We just have them send the tokens in, and we mint liquidity tokens based on the weth
+           liquidityTokensToMint = wethToDeposit;
            _addLiquidityMintAndTransfer(wethToDeposit, maximumPoolTokensToDeposit, wethToDeposit);
-           liquidityTokensToMint = wethToDeposit;
        }
```

#

### [S-Info10] `TSwapPool::totalLiquidityTokenSupply` function should be `external` instead of `public`.

**Description:**<br />

`TSwapPool::totalLiquidityTokenSupply` function should be `external` instead of `public`.

```diff
-   function totalLiquidityTokenSupply() public view returns (uint256) {
+   function totalLiquidityTokenSupply() external view returns (uint256) {
         return totalSupply();
     }
```

## Gas

- Included in above findings.
