// SPDX-License-Identifier: AGPL-3.0-only

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.29;

interface IUNI is IERC20 {
  function minter() external view returns (address);
  function mintingAllowedAfter() external view returns (uint256);
  function mint(address dst, uint256 rawAmount) external;
}
