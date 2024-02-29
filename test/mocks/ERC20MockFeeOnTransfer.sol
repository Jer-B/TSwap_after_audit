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
