// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

/// @dev Stripped down from:
/// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol
interface IUniswapV2Factory {
  function feeTo() external view returns (address);
  function feeToSetter() external view returns (address);
  function getPair(address tokenA, address tokenB) external view returns (address pair);
  function setFeeTo(address _feeTo) external;
  function setFeeToSetter(address _feeToSetter) external;
}
