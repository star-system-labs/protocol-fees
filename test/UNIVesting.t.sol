// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {UNIVesting} from "../src/UNIVesting.sol";
import {IUNIVesting} from "../src/interfaces/IUNIVesting.sol";

contract UNIVestingTest is Test {
  MockERC20 public vestingToken;
  UNIVesting public vesting;

  address recipient;
  address owner;
  uint256 constant JAN_1_2026 = 1_767_243_600;
  uint256 constant APR_1_2026 = 1_775_019_600;
  uint256 constant JUL_1_2026 = 1_782_882_000;
  uint256 constant FIVE_M = 5_000_000 ether;
  uint256 constant HUNDRED_M = 100_000_000 ether;
  uint256 constant QUARTERLY_SECONDS_ESTIMATE = 91.25 days;

  function setUp() public {
    vestingToken = new MockERC20("Test UNI", "TUNI", 18);
    recipient = makeAddr("recipient");
    owner = makeAddr("owner");
    vestingToken.mint(owner, HUNDRED_M);
    vesting = new UNIVesting(address(vestingToken), recipient);
    vesting.transferOwnership(owner);
    vm.prank(owner);
    vestingToken.approve(address(vesting), FIVE_M * 8);
  }

  function test_vesting_approval() public view {
    assertEq(vestingToken.allowance(owner, address(vesting)), FIVE_M * 8);
  }

  function test_vesting_lastQuarterlyTimestamp() public view {
    assertEq(vesting.lastQuarterlyTimestamp(), JAN_1_2026);
  }

  function test_vesting_withdraw_revertsOnlyQuarterly(uint256 timestamp) public {
    vm.assume(timestamp < APR_1_2026);
    vm.warp(timestamp);
    vm.expectRevert(IUNIVesting.OnlyQuarterly.selector);
    vesting.withdraw();
  }

  function test_vesting_calculate_quarters_none(uint256 timestamp) public {
    // before Apr 1, 2026
    vm.assume(timestamp <= APR_1_2026 - 1);
    vm.assertEq(vesting.quarters(), 0);
  }

  function test_vesting_calculate_quarters() public {
    // Mar 1, 2026
    vm.warp(1_772_341_200);
    vm.assertEq(vesting.quarters(), 0);
    // Apr 1, 2026
    vm.warp(APR_1_2026);
    vm.assertEq(vesting.quarters(), 1);
    // Apr 8, 2026
    vm.warp(1_775_664_000);
    vm.assertEq(vesting.quarters(), 1);
    // Sep 21, 2030
    vm.warp(1_916_269_541);
    vm.assertEq(vesting.quarters(), 18);
  }

  function test_fuzz_vesting_calculate_quarters(uint48 timestamp) public {
    // assume less than jan 1 2100, when the first 100 year leap skip
    vm.assume(timestamp < 4_102_462_800);
    vm.warp(timestamp);
    if (timestamp < JAN_1_2026) {
      vm.assertEq(vesting.quarters(), 0);
    } else {
      vm.assertApproxEqAbs(
        vesting.quarters(),
        (timestamp - JAN_1_2026) / QUARTERLY_SECONDS_ESTIMATE,
        1,
        "Quarter vs estimate divergence"
      );
    }
  }

  function test_vesting_withdraw() public {
    uint256 timestamp = APR_1_2026;
    vm.warp(timestamp);
    vesting.withdraw();

    assertEq(vesting.lastQuarterlyTimestamp(), timestamp);
    assertEq(vestingToken.balanceOf(recipient), vesting.quarterlyVestingAmount());
  }

  function test_vesting_withdraw_two_quarters() public {
    uint256 timestamp = JUL_1_2026;
    vm.warp(timestamp);
    vesting.withdraw();

    assertEq(vesting.lastQuarterlyTimestamp(), JUL_1_2026);
    assertEq(vestingToken.balanceOf(recipient), vesting.quarterlyVestingAmount() * 2);
  }

  function test_vesting_withdraw_updates_lastQuarterlyTimestamp() public {
    uint256 timestamp = APR_1_2026 + 500;
    vm.warp(timestamp);
    vesting.withdraw();

    assertEq(vesting.lastQuarterlyTimestamp(), APR_1_2026);
    assertEq(vestingToken.balanceOf(recipient), vesting.quarterlyVestingAmount());
  }

  function test_fuzz_vesting_withdraw(uint48 timestamp) public {
    // assume less than jan 1 2100, when the first 100 year leap skip
    vm.assume(timestamp < 4_102_462_800);
    vm.warp(timestamp);
    if (timestamp < APR_1_2026) {
      vm.expectRevert(IUNIVesting.OnlyQuarterly.selector);
      vesting.withdraw();
    } else if (timestamp < 1_838_174_400) {
      uint256 quarters = vesting.quarters();
      vesting.withdraw();
      assertEq(vestingToken.balanceOf(recipient), quarters * vesting.quarterlyVestingAmount());
    } else {
      vesting.withdraw();
      assertEq(vestingToken.balanceOf(recipient), vesting.quarterlyVestingAmount() * 8);
    }
  }

  function test_vesting_withdraw_at_exact_boundary() public {
    uint256 exactBoundary = vesting.lastQuarterlyTimestamp() + QUARTERLY_SECONDS_ESTIMATE;
    uint256 recipientBalanceBefore = vestingToken.balanceOf(recipient);

    vm.warp(exactBoundary);
    vesting.withdraw();

    uint256 recipientBalanceAfter = vestingToken.balanceOf(recipient);

    assertEq(recipientBalanceAfter - recipientBalanceBefore, vesting.quarterlyVestingAmount());
  }

  function test_vesting_updateRecipient_revertsNotAuthorized() public {
    address unauthorized = makeAddr("unauthorized");
    address newRecipient = makeAddr("newRecipient");

    vm.prank(unauthorized);
    vm.expectRevert(IUNIVesting.NotAuthorized.selector);
    vesting.updateRecipient(newRecipient);
  }

  function test_vesting_updateRecipient_succeedsAsOwner() public {
    address newRecipient = makeAddr("newRecipient");

    vm.prank(owner);
    vesting.updateRecipient(newRecipient);

    assertEq(vesting.recipient(), newRecipient);
  }

  function test_vesting_updateRecipient_succeedsAsRecipient() public {
    address newRecipient = makeAddr("newRecipient");

    vm.prank(recipient);
    vesting.updateRecipient(newRecipient);

    assertEq(vesting.recipient(), newRecipient);
  }

  function test_vesting_updateVestingAmount_revertsUnauthorized() public {
    address unauthorized = makeAddr("unauthorized");
    uint256 newAmount = 10_000_000e18;

    vm.prank(unauthorized);
    vm.expectRevert("UNAUTHORIZED");
    vesting.updateVestingAmount(newAmount);
  }

  function test_vesting_updateVestingAmount_succeeds() public {
    uint256 newAmount = 10_000_000e18;

    // Warp to after start time but before first quarter completes, so quarters() == 0
    vm.warp(vesting.lastQuarterlyTimestamp() + QUARTERLY_SECONDS_ESTIMATE - 1);

    vm.prank(owner);
    vesting.updateVestingAmount(newAmount);

    assertEq(vesting.quarterlyVestingAmount(), newAmount);
  }
}
