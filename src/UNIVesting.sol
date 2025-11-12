// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {
  BokkyPooBahsDateTimeLibrary as DateTime
} from "BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
import {Owned} from "solmate/src/auth/Owned.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {IUNIVesting} from "./interfaces/IUNIVesting.sol";

/// @title UNIVesting
/// @notice A vesting contract that releases UNI tokens quarterly to a designated recipient
/// @dev The contract starts vesting on January 1, 2026 and allows withdrawals every quarter
/// (approximately 90 days) The owner must approve the contract to transfer UNI tokens on their
/// behalf
contract UNIVesting is Owned, IUNIVesting {
  using SafeTransferLib for ERC20;

  /// @notice Number of months in a quarter
  uint256 private constant MONTHS_PER_QUARTER = 3;

  /// @notice The start time for vesting
  /// @dev equivalent to January 1, 2026 00:00:00 UTC
  uint48 private constant START_TIME = 1_767_243_600;

  /// @inheritdoc IUNIVesting
  ERC20 public immutable UNI;

  /// @inheritdoc IUNIVesting
  uint256 public quarterlyVestingAmount = 5_000_000 ether;

  /// @inheritdoc IUNIVesting
  address public recipient;

  /// @inheritdoc IUNIVesting
  uint48 public lastQuarterlyTimestamp = START_TIME;

  /// @notice Restricts function access to either the contract owner or the recipient
  /// @dev Reverts with NotAuthorized if caller is neither owner nor recipient
  modifier onlyOwnerOrRecipient() {
    require(msg.sender == recipient || msg.sender == owner, NotAuthorized());
    _;
  }

  /// @notice Constructs a new UNIVesting contract
  /// @param _uni The address of the UNI token contract
  /// @param _recipient The address that will receive vested UNI tokens
  /// @dev Sets the caller as the owner and initializes lastQuarterlyTimestamp to START_TIME
  constructor(address _uni, address _recipient) Owned(msg.sender) {
    UNI = ERC20(_uni);
    recipient = _recipient;
  }

  /// @inheritdoc IUNIVesting
  function updateVestingAmount(uint256 amount) public onlyOwner {
    require(quarters() == 0, CannotUpdateAmount());
    quarterlyVestingAmount = amount;
    emit VestingAmountUpdated(amount);
  }

  /// @inheritdoc IUNIVesting
  function updateRecipient(address _recipient) public onlyOwnerOrRecipient {
    recipient = _recipient;
    emit RecipientUpdated(recipient);
  }

  /// @inheritdoc IUNIVesting
  function withdraw() public {
    // assert some time has passed to avoid underflow in quarters()
    uint48 quartersPassed = quarters();
    // assert at least one quarter has passed else no withdraw is available
    require(quartersPassed > 0, OnlyQuarterly());

    uint256 vestedAmount = quarterlyVestingAmount * uint256(quartersPassed);
    uint256 currentAllowance = UNI.allowance(owner, address(this));

    if (currentAllowance < vestedAmount) {
      // Partial withdrawal - calculate how many quarters we can actually withdraw
      uint48 withdrawableQuarters = uint48(currentAllowance / quarterlyVestingAmount);

      require(withdrawableQuarters > 0, InsufficientAllowance());

      // Only advance by the quarters we can actually pay
      lastQuarterlyTimestamp = uint48(
        DateTime.addMonths(lastQuarterlyTimestamp, withdrawableQuarters * MONTHS_PER_QUARTER)
      );

      uint256 transferAmount = quarterlyVestingAmount * uint256(withdrawableQuarters);
      UNI.safeTransferFrom(owner, recipient, transferAmount);
    } else {
      // Full withdrawal - advance by all vested quarters
      lastQuarterlyTimestamp =
        uint48(DateTime.addMonths(lastQuarterlyTimestamp, quartersPassed * MONTHS_PER_QUARTER));

      UNI.safeTransferFrom(owner, recipient, vestedAmount);
    }
  }

  /// @inheritdoc IUNIVesting
  function quarters() public view returns (uint48 quartersPassed) {
    if (block.timestamp < lastQuarterlyTimestamp) return 0;
    quartersPassed =
      uint48(DateTime.diffMonths(lastQuarterlyTimestamp, block.timestamp) / MONTHS_PER_QUARTER);
  }
}
