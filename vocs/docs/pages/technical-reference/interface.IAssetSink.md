# IAssetSink
[Git Source](https://github.com/Uniswap/phoenix-fees/blob/8538dfe0c6b5788456432221d4719ef9bd91225a/src/interfaces/IAssetSink.sol)

The interface for releasing assets from the contract


## Functions
### releaser

*The releaser has exclusive access to the `release()` function*


```solidity
function releaser() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`_null_`|`address`|Address of the current IReleaser|


### setReleaser

Set the address of the IReleaser contract

*only callabe by `owner`*


```solidity
function setReleaser(address _releaser) external;
```

### release

Release assets to a specified recipient

*only callable by `releaser`*


```solidity
function release(Currency[] calldata assets, address recipient) external;
```

## Errors
### Unauthorized
Thrown when an unauthorized address attempts to call a restricted function


```solidity
error Unauthorized();
```

