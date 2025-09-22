# INonce
[Git Source](https://github.com/Uniswap/phoenix-fees/blob/8538dfe0c6b5788456432221d4719ef9bd91225a/src/interfaces/base/INonce.sol)


## Functions
### nonce


```solidity
function nonce() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_null_`|`uint256`|The contract's nonce|


## Errors
### InvalidNonce
Thrown when a user-provided nonce is not equal to the contract's nonce


```solidity
error InvalidNonce();
```

