// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.29;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {V3FeeManager} from "src/V3FeeManager.sol";
import {IUniswapV3PoolOwnerActions} from "src/interfaces/IUniswapV3PoolOwnerActions.sol";
import {IUniswapV3FactoryOwnerActions} from "src/interfaces/IUniswapV3FactoryOwnerActions.sol";
import {V3FeeManagerHarness} from "test/harnesses/V3OwnerFactoryHarness.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockUniswapV3Pool} from "test/mocks/MockUniswapV3Pool.sol";
import {MockUniswapV3Factory} from "test/mocks/MockUniswapV3Factory.sol";

contract V3FeeManagerTest is Test {
  V3FeeManagerHarness factoryOwner;
  address admin = makeAddr("Admin");
  MockERC20 payoutToken;
  address rewardReceiver;
  MockUniswapV3Pool pool;
  MockUniswapV3Pool pool2;
  MockUniswapV3Pool pool3;
  MockUniswapV3Factory factory;

  function setUp() public {
    vm.label(admin, "Admin");

    payoutToken = new MockERC20();
    vm.label(address(payoutToken), "Payout Token");

    rewardReceiver = makeAddr("Reward Receiver");

    pool = new MockUniswapV3Pool();
    vm.label(address(pool), "Pool 1");

    pool2 = new MockUniswapV3Pool();
    vm.label(address(pool2), "Pool 2");
    pool3 = new MockUniswapV3Pool();
    vm.label(address(pool3), "Pool 3");

    factory = new MockUniswapV3Factory();
    vm.label(address(factory), "Factory");
  }

  function _getValidGlobalFee(uint256 _seed) internal pure returns (uint8 _fee) {
    _fee = uint8(bound(_seed, 0, 10));
    if (_fee == 0) return _fee;
    if (_fee < 4) _fee += 3;
  }

  // In order to fuzz over the payout amount, we require each test to call this method to deploy
  // the factory owner before doing anything else.
  function _deployFeeManagerWithPayoutAmount(uint256 _payoutAmount) public {
    vm.assume(_payoutAmount != 0);
    uint8 _globalProtocolFeeDenominator = 10;
    return _deployFeeManagerWithPayoutAndFeeAmount(_payoutAmount, _globalProtocolFeeDenominator);
  }

  function _deployFeeManagerWithPayoutAndFeeAmount(uint256 _payoutAmount, uint256 _feeSeed) public {
    vm.assume(_payoutAmount != 0);
    uint8 _fee = _getValidGlobalFee(_feeSeed);

    factoryOwner =
      new V3FeeManagerHarness(admin, factory, payoutToken, _payoutAmount, _fee, rewardReceiver);
    vm.label(address(factoryOwner), "Factory Owner");
  }
}

