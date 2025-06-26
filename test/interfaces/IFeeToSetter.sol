// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

/// @dev Interface extracted from:
/// https://github.com/Uniswap/governance/blob/master/contracts/FeeToSetter.sol
interface IFeeToSetter {
  function factory() external view returns (address);
  function feeTo() external view returns (address);
  function owner() external view returns (address);
  function setFeeToSetter(address feeToSetter_) external;
  function setOwner(address owner_) external;
  function toggleFees(bool on) external;
  function vestingEnd() external view returns (uint256);
}
