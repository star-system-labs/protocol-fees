// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ERC20FeeCollector
/// @author [ScopeLift](https://scopelift.co)
/// @notice Sink for protocol fees as ERC20 tokens and allows claiming via payout race.
///         Fees accumulate in this contract from external sources and can be claimed by anyone
///         willing to pay a fixed payout amount. The payout race creates a competitive mechanism
///         where claimers compete to extract accumulated fees by paying the required payout token
///         amount to the designated receiver. This incentivizes timely fee collection while
///         generating revenue for the payout receiver.
contract ERC20FeeCollector {
  using SafeERC20 for IERC20;

  /// @notice Emitted when token fees are successfully claimed.
  /// @param token Address of the ERC20 token that was claimed.
  /// @param recipient Address that received the tokens.
  /// @param caller Address that initiated the claim.
  /// @param amount Amount of fees transferred to the recipient.
  event FeesClaimed(
    address indexed token, address indexed recipient, address indexed caller, uint256 amount
  );

  /// @notice Emitted when the existing admin designates a new address as the admin.
  event AdminSet(address indexed oldAdmin, address indexed newAdmin);

  /// @notice Emitted when the admin updates the payout amount.
  event PayoutAmountSet(uint256 indexed oldPayoutAmount, uint256 indexed newPayoutAmount);

  /// @notice Thrown when no claim input data is provided.
  error ERC20FeeCollector__NoClaimInputProvided();

  /// @notice Thrown when payout receiver address is invalid (zero address).
  error ERC20FeeCollector__InvalidPayoutReceiver();

  /// @notice Thrown when payout token address is invalid (zero address).
  error ERC20FeeCollector__InvalidPayoutToken();

  /// @notice Thrown when payout amount is invalid (zero).
  error ERC20FeeCollector__InvalidPayoutAmount();

  /// @notice Thrown when a non-admin account calls an admin-only function.
  error ERC20FeeCollector__Unauthorized();

  /// @notice Thrown if the proposed admin address is the zero address.
  error ERC20FeeCollector__InvalidAddress();

  /// @notice Data structure used to specify one or more fee amounts to be exchanged for
  /// the payout amount.
  /// @param token ERC20 token to claim.
  /// @param feeRecipient Address to receive the fees.
  /// @param amountRequested Amount of fee tokens to transfer.
  struct ClaimInputData {
    IERC20 token;
    address feeRecipient;
    uint256 amountRequested;
  }

  /// @notice Address that receives the `PAYOUT_TOKEN` payout from a fee race.
  address public immutable PAYOUT_RECEIVER;

  /// @notice Token required for payout (e.g., UNI or WETH).
  IERC20 public immutable PAYOUT_TOKEN;

  /// @notice Amount of payout token required to claim fees.
  uint256 public payoutAmount;

  /// @notice The address that can call privileged methods.
  address public admin;

  /// @notice Creates a new `ERC20FeeCollector` with the specified payout configuration.
  /// @param _admin The initial admin address for this deployment.
  /// @param _payoutReceiver Address that will receive payout token payments.
  /// @param _payoutToken Address of the ERC20 token required for payouts.
  /// @param _payoutAmount Amount of payout token required to claim fees.
  constructor(
    address _admin,
    address _payoutReceiver,
    address _payoutToken,
    uint256 _payoutAmount
  ) {
    _setAdmin(_admin);
    if (_payoutReceiver == address(0)) revert ERC20FeeCollector__InvalidPayoutReceiver();
    if (_payoutToken == address(0)) revert ERC20FeeCollector__InvalidPayoutToken();
    _setPayoutAmount(_payoutAmount);

    PAYOUT_RECEIVER = _payoutReceiver;
    PAYOUT_TOKEN = IERC20(_payoutToken);
  }

  /// @notice Public method that allows any caller to claim accumulated ERC20 tokens from this
  /// contract by paying a fixed payout amount. Caller must pre-approve this contract on the payout
  /// token contract for at least the payout amount, which is transferred from the caller to the
  /// payout receiver. The accumulated fees are sent to recipients of the caller's specification.
  ///
  /// A quick example illustrates why an external party, such as an MEV searcher, would be
  /// incentivized to call this method. Imagine 50,000 USDC and 10,000 DAI have accumulated in
  /// this collector. Assume the payout token and payout amount are WETH and 10e18 respectively.
  /// Finally, assume the spot USD price of ETH is $2,500, and both stablecoins are trading at
  /// their $1 peg. As fees accumulate in this contract, once the total value exceeds $25,000 in
  /// stablecoins, it becomes profitable for an external party to arbitrage by calling this method,
  /// paying 10 WETH (worth $25K) and receiving more than $25K worth of stablecoins. (This ignores
  /// other details real searchers would consider, such as gas costs and builder fees).
  ///
  /// The same mechanism applies regardless of what tokens have accumulated or what the payout token
  /// and amount are. Effectively, as fees accumulate, it eventually becomes profitable to "buy"
  /// them for less than their market value by paying the fixed payout amount.
  ///
  /// @param _claimInputs Array of claim input data. Each element contains:
  /// - `token`: The ERC20 token to claim from this contract
  /// - `feeRecipient`: The address to which claimed tokens will be sent
  /// - `amountRequested`: The amount of tokens to claim. Must not exceed the contract's balance
  ///
  /// @dev The entire transaction is atomic - if any individual transfer fails, the entire
  /// transaction reverts, including the payout transfer. This protects callers from losing their
  /// payout if any token claim fails.
  function claimFees(ClaimInputData[] calldata _claimInputs) external {
    if (_claimInputs.length == 0) revert ERC20FeeCollector__NoClaimInputProvided();

    PAYOUT_TOKEN.safeTransferFrom(msg.sender, PAYOUT_RECEIVER, payoutAmount);

    for (uint256 i = 0; i < _claimInputs.length; i++) {
      ClaimInputData calldata _input = _claimInputs[i];

      _input.token.safeTransfer(_input.feeRecipient, _input.amountRequested);

      emit FeesClaimed(
        address(_input.token), _input.feeRecipient, msg.sender, _input.amountRequested
      );
    }
  }

  /// @notice Reassign the admin role to a new address. Must be called by the existing admin.
  /// @param _newAdmin The address of the new admin.
  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    _setAdmin(_newAdmin);
  }

  /// @notice Update the payout amount to a new value. Must be called by admin.
  /// @param _newPayoutAmount The value that will be the new payout amount.
  /// @dev The admin can front-run pending `claimFees` transactions by changing this value.
  function setPayoutAmount(uint256 _newPayoutAmount) external {
    _revertIfNotAdmin();
    _setPayoutAmount(_newPayoutAmount);
  }

  /// @notice Internal function to change the admin.
  function _setAdmin(address _newAdmin) internal {
    if (_newAdmin == address(0)) revert ERC20FeeCollector__InvalidAddress();
    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Internal function to change the payout amount.
  function _setPayoutAmount(uint256 _newPayoutAmount) internal {
    if (_newPayoutAmount == 0) revert ERC20FeeCollector__InvalidPayoutAmount();
    emit PayoutAmountSet(payoutAmount, _newPayoutAmount);
    payoutAmount = _newPayoutAmount;
  }

  /// @notice Ensures the msg.sender is the contract admin and reverts otherwise.
  /// @dev Place inside methods to make them admin-only.
  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) revert ERC20FeeCollector__Unauthorized();
  }
}