contract Constructor is V3FeeManagerTest {
  function testFuzz_SetsTheAdminPayoutTokenAndPayoutAmount(uint256 _payoutAmount) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    assertEq(factoryOwner.admin(), admin);
    assertEq(address(factoryOwner.FACTORY()), address(factory));
    assertEq(address(factoryOwner.PAYOUT_TOKEN()), address(payoutToken));
    assertEq(factoryOwner.payoutAmount(), _payoutAmount);
    assertEq(address(factoryOwner.REWARD_RECEIVER()), rewardReceiver);
  }

  function testFuzz_SetsAllParametersToArbitraryValues(
    address _admin,
    address _factory,
    address _payoutToken,
    uint256 _payoutAmount,
    uint256 _feeSeed,
    address _rewardReceiver
  ) public {
    vm.assume(_admin != address(0) && _payoutAmount != 0);
    uint8 _fee = _getValidGlobalFee(_feeSeed);
    V3FeeManagerHarness _factoryOwner = new V3FeeManagerHarness(
      _admin,
      IUniswapV3FactoryOwnerActions(_factory),
      IERC20(_payoutToken),
      _payoutAmount,
      _fee,
      address(_rewardReceiver)
    );
    assertEq(_factoryOwner.admin(), _admin);
    assertEq(address(_factoryOwner.FACTORY()), address(_factory));
    assertEq(address(_factoryOwner.PAYOUT_TOKEN()), address(_payoutToken));
    assertEq(_factoryOwner.payoutAmount(), _payoutAmount);
    assertEq(address(_factoryOwner.REWARD_RECEIVER()), _rewardReceiver);
    assertEq(_factoryOwner.globalProtocolFee(), _fee);
  }

  function testFuzz_EmitsAdminSetEvent(
    address _admin,
    address _factory,
    address _payoutToken,
    uint256 _payoutAmount,
    uint256 _feeSeed,
    address _rewardReceiver
  ) public {
    vm.assume(_admin != address(0) && _payoutAmount != 0);
    uint8 _fee = _getValidGlobalFee(_feeSeed);

    vm.expectEmit();
    emit V3FeeManager.AdminSet(address(0), _admin);
    new V3FeeManagerHarness(
      _admin,
      IUniswapV3FactoryOwnerActions(_factory),
      IERC20(_payoutToken),
      _payoutAmount,
      _fee,
      address(_rewardReceiver)
    );
  }

  function testFuzz_EmitsPayoutSetEvent(
    address _admin,
    address _factory,
    address _payoutToken,
    uint256 _payoutAmount,
    uint256 _feeSeed,
    address _rewardReceiver
  ) public {
    vm.assume(_admin != address(0) && _payoutAmount != 0);
    uint8 _fee = _getValidGlobalFee(_feeSeed);

    vm.expectEmit();
    emit V3FeeManager.PayoutAmountSet(0, _payoutAmount);
    new V3FeeManagerHarness(
      _admin,
      IUniswapV3FactoryOwnerActions(_factory),
      IERC20(_payoutToken),
      _payoutAmount,
      _fee,
      address(_rewardReceiver)
    );
  }

  function testFuzz_RevertIf_TheAdminIsAddressZero(
    address _factory,
    address _payoutToken,
    uint256 _payoutAmount,
    uint256 _feeSeed,
    address _rewardReceiver
  ) public {
    vm.assume(_payoutAmount != 0);
    uint8 _fee = _getValidGlobalFee(_feeSeed);

    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidAddress.selector);
    new V3FeeManagerHarness(
      address(0),
      IUniswapV3FactoryOwnerActions(_factory),
      IERC20(_payoutToken),
      _payoutAmount,
      _fee,
      address(_rewardReceiver)
    );
  }

  function testFuzz_RevertIf_ThePayoutAmountIsZero(
    address _admin,
    address _factory,
    address _payoutToken,
    uint256 _feeSeed,
    address _rewardReceiver
  ) public {
    vm.assume(_admin != address(0));
    uint8 _fee = _getValidGlobalFee(_feeSeed);

    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidPayoutAmount.selector);
    new V3FeeManagerHarness(
      _admin,
      IUniswapV3FactoryOwnerActions(_factory),
      IERC20(_payoutToken),
      0,
      _fee,
      address(_rewardReceiver)
    );
  }

  function testFuzz_RevertIf_FeeIsNotInTheValidRange(
    address _admin,
    address _factory,
    address _payoutToken,
    uint256 _payoutAmount,
    uint8 _fee,
    address _rewardReceiver
  ) public {
    vm.assume(_fee != 0 && (_fee < 4 || _fee > 10));
    vm.assume(_admin != address(0) && _payoutAmount != 0);

    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidGlobalProtocolFee.selector);
    new V3FeeManagerHarness(
      _admin,
      IUniswapV3FactoryOwnerActions(_factory),
      IERC20(_payoutToken),
      _payoutAmount,
      _fee,
      address(_rewardReceiver)
    );
  }
}

contract _SetAdmin is V3FeeManagerTest {
  function testFuzz_UpdatesTheAdmin(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));
    _deployFeeManagerWithPayoutAmount(1);

    factoryOwner.exposed_setAdmin(_newAdmin);

    assertEq(factoryOwner.admin(), _newAdmin);
  }

  function testFuzz_EmitsAnEventWhenUpdatingTheAdmin(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));
    _deployFeeManagerWithPayoutAmount(1);

    vm.expectEmit();
    emit V3FeeManager.AdminSet(admin, _newAdmin);
    factoryOwner.exposed_setAdmin(_newAdmin);
  }

  function test_RevertIf_TheNewAdminIsAddressZero() public {
    _deployFeeManagerWithPayoutAmount(1);

    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidAddress.selector);
    factoryOwner.exposed_setAdmin(address(0));
  }
}

contract SetAdmin is V3FeeManagerTest {
  function testFuzz_UpdatesTheAdminWhenCalledByTheCurrentAdmin(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));
    _deployFeeManagerWithPayoutAmount(1);

    vm.prank(admin);
    factoryOwner.setAdmin(_newAdmin);

    assertEq(factoryOwner.admin(), _newAdmin);
  }

  function testFuzz_EmitsAnEventWhenUpdatingTheAdmin(address _newAdmin) public {
    vm.assume(_newAdmin != address(0));
    _deployFeeManagerWithPayoutAmount(1);

    vm.expectEmit();
    vm.prank(admin);
    emit V3FeeManager.AdminSet(admin, _newAdmin);
    factoryOwner.setAdmin(_newAdmin);
  }

  function testFuzz_RevertIf_TheCallerIsNotTheCurrentAdmin(address _notAdmin, address _newAdmin)
    public
  {
    _deployFeeManagerWithPayoutAmount(1);

    vm.assume(_notAdmin != admin);

    vm.expectRevert(V3FeeManager.V3FeeManager__Unauthorized.selector);
    vm.prank(_notAdmin);
    factoryOwner.setAdmin(_newAdmin);
  }

  function test_RevertIf_TheNewAdminIsAddressZero() public {
    _deployFeeManagerWithPayoutAmount(1);

    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidAddress.selector);
    vm.prank(admin);
    factoryOwner.setAdmin(address(0));
  }
}

