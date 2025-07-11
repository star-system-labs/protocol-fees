# Uniswap Fee Collection

*A unified system for collecting and converting fees from arbitrary revenue sources on arbitrary chains.*

## Overview

Uniswap Fee Collection is a maximally fault-tolerant system designed to collect fees from any revenue source on any blockchain and convert them efficiently. The system uses competitive economic incentives to ensure timely fee collection while maintaining decentralized governance through immutable smart contracts.

## Goals

- **Universal Support**: Collect fees from arbitrary revenue sources across arbitrary chains
- **Maximum Fault Tolerance**: Recover from chain downtime, bridge failures, and other infrastructure issues
- **Immutable Governance**: Configuration controlled by immutable smart contracts on Unichain
- **Economic Efficiency**: Competitive mechanisms ensure optimal fee collection and conversion

## Architecture

The Uniswap system consists of three core layers that work together across all supported chains:

### 1. Asset Sink

Each chain deploys a local **Asset Sink** - an immutable smart contract that serves as the collection point for all fees on that chain.

```
Fee Sources → Asset Sink → Releaser → Fee Conversion
```

**Key Properties:**

- **Immutable**: No admin functions, cannot be upgraded
- **Universal Collector**: Receives fees from all sources on the chain
- **Single Admin**: Only the `releaser` can withdraw assets
- **Atomic Operations**: Full balance transfers only

The Asset Sink defines one role: the `releaser`, which can atomically transfer the full balance of specified assets to a recipient address.

### 2. Fee Sources

Fee Sources are adapter contracts that channel fees from various protocols into the local Asset Sink. They handle the diversity of fee collection mechanisms across different protocols.

#### Push vs Pull Models

**Push Sources** (e.g., Uniswap V2):

- Fees automatically flow to Asset Sink
- Direct integration with protocol fee recipients
- Minimal ongoing maintenance

**Pull Sources** (e.g., Uniswap V3/V4):

- Require explicit collection calls
- Adapter contracts enable permissionless collection
- Anyone can trigger fee collection to Asset Sink

#### Supported Protocols

**Uniswap V2**

- LP tokens minted directly to Asset Sink
- 1/6 of swap fees collected as protocol revenue
- Zero additional infrastructure required

**Uniswap V3**

- V3FeeManager contract owns factory privileges
- Permissionless protocol fee collection
- Configurable fee rates per pool

**Uniswap V4**

- V4FeeSource as ProtocolFeeController
- Hooks-based fee collection
- Next-generation fee management

### 3. Releasers

Releasers are smart contracts that serve as the `releaser` for Asset Sinks. They implement the business logic for converting collected fees into protocol value.

#### UNI Burn (Mainnet)

On Ethereum mainnet where UNI tokens exist:

```
Searcher → Pay UNI → Releaser → Release Assets → Burn UNI
```

**Mechanism:**

1. Searcher pays fixed UNI amount to Releaser
2. Releaser releases Asset Sink contents to searcher
3. UNI tokens are burned, reducing total supply
4. Searcher profits from asset value exceeding UNI burn cost

#### Cross-Chain UNI Burn

For chains without native UNI:

```
Searcher → Burn UNI (Mainnet) → Bridge Message → Release Assets (Spoke)
```

**Mechanism:**

1. Searcher burns UNI on Ethereum mainnet
2. Cross-chain message triggers asset release on spoke chain
3. Monotonic nonce ensures strict ordering
4. Bundled multicalls optimize gas efficiency

## Economic Incentives

The system relies on economic competition to ensure efficient operation:

- **Profit Motive**: Searchers compete when asset value exceeds burn costs
- **Automatic Timing**: No manual intervention required
- **Gas Optimization**: Bundled operations reduce transaction costs
- **MEV Resistance**: Fixed burn amounts prevent extraction

## Fault Tolerance

Uniswap is designed to handle infrastructure failures gracefully:

- **Bridge Failures**: Each chain operates independently
- **Chain Downtime**: Fees accumulate until chain recovery
- **Governance Issues**: Immutable contracts prevent admin capture
- **Oracle Failures**: Economic incentives work without price feeds

## Implementation Status

This repository contains the initial implementation focusing on Uniswap V3 fee collection:

- **ERC20FeeCollector**: Prototype releaser with payout race mechanism
- **V3FeeManager**: Uniswap V3 fee source implementation
- **Comprehensive Tests**: 77 tests with fuzz testing coverage

## Deployment Architecture

```
Unichain (Config Chain)
├── Protocol Configuration
└── Cross-chain Governance

Ethereum Mainnet
├── Asset Sink
├── UNI Burn Releaser
├── V2 Fee Source (feeTo)
├── V3 Fee Source (V3FeeManager)
└── V4 Fee Source (V4FeeManager)

L2 Chains (Arbitrum, Optimism, Base, etc.)
├── Asset Sink
├── Cross-chain Releaser
├── V2 Fee Source (feeTo)
├── V3 Fee Source (V3FeeManager)
└── V4 Fee Source (V4FeeManager)
```

## Development

### Prerequisites

- [Foundry](https://getfoundry.sh/) - Ethereum development toolkit
- [Node.js](https://nodejs.org/) - For additional tooling

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd fee-collection

# Install dependencies
forge install

# Build contracts
forge build
```

### Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Generate coverage
forge coverage
```

### Project Structure

```
src/
├── AssetSink.sol             # Immutable fee collection contract
├── releasers/
│   ├── UNIBurnReleaser.sol   # Mainnet UNI burn mechanism
│   └── XChainReleaser.sol    # Cross-chain release mechanism
├── sources/
│   ├── V2FeeSource.sol       # Uniswap V2 fee integration
│   ├── V3FeeSource.sol       # Uniswap V3 fee management
│   └── V4FeeSource.sol       # Uniswap V4 fee hooks
└── interfaces/               # Contract interfaces

test/
├── integration/              # Cross-chain integration tests
├── unit/                     # Individual contract tests
└── fuzz/                     # Property-based testing
```

## Security

- **Immutable Core**: Asset Sinks cannot be upgraded or compromised
- **Economic Security**: Competitive incentives prevent manipulation
- **Comprehensive Testing**: Extensive test coverage including edge cases
- **Formal Verification**: Critical paths formally verified
- **Multi-chain Audits**: Security reviews across all deployment chains

## Future Development

### Protocol Fee Auctions

Advanced mechanism design for optimizing fee collection efficiency through auction-based competition.

### Additional Protocol Support

- UniswapX fee integration
- Interface fee collection
- Third-party protocol adapters

### Cross-chain Expansion

- Additional L2 and L1 chain support
- Alternative bridge integrations
- Rollup-specific optimizations

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with comprehensive tests
4. Submit a pull request

## License

This project is licensed under AGPL-3.0-only.

## Support

For questions or issues, please open an issue in the repository.

