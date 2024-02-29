// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC20MockFeeOnTransfer } from "../mocks/ERC20MockFeeOnTransfer.sol"; // ERC20MockFeeOnTransfer.sol for weird
    // token test

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;
    ERC20MockFeeOnTransfer shitcoin; // ERC20MockFeeOnTransfer.sol for weird token test

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();

        shitcoin = new ERC20MockFeeOnTransfer("FeeOnTransferCoin", "SHIT", 18, 1000); // ERC20MockFeeOnTransfer.sol
            // for
            // weird token test || parameters : name, symbol, decimals number, fee when transfer occur

        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        weth.mint(liquidityProvider, 200e18);
        poolToken.mint(liquidityProvider, 200e18);

        weth.mint(user, 100e18);
        poolToken.mint(user, 100e18);
    }

    function testDeposit() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.balanceOf(liquidityProvider), 100e18);
        assertEq(weth.balanceOf(liquidityProvider), 100e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 100e18);

        assertEq(weth.balanceOf(address(pool)), 100e18);
        assertEq(poolToken.balanceOf(address(pool)), 100e18);
    }

    function testDepositSwap() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        poolToken.approve(address(pool), 10e18);
        // After we swap, there will be ~110 tokenA, and ~91 WETH
        // 100 * 100 = 10,000
        // 110 * ~91 = 10,000
        uint256 expected = 9e18;

        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        assert(weth.balanceOf(user) >= expected);
    }

    function testWithdraw() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));

        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 100e18, 100e18, uint64(block.timestamp));

        assertEq(pool.totalSupply(), 0);
        assertEq(weth.balanceOf(liquidityProvider), 200e18);
        assertEq(poolToken.balanceOf(liquidityProvider), 200e18);
    }

    function testCollectFees() public {
        vm.startPrank(liquidityProvider);
        weth.approve(address(pool), 100e18);
        poolToken.approve(address(pool), 100e18);
        pool.deposit(100e18, 100e18, 100e18, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(user);
        uint256 expected = 9e18;
        poolToken.approve(address(pool), 10e18);
        pool.swapExactInput(poolToken, 10e18, weth, expected, uint64(block.timestamp));
        vm.stopPrank();

        vm.startPrank(liquidityProvider);
        pool.approve(address(pool), 100e18);
        pool.withdraw(100e18, 90e18, 100e18, uint64(block.timestamp));
        assertEq(pool.totalSupply(), 0);
        assert(weth.balanceOf(liquidityProvider) + poolToken.balanceOf(liquidityProvider) > 400e18);
    }

    /*//////////////////////////////////////////////////////////////
                               AUDIT-TEST
    //////////////////////////////////////////////////////////////*/

    // test based on deposit and swapping 10 times to get incentives and check the invariant after
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
        // ├─ emit log_named_uint(key: "      Left", val: 68979102255219266046 [6.897e19])
        // ├─ emit log_named_uint(key: "     Right", val: 97000000000000000000 [9.7e19])
        assertEq(poolTokenBalanceAfterSell, poolTokenBalanceBeforeSell - amountOfTokenToSell); // not ok
    }

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
}