contract _SetPayoutAmount is V3FeeManagerTest {
  function testFuzz_UpdatesThePayoutAmount(uint256 _initialPayoutAmount, uint256 _newPayoutAmount)
    public
  {
    vm.assume(_newPayoutAmount != 0);
    _deployFeeManagerWithPayoutAmount(_initialPayoutAmount);

    factoryOwner.exposed_setPayoutAmount(_newPayoutAmount);

    assertEq(factoryOwner.payoutAmount(), _newPayoutAmount);
  }

  function testFuzz_EmitsAnEventWhenUpdatingThePayoutAmount(
    uint256 _initialPayoutAmount,
    uint256 _newPayoutAmount
  ) public {
    vm.assume(_newPayoutAmount != 0);
    _deployFeeManagerWithPayoutAmount(_initialPayoutAmount);

    vm.expectEmit();
    vm.prank(admin);
    emit V3FeeManager.PayoutAmountSet(_initialPayoutAmount, _newPayoutAmount);
    factoryOwner.exposed_setPayoutAmount(_newPayoutAmount);
  }

  function testFuzz_RevertIf_TheNewPayoutAmountIsZero(uint256 _initialPayoutAmount) public {
    _deployFeeManagerWithPayoutAmount(_initialPayoutAmount);

    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidPayoutAmount.selector);
    vm.prank(admin);
    factoryOwner.exposed_setPayoutAmount(0);
  }
}

contract SetPayoutAmount is V3FeeManagerTest {
  function testFuzz_UpdatesThePayoutAmountWhenCalledByAdmin(
    uint256 _initialPayoutAmount,
    uint256 _newPayoutAmount
  ) public {
    vm.assume(_newPayoutAmount != 0);
    _deployFeeManagerWithPayoutAmount(_initialPayoutAmount);

    vm.prank(admin);
    factoryOwner.setPayoutAmount(_newPayoutAmount);

    assertEq(factoryOwner.payoutAmount(), _newPayoutAmount);
  }

  function testFuzz_EmitsAnEventWhenUpdatingThePayoutAmount(
    uint256 _initialPayoutAmount,
    uint256 _newPayoutAmount
  ) public {
    vm.assume(_newPayoutAmount != 0);
    _deployFeeManagerWithPayoutAmount(_initialPayoutAmount);

    vm.expectEmit();
    vm.prank(admin);
    emit V3FeeManager.PayoutAmountSet(_initialPayoutAmount, _newPayoutAmount);
    factoryOwner.setPayoutAmount(_newPayoutAmount);
  }

  function testFuzz_RevertIf_TheCallerIsNotAdmin(
    uint256 _initialPayoutAmount,
    uint256 _newPayoutAmount,
    address _notAdmin
  ) public {
    vm.assume(_notAdmin != admin && _newPayoutAmount != 0);
    _deployFeeManagerWithPayoutAmount(_initialPayoutAmount);

    vm.expectRevert(V3FeeManager.V3FeeManager__Unauthorized.selector);
    vm.prank(_notAdmin);
    factoryOwner.setPayoutAmount(_newPayoutAmount);
  }

  function testFuzz_RevertIf_TheNewPayoutAmountIsZero(uint256 _initialPayoutAmount) public {
    _deployFeeManagerWithPayoutAmount(_initialPayoutAmount);

    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidPayoutAmount.selector);
    vm.prank(admin);
    factoryOwner.setPayoutAmount(0);
  }
}

contract _SetGlobalProtocolFee is V3FeeManagerTest {
  uint256 constant PAYOUT_AMOUNT = 1;

  function testFuzz_SetsTheGlobalProtocolFee(uint256 _initFeeSeed, uint256 _updatedFeeSeed) public {
    _deployFeeManagerWithPayoutAndFeeAmount(PAYOUT_AMOUNT, _initFeeSeed);

    uint8 _updatedFee = _getValidGlobalFee(_updatedFeeSeed);
    factoryOwner.exposed_setGlobalProtocolFee(_updatedFee);
    assertEq(factoryOwner.globalProtocolFee(), _updatedFee);
  }

  function testFuzz_EmitsGlobalProtocolFeeSetEvent(uint256 _initFeeSeed, uint256 _updatedFeeSeed)
    public
  {
    _deployFeeManagerWithPayoutAndFeeAmount(PAYOUT_AMOUNT, _initFeeSeed);

    uint8 _updatedFee = _getValidGlobalFee(_updatedFeeSeed);
    vm.expectEmit();
    emit V3FeeManager.GlobalProtocolFeeSet(factoryOwner.globalProtocolFee(), _updatedFee);
    factoryOwner.exposed_setGlobalProtocolFee(_updatedFee);
  }

  function testFuzz_RevertIf_FeeIsLow(uint256 _initFeeSeed, uint256 _updatedFeeSeed) public {
    _deployFeeManagerWithPayoutAndFeeAmount(PAYOUT_AMOUNT, _initFeeSeed);

    uint8 _updatedFee = uint8(bound(_updatedFeeSeed, 1, 3));
    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidGlobalProtocolFee.selector);
    factoryOwner.exposed_setGlobalProtocolFee(_updatedFee);
  }

  function testFuzz_RevertIf_FeeIsHigh(uint256 _initFeeSeed, uint256 _updatedFeeSeed) public {
    _deployFeeManagerWithPayoutAndFeeAmount(PAYOUT_AMOUNT, _initFeeSeed);

    uint8 _updatedFee = uint8(bound(_updatedFeeSeed, 11, type(uint8).max));
    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidGlobalProtocolFee.selector);
    factoryOwner.exposed_setGlobalProtocolFee(_updatedFee);
  }
}

