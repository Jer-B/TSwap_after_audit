// SPDX-License-Identifier: MIT

// contract for mocking ERC20 tokens

pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("MockToken", "MOCK") {}

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}
