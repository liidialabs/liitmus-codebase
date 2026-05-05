# Aave V3 Integration Templates

Smart contract templates and interfaces for integrating Aave V3 lending protocol into applications. This directory provides ready-to-use building blocks that can be adapted to any project context.

---

## Directory Structure

```
aavev3/
├── README.md                    # This file
├── Constants.sol                # Contract addresses for all supported chains
├── interface/                   # Aave V3 contract interfaces
│   ├── IPool.sol                # Main Pool interface (supply, borrow, etc.)
│   ├── IPoolAddressesProvider.sol # Central address registry
│   ├── IPoolDataProvider.sol    # View functions for reserve/user data
│   ├── IPriceOracle.sol         # Price feed interface
│   ├── IAToken.sol              # aToken (supply position) interface
│   └── IVariableDebtToken.sol   # Variable debt token interface
├── usage/                       # Example contracts for each operation
│   ├── AaveV3Base.sol           # Base contract with common functionality
│   ├── Supply.sol               # Supply/deposit assets
│   ├── Withdraw.sol             # Withdraw supplied assets
│   ├── Borrow.sol               # Borrow against collateral
│   ├── Repay.sol                # Repay borrowed debt
│   ├── Liquidate.sol            # Liquidate underwater positions
│   └── FlashLoan.sol            # Execute flash loans
└── guides/
    └── integration_check.md     # Comprehensive integration guide
```

---

## Quick Start

### 1. Copy Required Files

Copy the `interface/` and `usage/` directories into your project. Adjust import paths as needed.

### 2. Configure Addresses

Update `Constants.sol` with the correct addresses for your target chain, or import the `AaveV3Addresses` library:

```solidity
import {AaveV3Addresses} from "./aavev3/Constants.sol";

// Use addresses for your chain
address pool = AaveV3Addresses.ARBITRUM_POOL;
address oracle = AaveV3Addresses.ARBITRUM_ORACLE;
```

### 3. Use the Templates

Each contract in `usage/` demonstrates a specific Aave V3 operation. Import and extend them:

```solidity
import {Supply} from "./aavev3/usage/Supply.sol";
import {Borrow} from "./aavev3/usage/Borrow.sol";

contract MyStrategy is Supply, Borrow {
    constructor(address provider, address oracle)
        Supply(provider)
        Borrow(provider, oracle)
    {}
}
```

---

## Supported Chains

| Chain | Pool Address |
|-------|-------------|
| Ethereum Mainnet | `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2` |
| Arbitrum | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` |
| Optimism | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` |
| Polygon | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` |
| Base | `0x8145c09465f0a8Dcf185eAA21dC941F0eA651F0e` |
| Avalanche | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` |
| Sepolia (testnet) | `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2` |

---

## Core Operations

| Operation | Contract | Description |
|-----------|----------|-------------|
| Supply | `Supply.sol` | Deposit assets to earn interest |
| Withdraw | `Withdraw.sol` | Withdraw supplied assets + interest |
| Borrow | `Borrow.sol` | Borrow against collateral |
| Repay | `Repay.sol` | Repay borrowed debt |
| Liquidate | `Liquidate.sol` | Liquidate underwater positions |
| Flash Loan | `FlashLoan.sol` | Borrow without collateral (same-tx repayment) |

---

## Key Concepts

### Health Factor
- Must stay above 1.0 to avoid liquidation
- Calculated as `(collateral × liquidation threshold) / debt`
- Monitor with `pool.getUserAccountData()`

### Interest Rate Modes
- **Stable (1)**: Fixed rate, limited to 25% of reserve
- **Variable (2)**: Rate fluctuates with market conditions

### aTokens
- Represent supply positions
- Balance grows automatically with accrued interest
- Can be transferred or used in other DeFi protocols

### E-Mode
- Efficiency mode for correlated assets (e.g., stablecoins)
- Provides higher LTV (up to 97%)
- Enabled via `pool.setUserEMode(categoryId)`

---

## Resources

- [Integration Guide](guides/integration_check.md) - Comprehensive setup and usage instructions
- [Aave V3 Docs](https://docs.aave.com/developers/) - Official documentation
- [Aave V3 Core](https://github.com/aave/aave-v3-core) - Source code
- [Deployed Contracts](https://docs.aave.com/developers/deployed-contracts/v3-mainnet) - Latest addresses