contract SetGlobalProtocolFee is V3FeeManagerTest {
  uint256 constant PAYOUT_AMOUNT = 1;

  function testFuzz_SetsTheGlobalProtocolFee(uint256 _initFeeSeed, uint256 _updatedFeeSeed) public {
    _deployFeeManagerWithPayoutAndFeeAmount(PAYOUT_AMOUNT, _initFeeSeed);

    uint8 _updatedFee = _getValidGlobalFee(_updatedFeeSeed);

    vm.prank(admin);
    factoryOwner.setGlobalProtocolFee(_updatedFee);
    assertEq(factoryOwner.globalProtocolFee(), _updatedFee);
  }

  function testFuzz_EmitsGlobalProtocolFeeSetEvent(uint256 _initFeeSeed, uint256 _updatedFeeSeed)
    public
  {
    _deployFeeManagerWithPayoutAndFeeAmount(PAYOUT_AMOUNT, _initFeeSeed);

    uint8 _updatedFee = _getValidGlobalFee(_updatedFeeSeed);

    vm.expectEmit();
    emit V3FeeManager.GlobalProtocolFeeSet(factoryOwner.globalProtocolFee(), _updatedFee);
    vm.prank(admin);
    factoryOwner.setGlobalProtocolFee(_updatedFee);
  }

  function testFuzz_RevertIf_FeeIsLow(uint256 _initFeeSeed, uint256 _updatedFeeSeed) public {
    _deployFeeManagerWithPayoutAndFeeAmount(PAYOUT_AMOUNT, _initFeeSeed);

    uint8 _updatedFee = uint8(bound(_updatedFeeSeed, 1, 3));
    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidGlobalProtocolFee.selector);
    vm.prank(admin);
    factoryOwner.setGlobalProtocolFee(_updatedFee);
  }

  function testFuzz_RevertIf_FeeIsHigh(uint256 _initFeeSeed, uint256 _updatedFeeSeed) public {
    _deployFeeManagerWithPayoutAndFeeAmount(PAYOUT_AMOUNT, _initFeeSeed);

    uint8 _updatedFee = uint8(bound(_updatedFeeSeed, 11, type(uint8).max));
    vm.expectRevert(V3FeeManager.V3FeeManager__InvalidGlobalProtocolFee.selector);
    vm.prank(admin);
    factoryOwner.setGlobalProtocolFee(_updatedFee);
  }

  function testFuzz_RevertIf_CalledByNonAdmin(
    address _nonAdmin,
    uint256 _initFeeSeed,
    uint256 _updatedFeeSeed
  ) public {
    vm.assume(_nonAdmin != admin);
    _deployFeeManagerWithPayoutAndFeeAmount(PAYOUT_AMOUNT, _initFeeSeed);

    uint8 _updatedFee = _getValidGlobalFee(_updatedFeeSeed);

    vm.expectRevert(V3FeeManager.V3FeeManager__Unauthorized.selector);
    vm.prank(_nonAdmin);
    factoryOwner.setGlobalProtocolFee(_updatedFee);
  }
}

contract EnableFeeAmount is V3FeeManagerTest {
  function testFuzz_ForwardsParametersToTheEnableFeeAmountMethodOnTheFactory(
    uint24 _fee,
    int24 _tickSpacing
  ) public {
    _deployFeeManagerWithPayoutAmount(1);

    vm.prank(admin);
    factoryOwner.enableFeeAmount(_fee, _tickSpacing);

    assertEq(factory.lastParam__enableFeeAmount_fee(), _fee);
    assertEq(factory.lastParam__enableFeeAmount_tickSpacing(), _tickSpacing);
  }

  function testFuzz_RevertIf_TheCallerIsNotTheAdmin(
    address _notAdmin,
    uint24 _fee,
    int24 _tickSpacing
  ) public {
    _deployFeeManagerWithPayoutAmount(1);
    vm.assume(_notAdmin != admin);

    vm.expectRevert(V3FeeManager.V3FeeManager__Unauthorized.selector);
    vm.prank(_notAdmin);
    factoryOwner.enableFeeAmount(_fee, _tickSpacing);
  }
}

