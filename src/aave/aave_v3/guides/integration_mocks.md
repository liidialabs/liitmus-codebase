# Aave V3 Integration Mocks Guide

This guide explains how to set up Aave V3 mock contracts for testing protocols that interact with Aave V3. It is designed to be followed by an LLM during the testing phase of an Aave V3 integration.

**Prerequisite**: Complete the integration steps in `integration_check.md` before setting up mocks.

---

## 1. Required Mock Contracts

The following mock contracts are available in `aave/aave_v3/mocks/`:

| Mock | File | Purpose |
|------|------|---------|
| `MockAaveV3Pool` | `aave/aave_v3/mocks/MockAaveV3Pool.sol` | Simulates the Aave V3 Pool — supply, borrow, withdraw, repay, liquidate, flash loans |
| `MockAaveV3Oracle` | `aave/aave_v3/mocks/MockAaveV3Oracle.sol` | Simulates the price oracle — configurable asset prices |
| `MockPoolDataProvider` | `aave/aave_v3/mocks/MockPoolDataProvider.sol` | Simulates pool data provider — configurable reserve configurations |

Token mocks are available in `src/mocks/`:

| Mock | File | Purpose |
|------|------|---------|
| `MockERC20` | `src/mocks/MockERC20.sol` | Generic ERC20 with `mint(address, uint256)` |
| `MockWETH` | `src/mocks/MockWETH.sol` | WETH with `deposit()` and `withdraw()` |

---

## 2. Test File Setup

### Step 1: Import All Mocks

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

// Mocks for Aave V3
import {MockAaveV3Pool} from "../test/mock/MockAaveV3Pool.sol";
import {MockAaveV3Oracle} from "../test/mock/MockAaveV3Oracle.sol";
import {MockPoolDataProvider} from "../test/mock/MockPoolDataProvider.sol";

// Token mocks
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockWETH} from "../src/mocks/MockWETH.sol"; // If necessary

// Aave V3 interfaces
import {IPool} from "../interface/aavev3/IPool.sol";
import {IAToken} from "../interface/aavev3/IAToken.sol";
import {IPoolDataProvider} from "../interface/aavev3/IPoolDataProvider.sol";
import {IPriceOracle} from "../interface/aavev3/IPriceOracle.sol";

