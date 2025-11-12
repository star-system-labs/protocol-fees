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

  function test_vesting_calculate_quarters_none(uint256 timestamp) public view {
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

    uint256 quarters = vesting.quarters();

    if (quarters == 0) {
      vm.expectRevert(IUNIVesting.OnlyQuarterly.selector);
      vesting.withdraw();
    } else {
      // The setup only approves 8 quarters worth (40M)
      uint256 expectedWithdrawal = quarters > 8 ? 8 : quarters;
      vesting.withdraw();
      assertEq(
        vestingToken.balanceOf(recipient), expectedWithdrawal * vesting.quarterlyVestingAmount()
      );

      // If more than 8 quarters vested, there should be remaining quarters
      if (quarters > 8) assertEq(vesting.quarters(), quarters - 8);
      else assertEq(vesting.quarters(), 0);
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

  function test_vesting_updateVestingAmount_revertsCannotUpdateAmount() public {
    uint256 newAmount = 10_000_000e18;

    // Warp past the start time so quarters() > 0
    vm.warp(vesting.lastQuarterlyTimestamp() + QUARTERLY_SECONDS_ESTIMATE);

    vm.prank(owner);
    vm.expectRevert(IUNIVesting.CannotUpdateAmount.selector);
    vesting.updateVestingAmount(newAmount);
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
    vm.warp(JAN_1_2026);

    vm.prank(owner);
    vesting.updateVestingAmount(newAmount);

    assertEq(vesting.quarterlyVestingAmount(), newAmount);
  }

  function test_withdraw_partialAllowance_onlyAdvancesPaidQuarters() public {
    // Setup: 3 quarters pass (15M tokens vested)
    // Using Apr 1, 2027 which gives exactly 3 quarters
    vm.warp(1_798_606_800); // Apr 1, 2027 (15 months from Jan 1, 2026)
    assertEq(vesting.quarters(), 3);

    // Owner only approves 2 quarters worth (10M)
    vm.prank(owner);
    vestingToken.approve(address(vesting), FIVE_M * 2);

    vesting.withdraw();

    // Recipient gets 10M (2 quarters worth)
    assertEq(vestingToken.balanceOf(recipient), FIVE_M * 2);

    // Timestamp only advances by 2 quarters, not 3
    // So there should still be 1 quarter remaining
    assertEq(vesting.quarters(), 1);

    // Now increase allowance and withdraw the remaining quarter
    vm.prank(owner);
    vestingToken.approve(address(vesting), FIVE_M);

    vesting.withdraw();

    // Total should now be 15M (3 quarters)
    assertEq(vestingToken.balanceOf(recipient), FIVE_M * 3);
    assertEq(vesting.quarters(), 0);
  }

  function test_withdraw_partialAllowance_lessThanOneQuarter_reverts() public {
    // Setup: 2 quarters pass (10M tokens vested)
    vm.warp(JUL_1_2026);
    assertEq(vesting.quarters(), 2);

    // Owner approves less than 1 quarter
    vm.prank(owner);
    vestingToken.approve(address(vesting), FIVE_M - 1);

    // Should revert with insufficient allowance message
    vm.expectRevert(IUNIVesting.InsufficientAllowance.selector);
    vesting.withdraw();
  }

  function test_withdraw_partialAllowance_exactlyOneQuarter() public {
    // Setup: 2 quarters pass
    vm.warp(JUL_1_2026);
    assertEq(vesting.quarters(), 2);

    // Owner approves exactly 1 quarter
    vm.prank(owner);
    vestingToken.approve(address(vesting), FIVE_M);

    vesting.withdraw();

    // Should withdraw 1 quarter, leaving 1 remaining
    assertEq(vestingToken.balanceOf(recipient), FIVE_M);
    assertEq(vesting.quarters(), 1);
  }

  function test_withdraw_zeroAllowance_reverts() public {
    // Setup: 1 quarter passes
    vm.warp(APR_1_2026);

    // Remove all allowance
    vm.prank(owner);
    vestingToken.approve(address(vesting), 0);

    // Should revert
    vm.expectRevert(IUNIVesting.InsufficientAllowance.selector);
    vesting.withdraw();
  }

  function test_withdraw_sequentialPartialWithdrawals() public {
    // Setup: 5 quarters pass (25M tokens vested)
    // Using Jan 1, 2028 which gives exactly 8 quarters (24 months from Jan 1, 2026)
    // We'll test with 5 quarters of partial withdrawals
    vm.warp(1_830_315_600); // Jan 1, 2028 (24 months = 8 quarters from Jan 1, 2026)
    uint256 totalQuarters = vesting.quarters();
    assertGe(totalQuarters, 5); // At least 5 quarters available

    // First withdrawal: approve and withdraw 2 quarters
    vm.prank(owner);
    vestingToken.approve(address(vesting), FIVE_M * 2);
    vesting.withdraw();
    assertEq(vestingToken.balanceOf(recipient), FIVE_M * 2);
    assertEq(vesting.quarters(), totalQuarters - 2);

    // Second withdrawal: approve and withdraw 1 quarter
    vm.prank(owner);
    vestingToken.approve(address(vesting), FIVE_M);
    vesting.withdraw();
    assertEq(vestingToken.balanceOf(recipient), FIVE_M * 3);
    assertEq(vesting.quarters(), totalQuarters - 3);

    // Third withdrawal: approve and withdraw 2 more quarters (total 5)
    vm.prank(owner);
    vestingToken.approve(address(vesting), FIVE_M * 2);
    vesting.withdraw();
    assertEq(vestingToken.balanceOf(recipient), FIVE_M * 5);
    assertEq(vesting.quarters(), totalQuarters - 5);
  }
}
