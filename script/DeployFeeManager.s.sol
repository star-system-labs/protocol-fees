// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

import {DeployFeeManagerInput} from "script/DeployFeeManagerInput.sol";
import {V3FeeManager} from "src/V3FeeManager.sol";
import {IUniswapV3FactoryOwnerActions} from "src/interfaces/IUniswapV3FactoryOwnerActions.sol";

contract DeployFeeManager is Script, DeployFeeManagerInput {
  uint256 deployerPrivateKey;

  function setUp() public {
    deployerPrivateKey = vm.envOr(
      "DEPLOYER_PRIVATE_KEY",
      uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
    );
  }

  function run() public returns (V3FeeManager) {
    vm.startBroadcast(deployerPrivateKey);

    // Deploy a new owner for the V3 factory owner actions contract.
    V3FeeManager v3FeeManager = new V3FeeManager(
      UNISWAP_GOVERNOR_TIMELOCK,
      IUniswapV3FactoryOwnerActions(UNISWAP_V3_FACTORY_ADDRESS),
      INITIAL_GLOBAL_PROTOCOL_FEE_DENOMINATOR,
      REWARD_RECEIVER
    );

    vm.stopBroadcast();

    return v3FeeManager;
  }
}