// Your contract under test
import {YourAaveContract} from "../src/path/to/YourAaveContract.sol";
```

### Step 2: Declare State Variables

```solidity
contract YourAaveContractTest is Test {
    // Contract under test
    YourAaveContract public target;

    // Aave V3 mocks
    MockAaveV3Pool public mockPool;
    MockAaveV3Oracle public mockOracle;
    MockPoolDataProvider public mockDataProvider;

    // Underlying asset mocks
    MockERC20 public usdc;
    MockERC20 public wbtc;
    MockWETH public weth;

    // aToken mocks (represent supply positions)
    MockERC20 public aUsdc;
    MockERC20 public aWbtc;
    MockERC20 public aWeth;

    // Variable debt token mocks (represent borrow positions)
    MockERC20 public vUsdc;
    MockERC20 public vWbtc;

    // Test addresses
    address public user1;
    address public user2;
    address public liquidator;

    // Constants
    uint256 constant BASE_PRECISION = 1e18;
    uint256 constant MIN_HEALTH_FACTOR = 1e18;

    // Oracle prices (8 decimal precision)
    int256 constant USDC_PRICE = 1e8;
    int256 constant WETH_PRICE = 2000e8;
    int256 constant WBTC_PRICE = 40000e8;
}
```

---

## 3. setUp() Flow

### Step 1: Create Mock Instances

Deploy all Aave V3 mocks in order:

```solidity
function setUp() public {
    // Deploy Aave V3 mocks
    mockPool = new MockAaveV3Pool();
    mockOracle = new MockAaveV3Oracle();
    mockDataProvider = new MockPoolDataProvider();

    // Deploy test addresses
    user1 = makeAddr("user1");
    user2 = makeAddr("user2");
    liquidator = makeAddr("liquidator");

    // Deploy underlying asset mocks
    usdc = new MockERC20("USD Coin", "USDC", 6);
    wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
    weth = new MockWETH();

    // Deploy aToken mocks
    aUsdc = new MockERC20("Aave USDC", "aUSDC", 6);
    aWbtc = new MockERC20("Aave WBTC", "aWBTC", 8);
    aWeth = new MockERC20("Aave WETH", "aWETH", 18);

    // Deploy variable debt token mocks
    vUsdc = new MockERC20("Variable Debt USDC", "vUSDC", 6);
    vWbtc = new MockERC20("Variable Debt WBTC", "vWBTC", 8);
```

### Step 2: Set Oracle Prices

Set asset prices on the mock oracle. **Prices use 8 decimal precision:**

```solidity
    // Set oracle prices
    mockOracle.setAssetPrice(address(usdc), uint256(USDC_PRICE));
    mockOracle.setAssetPrice(address(weth), uint256(WETH_PRICE));
    mockOracle.setAssetPrice(address(wbtc), uint256(WBTC_PRICE));
```

| Price | Value | Meaning |
|-------|-------|---------|
| USDC | `1e8` | $1.00 |
| WETH | `2000e8` | $2,000.00 |
| WBTC | `40000e8` | $40,000.00 |

### Step 3: Set Reserve Data on Mock Pool

Configure reserve data for each asset. This tells the mock pool how to respond to `getReserveData()` calls:

```solidity
    // USDC reserve data
    _setupReserveData({
        _asset: address(usdc),
        _aToken: address(aUsdc),
        _variableDebtToken: address(vUsdc),
        _reserveId: 1
    });

    // WETH reserve data
    _setupReserveData({
        _asset: address(weth),
        _aToken: address(aWeth),
        _variableDebtToken: address(0),  // WETH not borrowable in this setup
        _reserveId: 2
    });

    // WBTC reserve data
    _setupReserveData({
        _asset: address(wbtc),
        _aToken: address(aWbtc),
        _variableDebtToken: address(vWbtc),
        _reserveId: 3
    });
```

Helper function for setting up reserve data:

```solidity
function _setupReserveData(
    address _asset,
    address _aToken,
    address _variableDebtToken,
    uint8 _reserveId
) internal {
    IPool.ReserveData memory rd = IPool.ReserveData({
        configuration: IPool.ReserveConfigurationMap(0),
        liquidityIndex: 1e27,
        currentLiquidityRate: 3e25,           // 3% (ray precision)
        variableBorrowIndex: 1e27,
        currentVariableBorrowRate: 5e25,      // 5% (ray precision)
        currentStableBorrowRate: 6e25,        // 6% (ray precision)
        lastUpdateTimestamp: uint40(block.timestamp),
        id: _reserveId,
        aTokenAddress: _aToken,
        stableDebtTokenAddress: address(0),
        variableDebtTokenAddress: _variableDebtToken,
        interestRateStrategyAddress: address(0),
        accruedToTreasury: 0,
        unbacked: 0,
        isolationModeTotalDebt: 0
    });
    mockPool.setReserveData(_asset, rd);
}
```

### Step 4: Set Reserve Configuration on Mock Data Provider

Configure risk parameters for each asset:

```solidity
    // WETH configuration — usable as collateral, borrowable
    _setupReserveConfig({
        _asset: address(weth),
        _decimals: 18,
        _ltv: 7500,
        _liquidationThreshold: 8000,
        _liquidationBonus: 10500,
        _usageAsCollateralEnabled: true,
        _borrowingEnabled: true
    });

    // WBTC configuration — usable as collateral, borrowable
    _setupReserveConfig({
        _asset: address(wbtc),
        _decimals: 8,
        _ltv: 7000,
        _liquidationThreshold: 7500,
        _liquidationBonus: 11000,
        _usageAsCollateralEnabled: true,
        _borrowingEnabled: true
    });

    // USDC configuration — NOT usable as collateral, borrowable only
    _setupReserveConfig({
        _asset: address(usdc),
        _decimals: 6,
        _ltv: 0,
        _liquidationThreshold: 0,
        _liquidationBonus: 0,
        _usageAsCollateralEnabled: false,
        _borrowingEnabled: true
    });
```

Helper function for reserve configuration:

```solidity
function _setupReserveConfig(
    address _asset,
    uint256 _decimals,
    uint256 _ltv,
    uint256 _liquidationThreshold,
    uint256 _liquidationBonus,
    bool _usageAsCollateralEnabled,
    bool _borrowingEnabled
) internal {
    MockPoolDataProvider.ReserveConfig memory rc = MockPoolDataProvider.ReserveConfig({
        decimals: _decimals,
        ltv: _ltv,
        liquidationThreshold: _liquidationThreshold,
        liquidationBonus: _liquidationBonus,
        reserveFactor: 1000,
        usageAsCollateralEnabled: _usageAsCollateralEnabled,
        borrowingEnabled: _borrowingEnabled,
        stableBorrowRateEnabled: false,
        isActive: true,
        isFrozen: false
    });
    mockDataProvider.setReserveConfigurationData(_asset, rc);
}
```

**Parameter meanings (values in basis points):**

| Parameter | Example | Meaning |
|-----------|---------|---------|
| `ltv` | `7500` | 75% loan-to-value — max borrow against this collateral |
| `liquidationThreshold` | `8000` | 80% — position liquidated if debt exceeds this % of collateral |
| `liquidationBonus` | `10500` | 5% bonus to liquidator (10500 - 10000 = 500 bps) |

### Step 5: Set User Account Data

Configure mock health factor and account data for test users:

```solidity
    // Set healthy account data for user1
    _setUserAccountData({
        _user: user1,
        _totalCollateralBase: 2000e8,     // $2,000 in collateral
        _totalDebtBase: 0,                // No debt
        _availableBorrowsBase: 1500e8,    // $1,500 available to borrow
        _currentLiquidationThreshold: 8000,
        _ltv: 7500,
        _healthFactor: type(uint256).max  // Completely healthy (no debt)
    });

    // Set account data for a user with debt (for liquidation tests)
    _setUserAccountData({
        _user: user2,
        _totalCollateralBase: 1000e8,     // $1,000 in collateral
        _totalDebtBase: 800e8,            // $800 in debt
        _availableBorrowsBase: 0,          // Fully utilized
        _currentLiquidationThreshold: 8000,
        _ltv: 7500,
        _healthFactor: 1.1e18             // Slightly above liquidation
    });
```

Helper function:

```solidity
function _setUserAccountData(
    address _user,
    uint256 _totalCollateralBase,
    uint256 _totalDebtBase,
    uint256 _availableBorrowsBase,
    uint256 _currentLiquidationThreshold,
    uint256 _ltv,
    uint256 _healthFactor
) internal {
    mockPool.setUserAccountData(
        _user,
        _totalCollateralBase,
        _totalDebtBase,
        _availableBorrowsBase,
        _currentLiquidationThreshold,
        _ltv,
        _healthFactor
    );
}
```

**Typical health factor values:**

| Scenario | Health Factor |
|----------|--------------|
| No debt | `type(uint256).max` |
| Healthy position | `1.5e18` or higher |
| Near liquidation | `1.01e18` |
| At liquidation | `1e18` |
| Underwater | `< 1e18` |

### Step 6: Deploy Contract Under Test

```solidity
    // Deploy your contract with mock addresses
    target = new YourAaveContract(
        address(mockPool),
        address(mockOracle),
        address(mockDataProvider)
    );
```

### Step 7: Mint Tokens to Pool and Users

```solidity
    // Mint to pool (to back supply/borrow operations)
    usdc.mint(address(mockPool), 1000000e6);
    wbtc.mint(address(mockPool), 100e8);
    weth.mint(address(mockPool), 1000 ether);

    // Mint aTokens to pool
    aUsdc.mint(address(mockPool), 1000000e6);
    aWbtc.mint(address(mockPool), 1000e8);
    aWeth.mint(address(mockPool), 1000 ether);

    // Mint debt tokens to pool
    vUsdc.mint(address(mockPool), 1000000e6);
    vWbtc.mint(address(mockPool), 1000e8);

    // Mint to test users
    usdc.mint(user1, 100000e6);
    wbtc.mint(user1, 10e8);
    weth.mint(user1, 100 ether);

    usdc.mint(user2, 50000e6);
    wbtc.mint(user2, 5e8);

    // Mint ETH for WETH deposits
    vm.deal(user1, 100 ether);
    vm.deal(user2, 50 ether);

    // Mint to liquidator
    usdc.mint(liquidator, 50000e6);
}
```

---

## 4. Precision Reference

### Oracle Prices (8 decimals)

| Price | Value |
|-------|-------|
| $1.00 | `1e8` |
| $10.00 | `10e8` |
| $100.00 | `100e8` |
| $1,000.00 | `1000e8` |
| $10,000.00 | `10000e8` |
| $100,000.00 | `100000e8` |

### Interest Rates (27 decimals — ray)

| Rate | Value |
|------|-------|
| 1% | `1e25` |
| 3% | `3e25` |
| 5% | `5e25` |
| 10% | `10e25` |

### Indices (27 decimals — ray)

| Index | Value |
|-------|-------|
| Initial liquidity index | `1e27` |
| Initial borrow index | `1e27` |

### Reserve Configuration (basis points)

| Parameter | Range | Example |
|-----------|-------|---------|
| `ltv` | 0-10000 | `7500` = 75% |
| `liquidationThreshold` | 0-10000 | `8000` = 80% |
| `liquidationBonus` | 10000+ | `10500` = 5% bonus |
| `reserveFactor` | 0-10000 | `1000` = 10% |

---

## 5. Mock Configuration Helpers

### Setting Reserve Data Dynamically

```solidity
function configureAssetForTest(
    address asset,
    address aToken,
    address debtToken,
    uint256 price,
    uint256 ltv,
    uint256 liquidationThreshold,
    bool asCollateral,
    bool borrowable
) internal {
    // Set oracle price
    mockOracle.setAssetPrice(asset, price);

    // Set reserve data
    _setupReserveData(asset, aToken, debtToken, uint8(mockPool.reserveCount()));

    // Set reserve config
    _setupReserveConfig(
        asset,
        18,
        ltv,
        liquidationThreshold,
        asCollateral ? (liquidationThreshold + 500) : 0,
        asCollateral,
        borrowable
    );
}
```

### Setting a User Underwater (for liquidation tests)

```solidity
function setUnderwaterPosition(address user) internal {
    _setUserAccountData({
        _user: user,
        _totalCollateralBase: 1000e8,
        _totalDebtBase: 950e8,
        _availableBorrowsBase: 0,
        _currentLiquidationThreshold: 8000,
        _ltv: 7500,
        _healthFactor: 0.95e18  // Below 1.0 — liquidatable
    });
}
```

### Configuring Mock Pool to Simulate Reverts

Some mock contracts support setting conditions that cause reverts. Check the specific mock implementation:

```solidity
// If MockAaveV3Pool supports it:
mockPool.setRevertOnSupply(true);  // Next supply call will revert
mockPool.setRevertOnBorrow(true);  // Next borrow call will revert
```

---

## 6. Complete setUp() Example

```solidity
function setUp() public {
    // 1. Deploy Aave V3 mocks
    mockPool = new MockAaveV3Pool();
    mockOracle = new MockAaveV3Oracle();
    mockDataProvider = new MockPoolDataProvider();

    // 2. Deploy test addresses
    user1 = makeAddr("user1");
    user2 = makeAddr("user2");
    liquidator = makeAddr("liquidator");

    // 3. Deploy token mocks
    usdc = new MockERC20("USD Coin", "USDC", 6);
    wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
    weth = new MockWETH();
    aUsdc = new MockERC20("Aave USDC", "aUSDC", 6);
    aWbtc = new MockERC20("Aave WBTC", "aWBTC", 8);
    aWeth = new MockERC20("Aave WETH", "aWETH", 18);
    vUsdc = new MockERC20("Variable Debt USDC", "vUSDC", 6);
    vWbtc = new MockERC20("Variable Debt WBTC", "vWBTC", 8);

    // 4. Set oracle prices
    mockOracle.setAssetPrice(address(usdc), uint256(USDC_PRICE));
    mockOracle.setAssetPrice(address(weth), uint256(WETH_PRICE));
    mockOracle.setAssetPrice(address(wbtc), uint256(WBTC_PRICE));

    // 5. Set reserve data
    _setupReserveData(address(usdc), address(aUsdc), address(vUsdc), 1);
    _setupReserveData(address(weth), address(aWeth), address(0), 2);
    _setupReserveData(address(wbtc), address(aWbtc), address(vWbtc), 3);

    // 6. Set reserve configs
    _setupReserveConfig(address(weth), 18, 7500, 8000, 10500, true, true);
    _setupReserveConfig(address(wbtc), 8, 7000, 7500, 11000, true, true);
    _setupReserveConfig(address(usdc), 6, 0, 0, 0, false, true);

    // 7. Set user account data
    _setUserAccountData(user1, 2000e8, 0, 1500e8, 8000, 7500, type(uint256).max);
    _setUserAccountData(user2, 1000e8, 800e8, 0, 8000, 7500, 1.1e18);

    // 8. Deploy contract under test
    target = new YourAaveContract(
        address(mockPool),
        address(mockOracle),
        address(mockDataProvider)
    );

    // 9. Mint tokens
    usdc.mint(address(mockPool), 1000000e6);
    wbtc.mint(address(mockPool), 100e8);
    weth.mint(address(mockPool), 1000 ether);
    aUsdc.mint(address(mockPool), 1000000e6);
    aWbtc.mint(address(mockPool), 1000e8);
    aWeth.mint(address(mockPool), 1000 ether);
    vUsdc.mint(address(mockPool), 1000000e6);
    vWbtc.mint(address(mockPool), 1000e8);

    usdc.mint(user1, 100000e6);
    wbtc.mint(user1, 10e8);
    weth.mint(user1, 100 ether);
    vm.deal(user1, 100 ether);

    usdc.mint(user2, 50000e6);
    wbtc.mint(user2, 5e8);
    vm.deal(user2, 50 ether);

    usdc.mint(liquidator, 50000e6);
}
```

---

## 7. Next Steps: Writing Tests

After mocks are configured, write and run tests following `guides/test_and_debug.md`:

1. Create unit test file: `test/unit/YourAaveContract.t.sol`
2. Create fuzz test file: `test/fuzz/YourAaveContract.fuzz.t.sol`
3. Write tests covering all operations, reverts, events, state changes, and branches
4. Run tests: `forge test`
5. Verify coverage: `forge coverage`
6. Ensure **>95% coverage**