contract SetFeeProtocol is V3FeeManagerTest {
  function testFuzz_SetsPoolFeeProtocolsToGlobalFeeProtocol(uint256 _globalFeeSeed) public {
    uint8 _fee = _getValidGlobalFee(_globalFeeSeed);
    _deployFeeManagerWithPayoutAndFeeAmount(1, _fee);

    vm.prank(admin);
    factoryOwner.setFeeProtocol(pool);

    assertEq(pool.lastParam__setFeeProtocol_feeProtocol0(), _fee);
    assertEq(pool.lastParam__setFeeProtocol_feeProtocol1(), _fee);
  }

  function testFuzz_CanBeCalledByNonAdmin(address _notAdmin, uint256 _globalFeeSeed) public {
    uint8 _fee = _getValidGlobalFee(_globalFeeSeed);
    _deployFeeManagerWithPayoutAndFeeAmount(1, _fee);
    vm.assume(_notAdmin != admin);

    vm.prank(_notAdmin);
    factoryOwner.setFeeProtocol(pool);

    assertEq(pool.lastParam__setFeeProtocol_feeProtocol0(), _fee);
    assertEq(pool.lastParam__setFeeProtocol_feeProtocol1(), _fee);
  }

  function testFuzz_SetsMultiplePoolsFeeProtocolsToGlobalFeeProtocol(uint256 _globalFeeSeed) public {
    uint8 _fee = _getValidGlobalFee(_globalFeeSeed);
    _deployFeeManagerWithPayoutAndFeeAmount(1, _fee);

    IUniswapV3PoolOwnerActions[] memory _pools = new IUniswapV3PoolOwnerActions[](3);
    _pools[0] = IUniswapV3PoolOwnerActions(address(pool));
    _pools[1] = IUniswapV3PoolOwnerActions(address(pool2));
    _pools[2] = IUniswapV3PoolOwnerActions(address(pool3));

    // Protocol fees have not been set.
    assertEq(pool.lastParam__setFeeProtocol_feeProtocol0(), 0);
    assertEq(pool.lastParam__setFeeProtocol_feeProtocol1(), 0);
    assertEq(pool2.lastParam__setFeeProtocol_feeProtocol0(), 0);
    assertEq(pool2.lastParam__setFeeProtocol_feeProtocol1(), 0);
    assertEq(pool3.lastParam__setFeeProtocol_feeProtocol0(), 0);
    assertEq(pool3.lastParam__setFeeProtocol_feeProtocol1(), 0);

    factoryOwner.setFeeProtocol(_pools);

    assertEq(pool.lastParam__setFeeProtocol_feeProtocol0(), _fee);
    assertEq(pool.lastParam__setFeeProtocol_feeProtocol1(), _fee);
    assertEq(pool2.lastParam__setFeeProtocol_feeProtocol0(), _fee);
    assertEq(pool2.lastParam__setFeeProtocol_feeProtocol1(), _fee);
    assertEq(pool3.lastParam__setFeeProtocol_feeProtocol0(), _fee);
    assertEq(pool3.lastParam__setFeeProtocol_feeProtocol1(), _fee);
  }
}

