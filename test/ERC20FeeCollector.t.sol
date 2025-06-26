// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {ERC20FeeCollector} from "src/ERC20FeeCollector.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract ERC20FeeCollectorUnitTestBase is Test {
  ERC20FeeCollector public feeCollector;
  MockERC20 public payoutToken;
  MockERC20 public token1;
  MockERC20 public token2;

  address public payoutReceiver = makeAddr("payout receiver");
  uint256 public payoutAmount = 1e18;

  address public recipient = makeAddr("recipient");

  function setUp() public virtual {
    payoutToken = new MockERC20();
    token1 = new MockERC20();
    token2 = new MockERC20();

    feeCollector = new ERC20FeeCollector(payoutReceiver, address(payoutToken), payoutAmount);
  }

  function _mintTokensToFeeCollector(uint256 _token1Amount, uint256 _token2Amount) internal {
    token1.mint(address(feeCollector), _token1Amount);
    token2.mint(address(feeCollector), _token2Amount);
  }

  function _setupClaimer(address _claimer) internal {
    payoutToken.mint(_claimer, payoutAmount);
    vm.prank(_claimer);
    payoutToken.approve(address(feeCollector), payoutAmount);
  }
}

contract Constructor is ERC20FeeCollectorUnitTestBase {
  function testFuzz_SetsPayoutReceiver(address _payoutReceiver, uint256 _payoutAmount) public {
    vm.assume(_payoutReceiver != address(0));
    _payoutAmount = bound(_payoutAmount, 1, type(uint128).max);

    ERC20FeeCollector testCollector =
      new ERC20FeeCollector(_payoutReceiver, address(payoutToken), _payoutAmount);
    assertEq(testCollector.PAYOUT_RECEIVER(), _payoutReceiver);
  }

  function testFuzz_SetsPayoutToken(address _payoutToken, uint256 _payoutAmount) public {
    vm.assume(_payoutToken != address(0));
    _payoutAmount = bound(_payoutAmount, 1, type(uint128).max);

    ERC20FeeCollector testCollector =
      new ERC20FeeCollector(payoutReceiver, _payoutToken, _payoutAmount);
    assertEq(address(testCollector.PAYOUT_TOKEN()), _payoutToken);
  }

  function testFuzz_SetsPayoutAmount(uint256 _payoutAmount) public {
    _payoutAmount = bound(_payoutAmount, 1, type(uint128).max);

    ERC20FeeCollector testCollector =
      new ERC20FeeCollector(payoutReceiver, address(payoutToken), _payoutAmount);
    assertEq(testCollector.PAYOUT_AMOUNT(), _payoutAmount);
  }

  function testFuzz_RevertIf_PayoutReceiverIsZero(uint256 _payoutAmount) public {
    _payoutAmount = bound(_payoutAmount, 1, type(uint128).max);

    vm.expectRevert(ERC20FeeCollector.ERC20FeeCollector__InvalidPayoutReceiver.selector);
    new ERC20FeeCollector(address(0), address(payoutToken), _payoutAmount);
  }

  function testFuzz_RevertIf_PayoutTokenIsZero(uint256 _payoutAmount) public {
    _payoutAmount = bound(_payoutAmount, 1, type(uint128).max);

    vm.expectRevert(ERC20FeeCollector.ERC20FeeCollector__InvalidPayoutToken.selector);
    new ERC20FeeCollector(payoutReceiver, address(0), _payoutAmount);
  }

  function testFuzz_RevertIf_PayoutAmountIsZero(address _payoutReceiver, address _payoutToken)
    public
  {
    vm.assume(_payoutReceiver != address(0));
    vm.assume(_payoutToken != address(0));

    vm.expectRevert(ERC20FeeCollector.ERC20FeeCollector__InvalidPayoutAmount.selector);
    new ERC20FeeCollector(_payoutReceiver, _payoutToken, 0);
  }
}

