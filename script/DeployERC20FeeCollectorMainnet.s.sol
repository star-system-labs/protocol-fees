// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {DeployERC20FeeCollectorBaseImpl} from "script/DeployERC20FeeCollectorBaseImpl.sol";
import {MainnetConstants} from "script/constants/MainnetConstants.sol";
import {ERC20FeeCollector} from "src/ERC20FeeCollector.sol";

contract DeployERC20FeeCollectorMainnet is DeployERC20FeeCollectorBaseImpl, MainnetConstants {
  function run() public override returns (ERC20FeeCollector) {
    return _deploy(
      ERC20_FEE_COLLECTOR_ADMIN,
      ERC20_FEE_COLLECTOR_PAYOUT_RECEIVER,
      ERC20_FEE_COLLECTOR_PAYOUT_TOKEN,
      ERC20_FEE_COLLECTOR_PAYOUT_AMOUNT
    );
  }
}
