// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {V3FeeController} from "./feeControllers/V3FeeController.sol";
import {AssetSink} from "./AssetSink.sol";
import {Firepit} from "./releasers/Firepit.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";

contract Deployer {
  address public constant RESOURCE = 0x1000000000000000000000000000000000000000;
  uint256 public constant THRESHOLD = 69_420;
  IUniswapV3Factory public constant V3_FACTORY =
    IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

  bytes32 SALT_ASSET_SINK = 0;
  bytes32 SALT_RELEASER = 0;
  bytes32 SALT_FEE_CONTROLLER = 0;

  AssetSink public assetSink;
  Firepit public releaser;
  V3FeeController public feeController;

  //// ASSET SINK:
  /// 1. Deploy the AssetSink
  /// 3. Set the releaser on the asset sink.
  /// 4. Update the owner on the asset sink.

  /// RELEASER:
  /// 2. Deploy the Releaser.
  /// 5. Update the thresholdSetter on the releaser to the owner.
  /// 6. Update the owner on the releaser.

  /// FEE_CONTROLLER:
  /// 7. Deploy the FeeController.
  /// 8. Update the feeSetter to the owner.
  /// 9. Update the owner on the fee controller.
  constructor() {
    address owner = V3_FACTORY.owner();
    /// 1. Deploy the AssetSink.
    assetSink = new AssetSink{salt: SALT_ASSET_SINK}();
    /// 2. Deploy the Releaser.
    releaser = new Firepit{salt: SALT_RELEASER}(RESOURCE, THRESHOLD, address(assetSink));
    /// 3. Set the releaser on the asset sink.
    assetSink.setReleaser(address(releaser));
    /// 4. Update the owner on the asset sink.
    assetSink.transferOwnership(owner);

    /// 5. Update the thresholdSetter on the releaser to the owner.
    releaser.setThresholdSetter(owner);
    /// 6. Update the owner on the releaser.
    releaser.transferOwnership(owner);

    /// 7. Deploy the FeeController.
    feeController =
      new V3FeeController{salt: SALT_FEE_CONTROLLER}(address(V3_FACTORY), address(assetSink));

    /// 8. Update the feeSetter to the owner.
    feeController.setFeeSetter(owner);

    /// 9. Update the owner on the fee controller.
    feeController.transferOwnership(owner);
  }
}