contract ClaimFees is V3FeeManagerTest {
  function _buildClaimInputs(
    address _recipient,
    uint128 _amount0Requested,
    uint128 _amount1Requested
  ) internal view returns (V3FeeManager.ClaimInputData[] memory _inputs) {
    V3FeeManager.ClaimInputData memory _input = V3FeeManager.ClaimInputData({
      pool: pool,
      recipient: _recipient,
      amount0Requested: _amount0Requested,
      amount1Requested: _amount1Requested
    });
    _inputs = new V3FeeManager.ClaimInputData[](1);
    _inputs[0] = _input;
  }

  function testFuzz_TransfersThePayoutFromTheCallerToTheRewardReceiver(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0,
    uint128 _amount1
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.assume(_caller != address(0) && _recipient != address(0));
    payoutToken.mint(_caller, _payoutAmount);

    V3FeeManager.ClaimInputData[] memory _inputDataArray =
      _buildClaimInputs(_recipient, _amount0, _amount1);

    vm.startPrank(_caller);
    payoutToken.approve(address(factoryOwner), _payoutAmount);
    factoryOwner.claimFees(_inputDataArray);
    vm.stopPrank();

    assertEq(payoutToken.balanceOf(rewardReceiver), _payoutAmount);
  }

  function testFuzz_CallsPoolCollectProtocolMethodWithRecipientAndAmountsRequestedAndReturnsForwardedFeeAmountsFromPool(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0,
    uint128 _amount1
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.assume(_caller != address(0) && _recipient != address(0));
    payoutToken.mint(_caller, _payoutAmount);

    V3FeeManager.ClaimInputData[] memory _inputDataArray =
      _buildClaimInputs(_recipient, _amount0, _amount1);

    vm.startPrank(_caller);
    payoutToken.approve(address(factoryOwner), _payoutAmount);
    V3FeeManager.ClaimOutputData[] memory _claimOutputs = factoryOwner.claimFees(_inputDataArray);
    vm.stopPrank();

    V3FeeManager.ClaimOutputData memory _claimOutput = _claimOutputs[0];

    assertEq(pool.lastParam__collectProtocol_recipient(), _recipient);
    assertEq(pool.lastParam__collectProtocol_amount0Requested(), _amount0);
    assertEq(pool.lastParam__collectProtocol_amount1Requested(), _amount1);
    assertEq(_claimOutput.amount0, _amount0);
    assertEq(_claimOutput.amount1, _amount1);
  }

  function testFuzz_EmitsAnEventWithFeeClaimParameters(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0,
    uint128 _amount1
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.assume(_caller != address(0) && _recipient != address(0));
    payoutToken.mint(_caller, _payoutAmount);

    V3FeeManager.ClaimInputData[] memory _inputDataArray =
      _buildClaimInputs(_recipient, _amount0, _amount1);

    vm.startPrank(_caller);
    payoutToken.approve(address(factoryOwner), _payoutAmount);
    vm.expectEmit();
    emit V3FeeManager.FeesClaimed(address(pool), _caller, _recipient, _amount0, _amount1);
    factoryOwner.claimFees(_inputDataArray);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_CallerHasInsufficientBalanceOfPayoutToken(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0,
    uint128 _amount1,
    uint256 _mintAmount
  ) public {
    _payoutAmount = bound(_payoutAmount, 1, type(uint256).max);
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.assume(_caller != address(0) && _recipient != address(0));
    _mintAmount = bound(_mintAmount, 0, _payoutAmount - 1);
    payoutToken.mint(_caller, _mintAmount);

    vm.startPrank(_caller);
    payoutToken.approve(address(factoryOwner), _payoutAmount);

    V3FeeManager.ClaimInputData[] memory _inputDataArray =
      _buildClaimInputs(_recipient, _amount0, _amount1);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector, _caller, _mintAmount, _payoutAmount
      )
    );
    factoryOwner.claimFees(_inputDataArray);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_CallerHasInsufficientApprovalForPayoutToken(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0,
    uint128 _amount1,
    uint256 _approveAmount
  ) public {
    _payoutAmount = bound(_payoutAmount, 1, type(uint256).max);
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.assume(_caller != address(0) && _recipient != address(0));
    _approveAmount = bound(_approveAmount, 0, _payoutAmount - 1);
    payoutToken.mint(_caller, _payoutAmount);

    vm.startPrank(_caller);
    payoutToken.approve(address(factoryOwner), _approveAmount);

    V3FeeManager.ClaimInputData[] memory _inputDataArray =
      _buildClaimInputs(_recipient, _amount0, _amount1);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(factoryOwner),
        _approveAmount,
        _payoutAmount
      )
    );
    factoryOwner.claimFees(_inputDataArray);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_CallerExpectsMoreFeesThanPoolPaysOut(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0Requested,
    uint128 _amount1Requested,
    uint128 _amount0Collected,
    uint128 _amount1Collected
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);
    vm.assume(_caller != address(0) && _recipient != address(0));
    _amount0Requested = uint128(bound(_amount0Requested, 1, type(uint128).max));
    _amount1Requested = uint128(bound(_amount1Requested, 1, type(uint128).max));

    // sometimes get less amount0, other times get less amount1
    // uses arbitrary randomness via fuzzed _payoutAmount
    if (_payoutAmount % 2 == 0) {
      _amount0Collected = uint128(bound(_amount0Collected, 0, _amount0Requested - 1));
    } else {
      _amount1Collected = uint128(bound(_amount1Collected, 0, _amount1Requested - 1));
    }
    pool.setNextReturn__collectProtocol(_amount0Collected, _amount1Collected);

    payoutToken.mint(_caller, _payoutAmount);

    vm.startPrank(_caller);
    payoutToken.approve(address(factoryOwner), _payoutAmount);

    V3FeeManager.ClaimInputData[] memory _inputDataArray =
      _buildClaimInputs(_recipient, _amount0Requested, _amount1Requested);

    vm.expectRevert(V3FeeManager.V3FeeManager__InsufficientFeesCollected.selector);
    factoryOwner.claimFees(_inputDataArray);
    vm.stopPrank();
  }

  function testFuzz_TransfersPayoutForCollectingFeesFromMultiplePools(
    uint256 _payoutAmount,
    address _caller,
    address _recipientA,
    address _recipientB,
    uint128 _amount0,
    uint128 _amount1,
    uint128 _amount2,
    uint128 _amount3
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    _amount0 = uint128(bound(_amount0, 1, type(uint128).max));
    _amount1 = uint128(bound(_amount1, 1, type(uint128).max));
    _amount2 = uint128(bound(_amount2, 1, type(uint128).max));
    _amount3 = uint128(bound(_amount3, 1, type(uint128).max));

    vm.assume(
      _caller != address(0) && _caller != rewardReceiver && _recipientA != address(0)
        && _recipientB != address(0)
    );
    payoutToken.mint(_caller, _payoutAmount);

    V3FeeManager.ClaimInputData memory _inputA = V3FeeManager.ClaimInputData({
      pool: pool,
      recipient: _recipientA,
      amount0Requested: _amount0,
      amount1Requested: _amount1
    });
    V3FeeManager.ClaimInputData memory _inputB = V3FeeManager.ClaimInputData({
      pool: pool2,
      recipient: _recipientB,
      amount0Requested: _amount2,
      amount1Requested: _amount3
    });
    V3FeeManager.ClaimInputData[] memory _inputs = new V3FeeManager.ClaimInputData[](2);
    _inputs[0] = _inputA;
    _inputs[1] = _inputB;

    assertEq(payoutToken.balanceOf(rewardReceiver), 0);

    vm.startPrank(_caller);
    payoutToken.approve(address(factoryOwner), _payoutAmount);
    vm.expectEmit();
    emit V3FeeManager.FeesClaimed(address(pool), _caller, _recipientA, _amount0, _amount1);
    vm.expectEmit();
    emit V3FeeManager.FeesClaimed(address(pool2), _caller, _recipientB, _amount2, _amount3);
    factoryOwner.claimFees(_inputs);
    vm.stopPrank();

    assertEq(payoutToken.balanceOf(rewardReceiver), _payoutAmount);

    assertEq(pool.lastParam__collectProtocol_recipient(), _recipientA);
    assertEq(pool2.lastParam__collectProtocol_recipient(), _recipientB);
    assertEq(pool.lastParam__collectProtocol_amount0Requested(), _amount0);
    assertEq(pool.lastParam__collectProtocol_amount1Requested(), _amount1);
    assertEq(pool2.lastParam__collectProtocol_amount0Requested(), _amount2);
    assertEq(pool2.lastParam__collectProtocol_amount1Requested(), _amount3);
  }

  function testFuzz_RevertIf_OnePoolInMultiplePoolCallHasInsufficientFees(
    uint256 _payoutAmount,
    address _caller,
    address _recipientA,
    address _recipientB,
    uint128 _amount0,
    uint128 _amount1,
    uint128 _amount2,
    uint128 _amount3
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    _amount0 = uint128(bound(_amount0, 1, type(uint128).max));
    _amount1 = uint128(bound(_amount1, 1, type(uint128).max));
    _amount2 = uint128(bound(_amount2, 1, type(uint128).max));
    _amount3 = uint128(bound(_amount3, 1, type(uint128).max));

    vm.assume(
      _caller != address(0) && _caller != rewardReceiver && _recipientA != address(0)
        && _recipientB != address(0)
    );
    payoutToken.mint(_caller, _payoutAmount);

    V3FeeManager.ClaimInputData memory _inputA = V3FeeManager.ClaimInputData({
      pool: pool2,
      recipient: _recipientA,
      amount0Requested: _amount0,
      amount1Requested: _amount1
    });
    V3FeeManager.ClaimInputData memory _inputB = V3FeeManager.ClaimInputData({
      pool: pool3,
      recipient: _recipientB,
      amount0Requested: _amount2,
      amount1Requested: _amount3
    });
    V3FeeManager.ClaimInputData[] memory _inputs = new V3FeeManager.ClaimInputData[](2);
    _inputs[0] = _inputA;
    _inputs[1] = _inputB;

    // Randomize which payount amount on which pool is short.
    if (_payoutAmount % 2 == 0) {
      pool2.setNextReturn__collectProtocol(
        _amount0 % 2 == 0 ? _amount0 : _amount0 - 1, _amount0 % 2 == 1 ? _amount1 : _amount1 - 1
      );
    } else {
      pool3.setNextReturn__collectProtocol(
        _amount2 % 2 == 0 ? _amount2 : _amount2 - 1, _amount2 % 2 == 1 ? _amount3 : _amount3 - 1
      );
    }

    vm.startPrank(_caller);
    payoutToken.approve(address(factoryOwner), _payoutAmount);
    vm.expectRevert(V3FeeManager.V3FeeManager__InsufficientFeesCollected.selector);
    factoryOwner.claimFees(_inputs);
    vm.stopPrank();

    // Nothing was transferred or collected.
    assertEq(payoutToken.balanceOf(rewardReceiver), 0);
    assertEq(pool.lastParam__collectProtocol_recipient(), address(0));
    assertEq(pool2.lastParam__collectProtocol_recipient(), address(0));
    assertEq(pool.lastParam__collectProtocol_amount0Requested(), 0);
    assertEq(pool.lastParam__collectProtocol_amount1Requested(), 0);
    assertEq(pool2.lastParam__collectProtocol_amount0Requested(), 0);
    assertEq(pool2.lastParam__collectProtocol_amount1Requested(), 0);
  }
}

