// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IUniswapV3Factory} from "briefcase/deployers/v3-core/UniswapV3FactoryDeployer.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {MainnetDeployer} from "../script/deployers/MainnetDeployer.sol";
import {ITokenJar} from "../src/interfaces/ITokenJar.sol";
import {IReleaser} from "../src/interfaces/IReleaser.sol";
import {IOwned} from "../src/interfaces/base/IOwned.sol";
import {IV3FeeAdapter} from "../src/interfaces/IV3FeeAdapter.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "./interfaces/IUniswapV2Pair.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {UnificationProposal} from "../script/04_UnificationProposal.s.sol";

contract ProtocolFeesForkTest is Test {
  using FixedPointMathLib for uint256;

  MainnetDeployer public deployer;
  IUniswapV3Factory public factory;
  IUniswapV2Factory public v2Factory;
  IUniswapV2Router02 public v2Router;

  ITokenJar public tokenJar;
  IReleaser public releaser;
  IV3FeeAdapter public feeAdapter;

  address public owner;
  Merkle merkle;
  address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
  address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

  // v3 pools
  address pool0; // USDC-WETH 1 bip pool
  address pool1; // USDC-WETH 5 bip pool
  address pool2; // USDC-WETH 30 bip pool
  address pool3; // USDC-WETH 1% pool

  // DAI-WETH pools
  address daiPool0; // DAI-WETH 1 bip pool
  address daiPool1; // DAI-WETH 5 bip pool
  address daiPool2; // DAI-WETH 30 bip pool
  address daiPool3; // DAI-WETH 1% pool

  // v2 pair: WETH / USDC
  IUniswapV2Pair pair;

  function setUp() public {
    vm.createSelectFork("mainnet");
    factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    v2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    v2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    owner = factory.owner();

    deployer = new MainnetDeployer();
    UnificationProposal proposal = new UnificationProposal();
    proposal.runPranked(deployer);
    tokenJar = deployer.TOKEN_JAR();
    releaser = deployer.RELEASER();
    feeAdapter = deployer.V3_FEE_ADAPTER();

    merkle = new Merkle();

    // USDC-WETH pools
    pool0 = factory.getPool(WETH, USDC, 100); // 1 bip pool
    pool1 = factory.getPool(WETH, USDC, 500); // 5 bip pool
    pool2 = factory.getPool(WETH, USDC, 3000); // 30 bip pool
    pool3 = factory.getPool(WETH, USDC, 10_000); // 1% pool

    // DAI-WETH pools
    daiPool0 = factory.getPool(DAI, WETH, 100); // 1 bip pool
    daiPool1 = factory.getPool(DAI, WETH, 500); // 5 bip pool
    daiPool2 = factory.getPool(DAI, WETH, 3000); // 30 bip pool
    daiPool3 = factory.getPool(DAI, WETH, 10_000); // 1% pool

    pair = IUniswapV2Pair(v2Factory.getPair(WETH, USDC));

    IERC20(USDC).approve(address(v2Router), type(uint256).max);
    IERC20(WETH).approve(address(v2Router), type(uint256).max);
  }

  function test_enableFeeV3() public {
    assertEq(feeAdapter.feeSetter(), owner);
    // Generate merkle root from leaves
    bytes32 targetLeaf = _hashLeaf(USDC, WETH);
    bytes32 dummyLeaf = _hashLeaf(address(0), address(1));
    bytes32[] memory leaves = new bytes32[](2);
    leaves[0] = targetLeaf;
    leaves[1] = dummyLeaf;
    bytes32 merkleRoot = merkle.getRoot(leaves);

    vm.prank(owner);
    feeAdapter.setMerkleRoot(merkleRoot);

    // Enable fees on the 4 pools
    bytes32[] memory proof = merkle.getProof(leaves, 0);
    feeAdapter.triggerFeeUpdate(USDC, WETH, proof);

    // fees were set correctly, from the Deployer.sol
    (,,,,, uint8 protocolFee,) = IUniswapV3Pool(pool0).slot0();
    assertEq(protocolFee, 4 << 4 | 4);
    (,,,,, protocolFee,) = IUniswapV3Pool(pool1).slot0();
    assertEq(protocolFee, 4 << 4 | 4);
    (,,,,, protocolFee,) = IUniswapV3Pool(pool2).slot0();
    assertEq(protocolFee, 6 << 4 | 6);
    (,,,,, protocolFee,) = IUniswapV3Pool(pool3).slot0();
    assertEq(protocolFee, 6 << 4 | 6);
  }

  function test_enableFeeV3MultiProof() public {
    assertEq(feeAdapter.feeSetter(), owner);

    // Using the real merkle root from the generated merkle tree
    bytes32 merkleRoot = 0x7023498b119180d3a2b889629918fd5d25c673bab9d12a89d854fbe7e48e39ea;

    vm.prank(owner);
    feeAdapter.setMerkleRoot(merkleRoot);

    // Setting up the pairs for USDC-WETH and DAI-WETH
    IV3FeeAdapter.Pair[] memory pairs = new IV3FeeAdapter.Pair[](2);
    pairs[0] = IV3FeeAdapter.Pair({token0: USDC, token1: WETH});
    pairs[1] = IV3FeeAdapter.Pair({token0: DAI, token1: WETH});

    // Multi-proof elements from the generated proof
    bytes32[] memory proof = new bytes32[](21);

    proof[0] = hex"6459eeadd691ace40c26c99e3dc443cf667837f2c70583f6a9814f53f9045c10";
    proof[1] = hex"72a5540451eb138c2bc018fd4d9387a60ffcc2b1c0c4c3e8c9e91e08d5f8be7d";
    proof[2] = hex"8f87bbfccd457f48222f5bf48efe4d7f72b0bff94b0bc627fcd0dc2f57b87f4f";
    proof[3] = hex"56fb05c35b6eef4eae8664c5a1ce16188cf91e531b6a6f6251d3ba9aaab7a8f3";
    proof[4] = hex"8be4614e8239bb83fc200b0c6c0e3089e065b976b516d3f5692a5a3ee6bf7cbc";
    proof[5] = hex"95ae26f69fcf3f5b567289cfc764f0ff614e1121645b8f9685088de0f5565405";
    proof[6] = hex"47f6f335bb88b0779472babfdf5fa35e5db52c24a41e16a4972c5a06edda8c50";
    proof[7] = hex"fea44e96bb9d2b7813a1efd6bd41b03af4aa6b5a24f53b2d38506f1edb7b9b77";
    proof[8] = hex"3c1c8b8f06e0094ae4d9d579136eb3967570d448102c0853db7d6c10593ea349";
    proof[9] = hex"cf19215466076d2c3b47813f49b03fa62dbc7e0c207ff6222daecc1e851dee3e";
    proof[10] = hex"e5e804bdb9b8b146bb5e80c6d7c3cf6e0a4775236b4e750e1c8ee9b72c07d370";
    proof[11] = hex"47d34b0552c7dd70656f33a82e6d41786f8285c56cf1277f989d9e5979ef6dd5";
    proof[12] = hex"02f9819011687dd6423f96c6746ddbe355d04902dbe89dd7076f900c8c2ed0c9";
    proof[13] = hex"73d8cb1800d3d1cb3f9acb880727840e50181c206756500fe1a3678592728b11";
    proof[14] = hex"ad9637d1f10c84147eb2c874a39aa57bbfabe6624d192e11f76e5a2f448d31b4";
    proof[15] = hex"a1010d2b2144559d8af9be4dc23a2438fd63764b459f17c91e1c73abdbc9422c";
    proof[16] = hex"4f78b2165924f01484a707c12576ba278ced969016532ed493079b15e39695d7";
    proof[17] = hex"80b0f46608bb87e8ade934f3234628534d7b925179b7d3a26b6893db9bda41d7";
    proof[18] = hex"80d4fbe20df7a885477651cbb27cc5c86eadf56a9bf7dace2366717fc63ff378";
    proof[19] = hex"b896c0845073c96cc05b282fd5e54b2143905e83dbf1fcde9667ee6c991a0e46";
    proof[20] = hex"41505af6416c28e0e97852b057364d7f7cbd4348da2b37ff7cb67d892d285cc5";

    // Proof flags from the generated proof
    bool[] memory proofFlags = new bool[](22);
    // All false except index 18
    for (uint256 i = 0; i < 22; i++) {
      proofFlags[i] = (i == 18);
    }

    // Enable fees on the pools
    feeAdapter.batchTriggerFeeUpdate(pairs, proof, proofFlags);

    // Verify fees were set correctly for USDC-WETH pools
    (,,,,, uint8 protocolFee,) = IUniswapV3Pool(pool0).slot0();
    assertEq(protocolFee, 4 << 4 | 4);
    (,,,,, protocolFee,) = IUniswapV3Pool(pool1).slot0();
    assertEq(protocolFee, 4 << 4 | 4);
    (,,,,, protocolFee,) = IUniswapV3Pool(pool2).slot0();
    assertEq(protocolFee, 6 << 4 | 6);
    (,,,,, protocolFee,) = IUniswapV3Pool(pool3).slot0();
    assertEq(protocolFee, 6 << 4 | 6);

    // Verify fees were set correctly for DAI-WETH pools
    (,,,,, protocolFee,) = IUniswapV3Pool(daiPool0).slot0();
    assertEq(protocolFee, 4 << 4 | 4);
    (,,,,, protocolFee,) = IUniswapV3Pool(daiPool1).slot0();
    assertEq(protocolFee, 4 << 4 | 4);
    (,,,,, protocolFee,) = IUniswapV3Pool(daiPool2).slot0();
    assertEq(protocolFee, 6 << 4 | 6);
    (,,,,, protocolFee,) = IUniswapV3Pool(daiPool3).slot0();
    assertEq(protocolFee, 6 << 4 | 6);
  }

  function test_enableFeeV2() public {
    assertEq(v2Factory.feeToSetter(), owner);
    vm.prank(owner);
    v2Factory.setFeeTo(address(tokenJar));
    assertEq(v2Factory.feeTo(), address(tokenJar));
  }

  function test_createV2Fees() public {
    test_enableFeeV2();

    // add liquidity
    deal(USDC, address(this), 1_000_000e6);
    deal(WETH, address(this), 1000e18);
    (,, uint256 liquidity) =
      v2Router.addLiquidity(USDC, WETH, 1_000_000e6, 100e18, 0, 0, address(this), block.timestamp);
    assertEq(pair.balanceOf(address(this)), liquidity);

    deal(USDC, address(this), 1000e6);
    _exactInSwapV2(pair, true, 1000e6);

    deal(WETH, address(this), 10e18);
    _exactInSwapV2(pair, false, 10e18);

    // collect fees by withdrawing liquidity
    pair.approve(address(v2Router), liquidity);
    v2Router.removeLiquidity(
      USDC, WETH, pair.balanceOf(address(this)), 0, 0, address(this), block.timestamp
    );

    // some liquidity is sent to the token jar
    assertGt(pair.balanceOf(address(tokenJar)), 0);
  }

  function test_collectFeeV3() public {
    test_enableFeeV3();

    // swap on the 5 bip pool
    deal(USDC, address(this), 3000e6);
    _exactInSwapV3(pool1, true, 1000e6);
    deal(WETH, address(this), 3e18);
    _exactInSwapV3(pool1, false, 1e18);

    (uint128 token0Pool1, uint128 token1Pool1) = IUniswapV3Pool(pool1).protocolFees();
    assertApproxEqRel(token0Pool1, uint256(1000e6).mulWadDown(0.0005e18) / 4, 0.0001e18);
    assertApproxEqRel(token1Pool1, uint256(1e18).mulWadDown(0.0005e18) / 4, 0.0001e18);

    // swap on 30 bip pool
    _exactInSwapV3(pool2, true, 1000e6);
    _exactInSwapV3(pool2, false, 1e18);
    (uint128 token0Pool2, uint128 token1Pool2) = IUniswapV3Pool(pool2).protocolFees();
    assertApproxEqRel(token0Pool2, uint256(1000e6).mulWadDown(0.003e18) / 6, 0.0001e18);
    assertApproxEqRel(token1Pool2, uint256(1e18).mulWadDown(0.003e18) / 6, 0.0001e18);

    // swap on 1% pool
    _exactInSwapV3(pool3, true, 1000e6);
    _exactInSwapV3(pool3, false, 1e18);
    (uint128 token0Pool3, uint128 token1Pool3) = IUniswapV3Pool(pool3).protocolFees();
    assertApproxEqRel(token0Pool3, uint256(1000e6).mulWadDown(0.01e18) / 6, 0.0001e18);
    assertApproxEqRel(token1Pool3, uint256(1e18).mulWadDown(0.01e18) / 6, 0.0001e18);

    IV3FeeAdapter.CollectParams[] memory params = new IV3FeeAdapter.CollectParams[](3);
    params[0] = IV3FeeAdapter.CollectParams({
      pool: pool1, amount0Requested: type(uint128).max, amount1Requested: type(uint128).max
    });
    params[1] = IV3FeeAdapter.CollectParams({
      pool: pool2, amount0Requested: type(uint128).max, amount1Requested: type(uint128).max
    });
    params[2] = IV3FeeAdapter.CollectParams({
      pool: pool3, amount0Requested: type(uint128).max, amount1Requested: type(uint128).max
    });

    // token jar has no tokens
    assertEq(IERC20(USDC).balanceOf(address(tokenJar)), 0);
    assertEq(IERC20(WETH).balanceOf(address(tokenJar)), 0);
    feeAdapter.collect(params);

    // token jar has collected all fees
    // subtract 3 wei because the v3 pool always leaves 1 wei behind
    assertEq(
      IERC20(USDC).balanceOf(address(tokenJar)), token0Pool1 + token0Pool2 + token0Pool3 - 3 wei
    );
    assertEq(
      IERC20(WETH).balanceOf(address(tokenJar)), token1Pool1 + token1Pool2 + token1Pool3 - 3 wei
    );
  }

  function test_releaseV3(address caller, address recipient) public {
    vm.assume(caller != address(0));
    vm.assume(recipient != address(0) && recipient != address(tokenJar) && recipient != USDC);
    test_collectFeeV3();

    // give the caller some UNI to burn
    deal(deployer.RESOURCE(), address(caller), releaser.threshold());
    assertEq(IERC20(deployer.RESOURCE()).balanceOf(address(caller)), releaser.threshold());

    uint256 balance0Before = IERC20(USDC).balanceOf(recipient);
    uint256 balance1Before = IERC20(WETH).balanceOf(recipient);

    uint256 balance0TokenJarBefore = IERC20(USDC).balanceOf(address(tokenJar));
    uint256 balance1TokenJarBefore = IERC20(WETH).balanceOf(address(tokenJar));

    // release the assets
    uint256 _nonce = releaser.nonce();
    Currency[] memory currencies = new Currency[](2);
    currencies[0] = Currency.wrap(USDC);
    currencies[1] = Currency.wrap(WETH);

    vm.startPrank(caller);
    IERC20(deployer.RESOURCE()).approve(address(releaser), releaser.threshold());
    releaser.release(_nonce, currencies, recipient);
    vm.stopPrank();

    // amounts transferred from the token jar to the recipient
    assertEq(IERC20(USDC).balanceOf(address(tokenJar)), 0);
    assertEq(IERC20(WETH).balanceOf(address(tokenJar)), 0);
    assertEq(IERC20(USDC).balanceOf(recipient) - balance0Before, balance0TokenJarBefore);
    assertEq(IERC20(WETH).balanceOf(recipient) - balance1Before, balance1TokenJarBefore);
  }

  function test_releaseV2V3(address caller, address recipient) public {
    vm.assume(caller != address(0));
    vm.assume(recipient != address(0) && recipient != address(tokenJar) && recipient != USDC);
    test_createV2Fees();
    test_collectFeeV3();

    uint256 pairBalanceBefore = pair.balanceOf(address(tokenJar));

    // give the caller some UNI to burn
    deal(deployer.RESOURCE(), address(caller), releaser.threshold());
    assertEq(IERC20(deployer.RESOURCE()).balanceOf(address(caller)), releaser.threshold());

    // release the assets
    uint256 _nonce = releaser.nonce();
    Currency[] memory currencies = new Currency[](3);
    currencies[0] = Currency.wrap(USDC);
    currencies[1] = Currency.wrap(WETH);
    currencies[2] = Currency.wrap(address(pair));

    vm.startPrank(caller);
    IERC20(deployer.RESOURCE()).approve(address(releaser), releaser.threshold());
    releaser.release(_nonce, currencies, recipient);
    vm.stopPrank();

    // amounts transferred from the token jar to the recipient
    assertEq(IERC20(USDC).balanceOf(address(tokenJar)), 0);
    assertEq(IERC20(WETH).balanceOf(address(tokenJar)), 0);
    assertEq(pair.balanceOf(address(tokenJar)), 0);
    assertEq(pair.balanceOf(recipient), pairBalanceBefore);
  }

  /// @dev ensure v3 factory owner is recoverable
  function test_undo_v3(address newOwner) public {
    test_releaseV2V3(address(this), address(this));

    vm.prank(owner);
    feeAdapter.setFactoryOwner(newOwner);

    assertEq(IOwned(address(factory)).owner(), newOwner);
  }

  /// @dev ensures v2 factory feeTo is recoverable
  function test_undo_v2(address newFeeTo) public {
    test_releaseV2V3(address(this), address(this));

    vm.prank(owner);
    v2Factory.setFeeTo(newFeeTo);
    assertEq(v2Factory.feeTo(), newFeeTo);
  }

  // --- Helpers ---

  function _hashLeaf(address token0, address token1) internal pure returns (bytes32) {
    return keccak256(abi.encode(keccak256(abi.encode(token0, token1))));
  }

  function _exactInSwapV3(address pool, bool zeroForOne, uint256 amountIn) internal {
    IUniswapV3Pool(pool)
      .swap(
        address(this),
        zeroForOne,
        int256(amountIn),
        // constants grabbed from v3-core TickMath, pasted here to avoid type conversion in new
        // solidity version
        zeroForOne
          ? 4_295_128_739 + 1
          : 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342 - 1,
        abi.encode(address(this)) // encode the payer
      );
  }

  function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data)
    external
  {
    address user = abi.decode(data, (address));
    if (amount0Delta > 0) {
      IERC20 token = IERC20(IUniswapV3Pool(msg.sender).token0());
      vm.prank(user);
      token.approve(address(this), uint256(amount0Delta));
      token.transferFrom(user, msg.sender, uint256(amount0Delta));
    } else if (amount1Delta > 0) {
      IERC20 token = IERC20(IUniswapV3Pool(msg.sender).token1());
      vm.prank(user);
      token.approve(address(this), uint256(amount1Delta));
      token.transferFrom(user, msg.sender, uint256(amount1Delta));
    }
  }

  function _exactInSwapV2(IUniswapV2Pair _pair, bool zeroForOne, uint256 amountIn) internal {
    address[] memory path = new address[](2);
    path[0] = zeroForOne ? _pair.token0() : _pair.token1();
    path[1] = zeroForOne ? _pair.token1() : _pair.token0();
    v2Router.swapExactTokensForTokens(amountIn, 0, path, address(this), block.timestamp);
  }
}

// interface for:
// https://etherscan.io/address/0x18e433c7Bf8A2E1d0197CE5d8f9AFAda1A771360#code
// the current v2Factory.feeToSetter()
interface IFeeToSetter {
  function setFeeToSetter(address) external;
}
