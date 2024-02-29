**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [uninitialized-state](#uninitialized-state) (2 results) (High)
 - [missing-zero-check](#missing-zero-check) (1 results) (Low)
 - [reentrancy-events](#reentrancy-events) (1 results) (Low)
 - [pragma](#pragma) (1 results) (Informational)
## uninitialized-state
Impact: High
Confidence: High
 - [ ] ID-0
[PoolFactory.s_pools](src/PoolFactory.sol#L27) is never initialized. It is used in:
	- [PoolFactory.createPool(address)](src/PoolFactory.sol#L47-L58)
	- [PoolFactory.getPool(address)](src/PoolFactory.sol#L63-L65)

src/PoolFactory.sol#L27


 - [ ] ID-1
[PoolFactory.s_tokens](src/PoolFactory.sol#L28) is never initialized. It is used in:
	- [PoolFactory.getToken(address)](src/PoolFactory.sol#L67-L69)

src/PoolFactory.sol#L28


## missing-zero-check
Impact: Low
Confidence: Medium
 - [ ] ID-2
[PoolFactory.constructor(address).wethToken](src/PoolFactory.sol#L40) lacks a zero-check on :
		- [i_wethToken = wethToken](src/PoolFactory.sol#L41)

src/PoolFactory.sol#L40


## reentrancy-events
Impact: Low
Confidence: Medium
 - [ ] ID-3
Reentrancy in [TSwapPool._swap(IERC20,uint256,IERC20,uint256)](src/TSwapPool.sol#L308-L322):
	External calls:
	- [outputToken.safeTransfer(msg.sender,1_000_000_000_000_000_000)](src/TSwapPool.sol#L316)
	Event emitted after the call(s):
	- [Swap(msg.sender,inputToken,inputAmount,outputToken,outputAmount)](src/TSwapPool.sol#L318)

src/TSwapPool.sol#L308-L322


## pragma
Impact: Informational
Confidence: High
 - [ ] ID-4
Different versions of Solidity are used:
	- Version used: ['0.8.20', '>=0.6.2', '^0.8.20']
	- [0.8.20](src/PoolFactory.sol#L15)
	- [0.8.20](src/TSwapPool.sol#L15)
	- [>=0.6.2](lib/forge-std/src/interfaces/IERC20.sol#L2)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol#L3)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Permit.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Address.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Context.sol#L4)

src/PoolFactory.sol#L15


