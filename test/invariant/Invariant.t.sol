// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Handler} from "./Handler.t.sol";
import {TSwapPool} from "../../src/TSwapPool.sol";
import {PoolFactory} from "../../src/PoolFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

contract Invariant is StdInvariant, Test {
    using SafeERC20 for IERC20;

    // contracts
    PoolFactory poolFactoryContract;
    TSwapPool tSwapPoolContract;
    IERC20 tokenContract;
    Handler handler;

    // Tswap use 2 tokens, WETH and any other token to paired with WETH into a pool
    // Gives back a LP token after liquidity deposit.
    ERC20Mock WETH;
    ERC20Mock TokenPairedA;

    address user = makeAddr("user");
    // address liquidityProvider = makeAddr("liquidityProvider");
    int256 startingAmountA = 100e18; // Token A
    int256 startingAmountB = 50e18; // Weth uint256 private constant MINIMUM_WETH_LIQUIDITY = 1_000_000_000;
    uint256 public constant INITIAL_SUPPLY = 1_000_000e18;

    function setUp() public {
        // let say this test contract is also the liquidity provider ????

        //set up ERCs
        WETH = new ERC20Mock();
        TokenPairedA = new ERC20Mock();

        // Factory contract and pool contract
        poolFactoryContract = new PoolFactory(address(WETH));
        tSwapPoolContract = TSwapPool(
            poolFactoryContract.createPool(address(TokenPairedA))
        );

        // mint some tokens for the liquidity provider
        TokenPairedA.mint(address(this), uint256(startingAmountA));
        WETH.mint(address(this), uint256(startingAmountB));

        // approve all tokens to be used for deposit
        TokenPairedA.approve(address(tSwapPoolContract), type(uint256).max);
        WETH.approve(address(tSwapPoolContract), type(uint256).max);

        // deposit liquidity into a pool
        tSwapPoolContract.deposit(
            uint256(startingAmountB),
            uint256(startingAmountB), // if 100 weth deposit, we pick that 1LP is equal to 1 Weth as ratio
            uint256(startingAmountA),
            uint64(block.timestamp)
        );

        // instead of interacting with the contract directly, we interact with the handler contract
        handler = new Handler(tSwapPoolContract);

        // Select selectors from the handler contract that can be used
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = handler.swapTokenAForWethBasedOnOutputWeth.selector;
        selectors[1] = handler.deposit.selector;
        // selectors[2] = handler.depositMockUsdcHandler.selector;
        // selectors[3] = handler.withdrawMockUsdcHandler.selector;

        // targeted functions are put in a new object we call fuzzSelector, using the handler contract as the address and the selectors array.
        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );

        // and target the handler contract which will then call on the main contract (else it might try to target contracts from dependencies.)
        targetContract(address(handler));
    }

    function statefulFuzz_constantProductFormulaStaysTheSameTokenA() public {
        assertEq(handler.amountAToDeposit(), handler.actualChangeOfTokenA());
    }

    function statefulFuzz_constantProductFormulaStaysTheSameWeth() public {
        assertEq(handler.AmountWethToDeposit(), handler.actualChangeOfWeth());
    }
}
