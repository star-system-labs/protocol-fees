// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {ERC20FeeCollector} from "src/ERC20FeeCollector.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IUniswapV2Factory} from "test/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router} from "test/interfaces/IUniswapV2Router.sol";
import {IFeeToSetter} from "test/interfaces/IFeeToSetter.sol";

contract ERC20FeeCollectorIntegrationTest is Test {
  ERC20FeeCollector public feeCollector;

  address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address public constant UNISWAP_TIMELOCK = 0x1a9C8182C09F50C8318d769245beA52c32BE35BC;

  IUniswapV2Factory public constant FACTORY =
    IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
  IUniswapV2Router public constant ROUTER =
    IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  IFeeToSetter public constant FEE_TO_SETTER =
    IFeeToSetter(0x18e433c7Bf8A2E1d0197CE5d8f9AFAda1A771360);

  address public rewardReceiver = makeAddr("reward receiver");
  uint256 public payoutAmount = 1e18;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("mainnet"), 22_496_986);

    feeCollector = new ERC20FeeCollector(rewardReceiver, WETH, payoutAmount);

    // Set up fee collection through governance
    vm.startPrank(UNISWAP_TIMELOCK);
    FEE_TO_SETTER.setFeeToSetter(UNISWAP_TIMELOCK);
    FACTORY.setFeeTo(address(feeCollector));
    FACTORY.setFeeToSetter(address(0));
    vm.stopPrank();
  }

  function testFork_VerifyV2FeeCollectionIsSetupCorrectly() public view {
    assertEq(FACTORY.feeToSetter(), address(0));
    assertEq(FACTORY.feeTo(), address(feeCollector));
  }

  function testForkFuzz_ClaimAccumulatedFees(
    uint256 _wethAmount,
    uint256 _usdcAmount,
    uint256 _swapAmount
  ) public {
    _wethAmount = bound(_wethAmount, 10e18, 1000e18);
    _usdcAmount = bound(_usdcAmount, 10_000e6, 1_000_000e6);
    _swapAmount = bound(_swapAmount, 1e18, 50e18);

    address liquidityProvider = makeAddr("LP Provider");
    address swapper = makeAddr("Swapper");
    address claimer = makeAddr("Fee Claimer");
    address recipient = makeAddr("Fee Recipient");

    address pair = FACTORY.getPair(WETH, USDC);

    // Setup tokens
    deal(WETH, liquidityProvider, _wethAmount * 2);
    deal(USDC, liquidityProvider, _usdcAmount * 2);
    deal(WETH, swapper, _swapAmount);
    deal(WETH, claimer, payoutAmount);

    // Add initial liquidity
    vm.startPrank(liquidityProvider);
    IERC20(WETH).approve(address(ROUTER), _wethAmount);
    IERC20(USDC).approve(address(ROUTER), _usdcAmount);
    ROUTER.addLiquidity(
      WETH, USDC, _wethAmount, _usdcAmount, 0, 0, liquidityProvider, block.timestamp
    );
    vm.stopPrank();

    // Perform swap to generate fees
    vm.startPrank(swapper);
    IERC20(WETH).approve(address(ROUTER), _swapAmount);
    address[] memory path = new address[](2);
    path[0] = WETH;
    path[1] = USDC;
    ROUTER.swapExactTokensForTokens(_swapAmount, 0, path, swapper, block.timestamp);
    vm.stopPrank();

    // Add more liquidity to trigger fee distribution
    vm.startPrank(liquidityProvider);
    IERC20(WETH).approve(address(ROUTER), _wethAmount);
    IERC20(USDC).approve(address(ROUTER), _usdcAmount);
    ROUTER.addLiquidity(
      WETH, USDC, _wethAmount, _usdcAmount, 0, 0, liquidityProvider, block.timestamp
    );
    vm.stopPrank();

    // Check fees accumulated
    uint256 tokenBalance = IERC20(pair).balanceOf(address(feeCollector));

    // Claim the fees
    vm.startPrank(claimer);
    IERC20(WETH).approve(address(feeCollector), payoutAmount);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](1);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(pair),
      feeRecipient: recipient,
      amountRequested: tokenBalance
    });

    uint256 rewardReceiverBalanceBefore = IERC20(WETH).balanceOf(rewardReceiver);
    uint256 recipientBalanceBefore = IERC20(pair).balanceOf(recipient);

    feeCollector.claimFees(claims);
    vm.stopPrank();

    // Verify claim worked
    assertEq(IERC20(WETH).balanceOf(rewardReceiver), rewardReceiverBalanceBefore + payoutAmount);
    assertEq(IERC20(pair).balanceOf(recipient), recipientBalanceBefore + tokenBalance);
    assertEq(IERC20(pair).balanceOf(address(feeCollector)), 0);
  }

  function testForkFuzz_RevertWhen_ClaimFeesOnInsufficientBalance(uint256 _amountRequested) public {
    _amountRequested = bound(_amountRequested, 1e18, 10_000e18);

    address claimer = makeAddr("Fee Claimer");
    address recipient = makeAddr("Fee Recipient");
    address pair = FACTORY.getPair(WETH, USDC);

    deal(WETH, claimer, payoutAmount);

    vm.startPrank(claimer);
    IERC20(WETH).approve(address(feeCollector), payoutAmount);

    ERC20FeeCollector.ClaimInputData[] memory claims = new ERC20FeeCollector.ClaimInputData[](1);
    claims[0] = ERC20FeeCollector.ClaimInputData({
      token: IERC20(pair),
      feeRecipient: recipient,
      amountRequested: _amountRequested
    });

    vm.expectRevert("ds-math-sub-underflow");

    feeCollector.claimFees(claims);
    vm.stopPrank();
  }
}