contract _ClaimFees is V3FeeManagerTest {
  function testFuzz_ReturnsFeesCollected(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0Requested,
    uint128 _amount1Requested,
    uint128 _amount0,
    uint128 _amount1
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.assume(_caller != address(0) && _caller != rewardReceiver && _recipient != address(0));

    V3FeeManager.ClaimInputData memory _input = V3FeeManager.ClaimInputData({
      pool: pool,
      recipient: _recipient,
      amount0Requested: _amount0Requested,
      amount1Requested: _amount1Requested
    });

    _amount0 = uint128(bound(_amount0, _amount0Requested, type(uint128).max));
    _amount1 = uint128(bound(_amount1, _amount1Requested, type(uint128).max));
    pool.setNextReturn__collectProtocol(_amount0, _amount1);

    vm.prank(_caller);
    V3FeeManager.ClaimOutputData memory _output = factoryOwner.exposed_claimFees(_input);
    vm.stopPrank();

    assertEq(address(_output.pool), address(pool));
    assertEq(_output.amount0, _amount0);
    assertEq(_output.amount1, _amount1);
  }

  function testFuzz_CollectsProtocolFee(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0Requested,
    uint128 _amount1Requested
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.assume(_caller != address(0) && _caller != rewardReceiver && _recipient != address(0));

    V3FeeManager.ClaimInputData memory _input = V3FeeManager.ClaimInputData({
      pool: pool,
      recipient: _recipient,
      amount0Requested: _amount0Requested,
      amount1Requested: _amount1Requested
    });

    vm.prank(_caller);
    factoryOwner.exposed_claimFees(_input);
    vm.stopPrank();

    assertEq(pool.lastParam__collectProtocol_recipient(), _recipient);
    assertEq(pool.lastParam__collectProtocol_amount0Requested(), _amount0Requested);
    assertEq(pool.lastParam__collectProtocol_amount1Requested(), _amount1Requested);
  }

  function testFuzz_EmitsFeesClaimedEvent(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0Requested,
    uint128 _amount1Requested,
    uint128 _amount0,
    uint128 _amount1
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.assume(_caller != address(0) && _caller != rewardReceiver && _recipient != address(0));

    V3FeeManager.ClaimInputData memory _input = V3FeeManager.ClaimInputData({
      pool: pool,
      recipient: _recipient,
      amount0Requested: _amount0Requested,
      amount1Requested: _amount1Requested
    });

    _amount0 = uint128(bound(_amount0, _amount0Requested, type(uint128).max));
    _amount1 = uint128(bound(_amount1, _amount1Requested, type(uint128).max));
    pool.setNextReturn__collectProtocol(_amount0, _amount1);

    vm.expectEmit();
    emit V3FeeManager.FeesClaimed(address(pool), _caller, _recipient, _amount0, _amount1);
    vm.prank(_caller);
    factoryOwner.exposed_claimFees(_input);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_InsufficientFeesAvailable(
    uint256 _payoutAmount,
    address _caller,
    address _recipient,
    uint128 _amount0Requested,
    uint128 _amount1Requested,
    uint128 _amount0,
    uint128 _amount1
  ) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.assume(_caller != address(0) && _caller != rewardReceiver && _recipient != address(0));

    _amount0Requested = uint128(bound(_amount0Requested, 1, type(uint128).max));
    _amount1Requested = uint128(bound(_amount1Requested, 1, type(uint128).max));

    V3FeeManager.ClaimInputData memory _input = V3FeeManager.ClaimInputData({
      pool: pool,
      recipient: _recipient,
      amount0Requested: _amount0Requested,
      amount1Requested: _amount1Requested
    });

    // Randomize which payout amount is too low.
    if (_payoutAmount % 2 == 0) _amount0 = uint128(bound(_amount0, 0, _amount0Requested - 1));
    else _amount1 = uint128(bound(_amount1, 0, _amount1Requested - 1));
    pool.setNextReturn__collectProtocol(_amount0, _amount1);

    vm.expectRevert(V3FeeManager.V3FeeManager__InsufficientFeesCollected.selector);
    vm.prank(_caller);
    factoryOwner.exposed_claimFees(_input);
    vm.stopPrank();
  }
}

contract _RevertIfNotAdmin is V3FeeManagerTest {
  function testFuzz_NoopIfCalledByAdmin(uint256 _payoutAmount) public {
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.prank(admin);
    factoryOwner.exposed_revertIfNotAdmin();
  }

  function testFuzz_RevertIf_CalledByNonAdmin(address _notAdmin, uint256 _payoutAmount) public {
    vm.assume(_notAdmin != admin);
    _deployFeeManagerWithPayoutAmount(_payoutAmount);

    vm.expectRevert(V3FeeManager.V3FeeManager__Unauthorized.selector);
    vm.prank(_notAdmin);
    factoryOwner.exposed_revertIfNotAdmin();
  }
}
