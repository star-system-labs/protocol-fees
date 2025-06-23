// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {ERC20FeeCollector} from "src/ERC20FeeCollector.sol";

abstract contract DeployERC20FeeCollectorBaseImpl is Script {
  /// @notice Creates a wallet for deployment using the private key from environment
  /// @dev Requires DEPLOYER_PRIVATE_KEY to be set in the environment
  /// @return wallet The wallet to be used for deployment
  function _deploymentWallet() internal virtual returns (Vm.Wallet memory) {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    return vm.createWallet(deployerPrivateKey);
  }

  function run() public virtual returns (ERC20FeeCollector);

  /// @notice Creates the ERC20FeeCollector with the provided configuration
  function _deploy(
    address _admin,
    address _payoutReceiver,
    address _payoutToken,
    uint256 _payoutAmount
  ) internal returns (ERC20FeeCollector) {
    Vm.Wallet memory wallet = _deploymentWallet();
    vm.startBroadcast(wallet.privateKey);

    ERC20FeeCollector feeCollector =
      new ERC20FeeCollector(_admin, _payoutReceiver, _payoutToken, _payoutAmount);

    vm.stopBroadcast();

    return feeCollector;
  }
}