contract ClaimFees is ERC20FeeCollectorUnitTestBase {
  function testFuzz_ClaimSingleFeeToken(
    address _claimer,
    uint256 _token1Balance,
    uint256 _claimAmount
  ) public {
    vm.assume(_claimer != address(0));
    _token1Balance = bound(_token1Balance, 1, type(uint128).max);
    _claimAmount = bound(_claimAmount, 1, _token1Balance);

    _setupClaimer(_claimer);

    _mintTokensToFeeCollector(_token1Balance, 0);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](1);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token1)),
      feeRecipient: recipient,
      amountRequested: _claimAmount
    });

    vm.prank(_claimer);
    feeCollector.claimFees(claims);

    assertEq(token1.balanceOf(recipient), _claimAmount);
    assertEq(token1.balanceOf(address(feeCollector)), _token1Balance - _claimAmount);
  }

  function testFuzz_ClaimMultipleFeeTokens(
    address _claimer,
    uint256 _token1Balance,
    uint256 _token2Balance,
    uint256 _claim1Amount,
    uint256 _claim2Amount
  ) public {
    vm.assume(_claimer != address(0));
    _token1Balance = bound(_token1Balance, 1, type(uint128).max);
    _token2Balance = bound(_token2Balance, 1, type(uint128).max);
    _claim1Amount = bound(_claim1Amount, 1, _token1Balance);
    _claim2Amount = bound(_claim2Amount, 1, _token2Balance);

    _setupClaimer(_claimer);

    _mintTokensToFeeCollector(_token1Balance, _token2Balance);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](2);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token1)),
      feeRecipient: recipient,
      amountRequested: _claim1Amount
    });
    claims[1] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token2)),
      feeRecipient: recipient,
      amountRequested: _claim2Amount
    });

    vm.prank(_claimer);
    feeCollector.claimFees(claims);

    assertEq(token1.balanceOf(recipient), _claim1Amount);
    assertEq(token2.balanceOf(recipient), _claim2Amount);
    assertEq(token1.balanceOf(address(feeCollector)), _token1Balance - _claim1Amount);
    assertEq(token2.balanceOf(address(feeCollector)), _token2Balance - _claim2Amount);
  }

  function testFuzz_CallerSendsPayoutAmount(
    address _claimer,
    uint256 _token1Balance,
    uint256 _claimAmount
  ) public {
    vm.assume(_claimer != address(0));
    vm.assume(_claimer != payoutReceiver);
    _token1Balance = bound(_token1Balance, 1, type(uint128).max);
    _claimAmount = bound(_claimAmount, 1, _token1Balance);

    _setupClaimer(_claimer);

    _mintTokensToFeeCollector(_token1Balance, 0);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](1);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token1)),
      feeRecipient: recipient,
      amountRequested: _claimAmount
    });

    uint256 payoutReceiverBalanceBefore = payoutToken.balanceOf(payoutReceiver);
    uint256 claimerBalanceBefore = payoutToken.balanceOf(_claimer);

    vm.prank(_claimer);
    feeCollector.claimFees(claims);

    assertEq(payoutToken.balanceOf(payoutReceiver), payoutReceiverBalanceBefore + payoutAmount);
    assertEq(payoutToken.balanceOf(_claimer), claimerBalanceBefore - payoutAmount);
  }

  function testFuzz_EmitsFeesClaimedEvent(
    address _claimer,
    uint256 _token1Balance,
    uint256 _claimAmount,
    address _recipient
  ) public {
    vm.assume(_claimer != address(0) && _recipient != address(0)); // OpenZeppelin ERC20 prevents
      // transfers to address(0)
    _token1Balance = bound(_token1Balance, 1, type(uint128).max);
    _claimAmount = bound(_claimAmount, 1, _token1Balance);

    _setupClaimer(_claimer);

    _mintTokensToFeeCollector(_token1Balance, 0);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](1);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token1)),
      feeRecipient: _recipient,
      amountRequested: _claimAmount
    });

    vm.expectEmit();
    emit ERC20FeeCollector.FeesClaimed(address(token1), _recipient, _claimer, _claimAmount);

    vm.prank(_claimer);
    feeCollector.claimFees(claims);
  }

  function testFuzz_EmitsMultipleFeesClaimedEvents(
    address _claimer,
    uint256 _token1Balance,
    uint256 _token2Balance,
    uint256 _claim1Amount,
    uint256 _claim2Amount,
    address _recipient1,
    address _recipient2
  ) public {
    vm.assume(_claimer != address(0) && _recipient1 != address(0) && _recipient2 != address(0)); // OpenZeppelin
      // ERC20
      // prevents transfers to address(0)
    _token1Balance = bound(_token1Balance, 1, type(uint128).max);
    _token2Balance = bound(_token2Balance, 1, type(uint128).max);
    _claim1Amount = bound(_claim1Amount, 1, _token1Balance);
    _claim2Amount = bound(_claim2Amount, 1, _token2Balance);

    _setupClaimer(_claimer);

    _mintTokensToFeeCollector(_token1Balance, _token2Balance);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](2);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token1)),
      feeRecipient: _recipient1,
      amountRequested: _claim1Amount
    });
    claims[1] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token2)),
      feeRecipient: _recipient2,
      amountRequested: _claim2Amount
    });

    vm.expectEmit();
    emit ERC20FeeCollector.FeesClaimed(address(token1), _recipient1, _claimer, _claim1Amount);
    vm.expectEmit();
    emit ERC20FeeCollector.FeesClaimed(address(token2), _recipient2, _claimer, _claim2Amount);

    vm.prank(_claimer);
    feeCollector.claimFees(claims);
  }

  function testFuzz_AllowsDifferentRecipientsPerClaim(
    address _claimer,
    uint256 _token1Balance,
    uint256 _token2Balance,
    uint256 _claim1Amount,
    uint256 _claim2Amount,
    address _recipient1,
    address _recipient2
  ) public {
    vm.assume(
      _claimer != address(0) && _recipient1 != address(0) && _recipient2 != address(0)
        && _recipient1 != _recipient2 && _recipient1 != address(feeCollector)
        && _recipient2 != address(feeCollector)
    ); // Prevent invalid recipients and address collisions
    _token1Balance = bound(_token1Balance, 1, type(uint128).max);
    _token2Balance = bound(_token2Balance, 1, type(uint128).max);
    _claim1Amount = bound(_claim1Amount, 1, _token1Balance);
    _claim2Amount = bound(_claim2Amount, 1, _token2Balance);

    _setupClaimer(_claimer);

    _mintTokensToFeeCollector(_token1Balance, _token2Balance);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](2);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token1)),
      feeRecipient: _recipient1,
      amountRequested: _claim1Amount
    });
    claims[1] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token2)),
      feeRecipient: _recipient2,
      amountRequested: _claim2Amount
    });

    vm.prank(_claimer);
    feeCollector.claimFees(claims);

    assertEq(token1.balanceOf(_recipient1), _claim1Amount);
    assertEq(token2.balanceOf(_recipient2), _claim2Amount);
    assertEq(token1.balanceOf(_recipient2), 0);
    assertEq(token2.balanceOf(_recipient1), 0);
  }

  function testFuzz_RevertIf_NoClaimInputsProvided(address _claimer) public {
    vm.assume(_claimer != address(0));
    _setupClaimer(_claimer);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](0);

    vm.expectRevert(ERC20FeeCollector.ERC20FeeCollector__NoClaimInputProvided.selector);
    vm.prank(_claimer);
    feeCollector.claimFees(claims);
  }

  function testFuzz_RevertIf_AmountRequestedExceedsContractBalance(
    address _claimer,
    uint256 _token1Balance,
    uint256 _excessiveAmount,
    address _recipient
  ) public {
    vm.assume(_claimer != address(0) && _recipient != address(0)); // Avoid ERC20InvalidReceiver
      // error
    _token1Balance = bound(_token1Balance, 1, type(uint128).max - 1); // Leave room for +1
    _excessiveAmount = bound(_excessiveAmount, _token1Balance + 1, type(uint128).max); // More than
      // available

    _setupClaimer(_claimer);

    _mintTokensToFeeCollector(_token1Balance, 0);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](1);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token1)),
      feeRecipient: _recipient,
      amountRequested: _excessiveAmount
    });

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        address(feeCollector),
        _token1Balance,
        _excessiveAmount
      )
    );
    vm.prank(_claimer);
    feeCollector.claimFees(claims);
  }

  function testFuzz_RevertIf_ClaimerInsufficientPayoutTokenAllowance(
    address _claimer,
    uint256 _token1Balance,
    uint256 _claimAmount,
    uint256 _insufficientAllowance,
    address _recipient
  ) public {
    vm.assume(_claimer != address(0));
    _token1Balance = bound(_token1Balance, 1, type(uint128).max);
    _claimAmount = bound(_claimAmount, 1, _token1Balance);
    _insufficientAllowance = bound(_insufficientAllowance, 0, payoutAmount - 1); // Less than
      // required

    // Setup: Give claimer payout tokens but insufficient approval
    payoutToken.mint(_claimer, payoutAmount);
    vm.prank(_claimer);
    payoutToken.approve(address(feeCollector), _insufficientAllowance);

    _mintTokensToFeeCollector(_token1Balance, 0);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](1);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token1)),
      feeRecipient: _recipient,
      amountRequested: _claimAmount
    });

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(feeCollector),
        _insufficientAllowance,
        payoutAmount
      )
    );
    vm.prank(_claimer);
    feeCollector.claimFees(claims);
  }

  function testFuzz_RevertIf_NthClaimInMultipleClaimsFails(
    address _claimer,
    uint256 _token1Balance,
    uint256 _token2Balance,
    uint256 _claim1Amount,
    uint256 _claim2Amount,
    uint256 _insufficientToken3Balance,
    address _recipient
  ) public {
    vm.assume(_claimer != address(0) && _recipient != address(0));
    _token1Balance = bound(_token1Balance, 1, type(uint128).max);
    _token2Balance = bound(_token2Balance, 1, type(uint128).max);
    _claim1Amount = bound(_claim1Amount, 1, _token1Balance);
    _claim2Amount = bound(_claim2Amount, 1, _token2Balance);
    // Token3 has less balance than what we'll try to claim
    _insufficientToken3Balance = bound(_insufficientToken3Balance, 0, type(uint128).max - 1);
    uint256 _claim3Amount = _insufficientToken3Balance + 1; // Always exceeds balance

    _setupClaimer(_claimer);

    // Create a third mock token
    MockERC20 token3 = new MockERC20();

    // Mint tokens to fee collector - token3 gets insufficient balance
    _mintTokensToFeeCollector(_token1Balance, _token2Balance);
    token3.mint(address(feeCollector), _insufficientToken3Balance);

    // Record initial balances
    uint256 initialToken1Balance = token1.balanceOf(address(feeCollector));
    uint256 initialToken2Balance = token2.balanceOf(address(feeCollector));
    uint256 initialToken3Balance = token3.balanceOf(address(feeCollector));
    uint256 initialPayoutTokenBalance = payoutToken.balanceOf(payoutReceiver);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](3);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token1)),
      feeRecipient: _recipient,
      amountRequested: _claim1Amount
    });
    claims[1] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token2)),
      feeRecipient: _recipient,
      amountRequested: _claim2Amount
    });
    claims[2] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(address(token3)),
      feeRecipient: _recipient,
      amountRequested: _claim3Amount
    });

    // Expect revert on the third token transfer
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        address(feeCollector),
        _insufficientToken3Balance,
        _claim3Amount
      )
    );
    vm.prank(_claimer);
    feeCollector.claimFees(claims);

    // Verify no tokens were transferred (atomicity)
    assertEq(token1.balanceOf(address(feeCollector)), initialToken1Balance);
    assertEq(token2.balanceOf(address(feeCollector)), initialToken2Balance);
    assertEq(token3.balanceOf(address(feeCollector)), initialToken3Balance);
    assertEq(payoutToken.balanceOf(payoutReceiver), initialPayoutTokenBalance);
  }
}
