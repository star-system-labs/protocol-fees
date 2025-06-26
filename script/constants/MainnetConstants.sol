// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

/// @title MainnetConstants
/// @notice Deployment constants for Ethereum Mainnet (Chain ID: 1)
contract MainnetConstants {
  // Mainnet token addresses
  address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address internal constant USDC = 0xA0B86a33e6417a3f1ee0f9b4D2B0d76e3F1B75e0;

  // ERC20FeeCollector deployment configuration constants
  address internal constant ERC20_FEE_COLLECTOR_PAYOUT_RECEIVER =
    0x1234567890123456789012345678901234567890; // TODO:
    // Replace with actual receiver
  address internal constant ERC20_FEE_COLLECTOR_PAYOUT_TOKEN = WETH;
  uint256 internal constant ERC20_FEE_COLLECTOR_PAYOUT_AMOUNT = 1 ether; // 1 WETH
}
