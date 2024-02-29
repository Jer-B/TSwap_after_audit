// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { Test, console2 } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool tSwapPoolContract;

    ERC20Mock WETH;
    ERC20Mock TokenPairedA;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    int256 startingAmountA;
    int256 startingAmountWeth;

    int256 public amountAToDeposit; // the expected change happening when performing a deposit or a swap
    int256 public AmountWethToDeposit;

    int256 public actualChangeOfTokenA;
    int256 public actualChangeOfWeth;

    //starts with the deployed TSwapPool pool contract
    constructor(TSwapPool _tSwapPoolContract) {
        tSwapPoolContract = _tSwapPoolContract;

        WETH = ERC20Mock(tSwapPoolContract.getWeth()); //get Weth address from the pool getter function
        TokenPairedA = ERC20Mock(tSwapPoolContract.getPoolToken()); //get paired Token address from the pool getter
            // function
    }

    // _swap
    // if 1 token A is equivalent to 0.01 Weth, swap 1 token A for 0.01 Weth
    function swapTokenAForWethBasedOnOutputWeth(uint256 wethAfterSwap) public {
        uint256 minimumWeth = tSwapPoolContract.getMinimumWethDepositAmount();

        wethAfterSwap = bound(wethAfterSwap, minimumWeth, WETH.balanceOf(address(tSwapPoolContract))); //0 to 18.4 eth
        //avoid swapping everything in the pool
        if (wethAfterSwap >= WETH.balanceOf(address(tSwapPoolContract))) {
            return;
        }

        uint256 tokenAtoSwap = tSwapPoolContract.getInputAmountBasedOnOutput(
            wethAfterSwap,
            TokenPairedA.balanceOf(address(tSwapPoolContract)),
            WETH.balanceOf(address(tSwapPoolContract))
        );

        // in case it is too big
        if (tokenAtoSwap > type(uint64).max) {
            return;
        }

        // update starting balance
        startingAmountWeth = int256(WETH.balanceOf(address(tSwapPoolContract)));
        startingAmountA = int256(TokenPairedA.balanceOf(address(tSwapPoolContract)));

        // update first deposit amount
        AmountWethToDeposit = int256(-1) * int256(wethAfterSwap); // not gaining weth, as we substract Weth from the
            // pool
        amountAToDeposit = int256(tokenAtoSwap);

        // mint more tokens if the balance of user is too low for the swap
        if (TokenPairedA.balanceOf(user) < tokenAtoSwap) {
            TokenPairedA.mint(user, tokenAtoSwap - TokenPairedA.balanceOf(user) + 1);
        }

        // do the swap

        vm.startPrank(user);
        TokenPairedA.approve(address(tSwapPoolContract), type(uint256).max);
        tSwapPoolContract.swapExactOutput(TokenPairedA, WETH, wethAfterSwap, uint64(block.timestamp));

        vm.stopPrank();

        // pool balance change checkers after swap

        uint256 WethPoolAfterSwap = WETH.balanceOf(address(tSwapPoolContract));
        uint256 TokenPoolAfterSwap = TokenPairedA.balanceOf(address(tSwapPoolContract));

        actualChangeOfTokenA = int256(TokenPoolAfterSwap) - int256(startingAmountA);
        actualChangeOfWeth = int256(WethPoolAfterSwap) - int256(startingAmountWeth);
    }

    // deposit and swapExactOutput
    function deposit(uint256 wethAmount) public {
        uint256 minimumWeth = tSwapPoolContract.getMinimumWethDepositAmount();
        wethAmount = bound(wethAmount, minimumWeth, type(uint64).max); //0,000000001 to 18.4 eth

        // starting balance
        startingAmountWeth = int256(WETH.balanceOf(address(tSwapPoolContract)));
        startingAmountA = int256(TokenPairedA.balanceOf(address(tSwapPoolContract)));

        // first deposit amount
        AmountWethToDeposit = int256(wethAmount);
        amountAToDeposit = int256(tSwapPoolContract.getPoolTokensToDepositBasedOnWeth(wethAmount));

        // Liquidity provider actions
        vm.startPrank(liquidityProvider);
        // mint tokens
        WETH.mint(address(liquidityProvider), wethAmount);
        TokenPairedA.mint(address(liquidityProvider), uint256(amountAToDeposit));

        // approves tokens
        WETH.approve(address(tSwapPoolContract), type(uint256).max);
        TokenPairedA.approve(address(tSwapPoolContract), type(uint256).max);

        //deposit
        tSwapPoolContract.deposit(
            wethAmount,
            0, // no limit on the lp to get back
            uint256(amountAToDeposit),
            uint64(block.timestamp)
        );

        vm.stopPrank();

        // pool balance change checkers after deposit

        uint256 WethPoolAfterDeposit = WETH.balanceOf(address(tSwapPoolContract));
        uint256 TokenPoolAfterDeposit = TokenPairedA.balanceOf(address(tSwapPoolContract));

        actualChangeOfTokenA = int256(TokenPoolAfterDeposit) - int256(startingAmountA);
        actualChangeOfWeth = int256(WethPoolAfterDeposit) - int256(startingAmountWeth);
    }
}
