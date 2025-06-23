// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {DeployERC20FeeCollectorBaseImpl} from "script/DeployERC20FeeCollectorBaseImpl.sol";
import {ERC20FeeCollector} from "src/ERC20FeeCollector.sol";

contract DeployERC20FeeCollectorFake is DeployERC20FeeCollectorBaseImpl {
  address public admin;
  address public payoutReceiver;
  address public payoutToken;
  uint256 public payoutAmount;

  constructor(
    address _admin,
    address _payoutReceiver,
    address _payoutToken,
    uint256 _payoutAmount
  ) {
    admin = _admin;
    payoutReceiver = _payoutReceiver;
    payoutToken = _payoutToken;
    payoutAmount = _payoutAmount;
  }

  function run() public override returns (ERC20FeeCollector) {
    return _deploy(admin, payoutReceiver, payoutToken, payoutAmount);
  }
}

contract DeployERC20FeeCollectorTest is Test {
  function testFuzz_CorrectlyDeploysErc20FeeCollector(
    address admin,
    address payoutReceiver,
    address payoutToken,
    uint256 payoutAmount
  ) public {
    // Ensure valid inputs that won't cause constructor reverts
    vm.assume(admin != address(0));
    vm.assume(payoutReceiver != address(0));
    vm.assume(payoutToken != address(0));
    vm.assume(payoutAmount != 0);

    // Set up mock private key for deployment
    vm.setEnv(
      "DEPLOYER_PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    );

    DeployERC20FeeCollectorFake deployer =
      new DeployERC20FeeCollectorFake(admin, payoutReceiver, payoutToken, payoutAmount);
    ERC20FeeCollector deployed = deployer.run();

    // Verify the contract was deployed with correct configuration
    assertEq(deployed.admin(), admin);
    assertEq(deployed.PAYOUT_RECEIVER(), payoutReceiver);
    assertEq(address(deployed.PAYOUT_TOKEN()), payoutToken);
    assertEq(deployed.payoutAmount(), payoutAmount);
  }
}
