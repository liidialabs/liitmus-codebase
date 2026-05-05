# Aave V3 Integration & Update Guide

This guide provides comprehensive, step-by-step instructions for integrating Aave V3 into a Solidity project **or** updating/refining an existing Aave V3 integration. It is designed to be followed by an LLM to produce correct, tested integrations.

---

## 1. Aave V3 Overview

Aave V3 is a decentralized lending protocol that allows users to:
- **Supply** assets to earn interest (receive aTokens)
- **Borrow** assets against collateral (variable or stable rates)
- **Liquidate** underwater positions (repay debt for discounted collateral)
- **Flash loans** (borrow without collateral, repay in same transaction)

---

## 2. Contract Architecture

### Core Contracts

| Contract | Purpose |
|----------|---------|
| `Pool` | Main contract for supply, borrow, withdraw, repay, liquidation, flash loans |
| `PriceOracle` | Provides asset prices in USD |
| `PoolDataProvider` | View functions for reserve and user data |

### Token Types

| Token | Purpose |
|-------|---------|
| `aToken` | Represents supply position (balance grows with interest) |
| `VariableDebtToken` | Represents variable rate borrow position |
| `StableDebtToken` | Represents stable rate borrow position |

### Available Usage Modules

The following usage modules are available in `aave/aave_v3/usage/` for reference during integration:

| Module | File | Purpose |
|--------|------|---------|
| Base | `AaveV3Base.sol` | Base contract with common setup and helpers |
| Supply | `Supply.sol` | Asset supply (deposit) implementation |
| Withdraw | `Withdraw.sol` | Asset withdrawal implementation |
| Borrow | `Borrow.sol` | Asset borrowing implementation |
| Repay | `Repay.sol` | Debt repayment implementation |
| Liquidate | `Liquidate.sol` | Liquidation call implementation |
| FlashLoan | `FlashLoan.sol` | Flash loan implementation |

When integrating any Aave V3 operation, **always reference the corresponding usage file** for correct implementation patterns.

---

## 3. Integration Setup

### Step 1: Check for Existing Aave V3 Setup

Before making any changes, check the target project for an existing Aave V3 integration:

1. **Search for Aave V3 interfaces** in the project's `interface/` or `interfaces/` directories:
   ```bash
   # Look for Aave-related interfaces
   ls interface/ | grep -i aave    # or interfaces/
   ```
   - Files to look for: `IPool.sol`, `IAToken.sol`, `IPoolDataProvider.sol`, `IPriceOracle.sol`, `IVariableDebtToken.sol`

2. **Search for Aave V3 imports** across the codebase:
   ```bash
   grep -r "IPool\|AaveV3\|aave.*v3" src/ --include="*.sol"
   ```

3. **Check for existing Aave interaction contracts**:
   - Look for contracts that import or reference `IPool`, `MockAaveV3Pool`, or Aave addresses
   - Check if there is already a base contract extending Aave functionality

### Step 2: If No Existing Aave V3 Setup — Create Interface Directory

If the project does **not** have an existing Aave V3 setup, create the interface directory and copy the interfaces from the reference modules:

1. **Create `aavev3/` inside the project's existing `interface/` directory:**
   ```
   interface/
   └── aavev3/
       ├── IPool.sol
       ├── IAToken.sol
       ├── IPoolDataProvider.sol
       ├── IPriceOracle.sol
       └── IVariableDebtToken.sol
   ```

2. **Write the interface files** by copying from `aave/aave_v3/interface/`:
   - `aave/aave_v3/interface/IPool.sol` → `interface/aavev3/IPool.sol`
   - `aave/aave_v3/interface/IAToken.sol` → `interface/aavev3/IAToken.sol`
   - `aave/aave_v3/interface/IPoolDataProvider.sol` → `interface/aavev3/IPoolDataProvider.sol`
   - `aave/aave_v3/interface/IPriceOracle.sol` → `interface/aavev3/IPriceOracle.sol`
   - `aave/aave_v3/interface/IVariableDebtToken.sol` → `interface/aavev3/IVariableDebtToken.sol`

3. **Verify the interfaces compile** with the rest of the project:
   ```bash
   forge build
   ```

### Step 3: If Existing Aave V3 Setup Found — Review and Update

If the project already has Aave V3 interfaces or integration:

1. **Review existing interface versions** — compare against the reference interfaces in `aave/aave_v3/interface/` to ensure they are up to date
2. **Review existing integration contracts** — identify which Aave V3 operations are already implemented
3. **Note any customizations** the project has made that should be preserved
4. **Proceed to the integration step** below, referencing the appropriate usage modules

### Step 4: Configure Contract Addresses

Once interfaces are in place, configure the Aave V3 contract addresses for the target chain. Get addresses from the [Aave V3 docs](https://docs.aave.com/developers/deployed-contracts/v3-mainnet) or reference `aave/aave_v3/Constants.sol`:

```solidity
import {IPool} from "../interface/aavev3/IPool.sol";
import {IPoolDataProvider} from "../interface/aavev3/IPoolDataProvider.sol";
import {IPriceOracle} from "../interface/aavev3/IPriceOracle.sol";

contract MyAaveIntegration {
    IPool public pool;
    IPriceOracle public oracle;
    IPoolDataProvider public dataProvider;

    constructor(address _pool, address _oracle, address _dataProvider) {
        pool = IPool(_pool);
        oracle = IPriceOracle(_oracle);
        dataProvider = IPoolDataProvider(_dataProvider);
    }
}
```

### Step 5: Verify Asset is Listed

Before interacting with any asset, verify it is listed on Aave V3:

```solidity
function isAssetListed(address asset) public view returns (bool) {
    try pool.getReserveData(asset) returns (IPool.ReserveData memory) {
        return true;
    } catch {
        return false;
    }
}
```

---

## 4. Perform the Integration or Update

### Determine the Scope

Based on the user's instructions, identify what needs to be done:

- **New integration**: The user wants to add Aave V3 functionality to their project for the first time
- **Update existing integration**: The user wants to modify, extend, or fix an existing Aave V3 integration

In both cases, **reference the appropriate usage module** from `aave/aave_v3/usage/` for correct implementation patterns.

### 4.1 New Integration

If the user is integrating Aave V3 for the first time, follow their instructions on **where** to integrate (which contract, which functions) and reference the corresponding usage files:

| User Wants To... | Reference Usage File |
|-------------------|---------------------|
| Supply/deposit assets | `aave/aave_v3/usage/Supply.sol` |
| Withdraw assets | `aave/aave_v3/usage/Withdraw.sol` |
| Borrow assets | `aave/aave_v3/usage/Borrow.sol` |
| Repay debt | `aave/aave_v3/usage/Repay.sol` |
| Liquidate positions | `aave/aave_v3/usage/Liquidate.sol` |
| Execute flash loans | `aave/aave_v3/usage/FlashLoan.sol` |
| Set up base Aave functionality | `aave/aave_v3/usage/AaveV3Base.sol` |

**Integration pattern for each operation:**

1. **Read the usage file** to understand the correct implementation
2. **Implement the function** in the user's target contract, adapting as needed
3. **Ensure proper imports** of interfaces from `interface/aavev3/`
4. **Follow the flow** documented in the usage file (approve → call → verify)
5. **Add error handling** for Aave-specific reverts
6. **Add access control** as specified by the user

### 4.2 Update Existing Integration

If updating or refining an existing Aave V3 integration:

1. **Read the existing integration code** to understand the current implementation
2. **Compare against the reference usage files** in `aave/aave_v3/usage/` to identify gaps or issues
3. **Apply the user's requested changes** while referencing the correct usage patterns
4. **Ensure consistency** across all Aave-related functions in the contract
5. **Preserve any custom logic** that the user wants to keep

### 4.3 Core Operation Reference

Each usage module in `aave/aave_v3/usage/` contains the canonical implementation pattern. Always reference them directly rather than relying on memory. The key operations and their patterns:

#### Supply
- Transfer asset from user → Approve pool → Call `pool.supply()` → Receive aTokens
- Reference: `aave/aave_v3/usage/Supply.sol`

#### Withdraw
- Call `pool.withdraw()` → aTokens burned → Underlying tokens received
- Reference: `aave/aave_v3/usage/Withdraw.sol`

#### Borrow
- Verify health factor → Call `pool.borrow()` → Receive borrowed tokens → Debt tokens minted
- Reference: `aave/aave_v3/usage/Borrow.sol`

#### Repay
- Transfer repayment tokens → Approve pool → Call `pool.repay()` → Debt reduced
- Reference: `aave/aave_v3/usage/Repay.sol`

#### Liquidate
- Transfer debt tokens → Approve pool → Call `pool.liquidationCall()` → Receive collateral
- Reference: `aave/aave_v3/usage/Liquidate.sol`

#### Flash Loan
- Call `pool.flashLoanSimple()` → Pool calls `executeOperation()` → Perform logic → Approve repayment → Pool verifies
- Reference: `aave/aave_v3/usage/FlashLoan.sol`

---

## 5. Post-Integration: Write Mock Contracts

After the integration code is written (new or updated), set up mock contracts for testing.

### Step 1: Copy Mock Contracts from Reference

The mock contracts are available in `aave/aave_v3/mocks/`. These should be referenced or copied into the project's test directory:

| Mock | Location | Purpose |
|------|----------|---------|
| `MockAaveV3Pool.sol` | `aave/aave_v3/mocks/MockAaveV3Pool.sol` | Simulates Aave Pool (supply, borrow, withdraw, repay, liquidate, flash loans) |
| `MockAaveV3Oracle.sol` | `aave/aave_v3/mocks/MockAaveV3Oracle.sol` | Simulates price oracle with configurable asset prices |
| `MockPoolDataProvider.sol` | `aave/aave_v3/mocks/MockPoolDataProvider.sol` | Simulates pool data provider with configurable reserve configs |

### Step 2: Also Reference Base Token Mocks

| Mock | Location | Purpose |
|------|----------|---------|
| `MockERC20.sol` | `src/mocks/MockERC20.sol` | Generic ERC20 with `mint(address, uint256)` |
| `MockWETH.sol` | `src/mocks/MockWETH.sol` | WETH mock with `deposit()` and `withdraw()` |

### Step 3: Set Up Test Environment

Place mock contracts in the appropriate test directory:
- Mocks specific to Aave V3 testing → `test/mock/`
- General token mocks → reference from `src/mocks/`

For detailed mock setup instructions, follow `aave/aave_v3/guides/integration_mocks.md`.

---

## 6. Write and Run Tests

After mocks are in place, write comprehensive tests following `guides/test_and_debug.md`.

### Step 1: Create Test Files

Following the structure in `guides/test_and_debug.md`:

```
test/
├── unit/
│   └── YourAaveIntegrationContract.t.sol    # Unit tests
├── fuzz/
│   └── YourAaveIntegrationContract.fuzz.t.sol  # Fuzz tests
└── mock/
    ├── MockAaveV3Pool.sol
    ├── MockAaveV3Oracle.sol
    └── MockPoolDataProvider.sol
```

### Step 2: Write Unit Tests

For the contract that integrates Aave V3, write tests covering:

1. **Happy path for each Aave operation** (supply, withdraw, borrow, repay, liquidate, flash loan)
2. **All revert conditions** — asset not listed, insufficient balance, health factor too low, unauthorized access
3. **All branches** — different asset types, rate modes, collateral states
4. **Events emitted** — Aave events and your contract's own events
5. **State changes** — aToken balances, debt balances, health factor
6. **Access control** — only authorized addresses can call Aave functions
7. **Edge cases** — zero amounts, max amounts, address(0)

**Example test structure:**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YourAaveContract} from "../src/path/to/YourAaveContract.sol";
import {MockAaveV3Pool} from "../test/mock/MockAaveV3Pool.sol";
import {MockAaveV3Oracle} from "../test/mock/MockAaveV3Oracle.sol";
import {MockPoolDataProvider} from "../test/mock/MockPoolDataProvider.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract YourAaveContractTest is Test {
    YourAaveContract public target;
    MockAaveV3Pool public mockPool;
    MockAaveV3Oracle public mockOracle;
    MockPoolDataProvider public mockDataProvider;
    MockERC20 public asset;

    address public user;

    function setUp() public {
        user = makeAddr("user");

        // Deploy mocks
        mockPool = new MockAaveV3Pool();
        mockOracle = new MockAaveV3Oracle();
        mockDataProvider = new MockPoolDataProvider();

        // Deploy asset mock
        asset = new MockERC20("Test Token", "TST", 18);

        // Deploy target contract with mock addresses
        target = new YourAaveContract(
            address(mockPool),
            address(mockOracle),
            address(mockDataProvider)
        );

        // Configure mock pool and data provider for the asset
        _setupMockReserve(address(asset));

        // Fund user
        asset.mint(user, 1000 ether);
    }

    function _setupMockReserve(address _asset) internal {
        // Set oracle price
        mockOracle.setAssetPrice(_asset, 2000e8);

        // Set reserve data on mock pool
        IPool.ReserveData memory rd = IPool.ReserveData({
            configuration: IPool.ReserveConfigurationMap(0),
            liquidityIndex: 1e27,
            currentLiquidityRate: 3e25,
            variableBorrowIndex: 1e27,
            currentVariableBorrowRate: 5e25,
            currentStableBorrowRate: 6e25,
            lastUpdateTimestamp: uint40(block.timestamp),
            id: 1,
            aTokenAddress: _asset,
            stableDebtTokenAddress: address(0),
            variableDebtTokenAddress: _asset,
            interestRateStrategyAddress: address(0),
            accruedToTreasury: 0,
            unbacked: 0,
            isolationModeTotalDebt: 0
        });
        mockPool.setReserveData(_asset, rd);

        // Set reserve configuration
        MockPoolDataProvider.ReserveConfig memory rc = MockPoolDataProvider.ReserveConfig({
            decimals: 18,
            ltv: 7500,
            liquidationThreshold: 8000,
            liquidationBonus: 10500,
            reserveFactor: 1000,
            usageAsCollateralEnabled: true,
            borrowingEnabled: true,
            stableBorrowRateEnabled: true,
            isActive: true,
            isFrozen: false
        });
        mockDataProvider.setReserveConfigurationData(_asset, rc);
    }

    // === Supply Tests ===
    function test_Supply_DepositsToAave() public {
        uint256 amount = 10 ether;
        asset.mint(address(this), amount);
        asset.approve(address(target), amount);

        target.supply(address(asset), amount);

        // Verify aToken balance increased
        // Verify pool state updated
    }

    function test_Supply_RevertWhen_AssetNotListed() public {
        address unlistedAsset = address(new MockERC20("Unlisted", "UNL", 18));
        vm.expectRevert(/* appropriate error */);
        target.supply(unlistedAsset, 1 ether);
    }

    // === Withdraw Tests ===
    function test_Withdraw_RetrievesFromAave() public {
        // Supply first
        // Then withdraw
        // Verify balances
    }

    function test_Withdraw_RevertWhen_InsufficientBalance() public {
        vm.expectRevert(/* appropriate error */);
        target.withdraw(address(asset), 1 ether);
    }

    // === Borrow Tests ===
    function test_Borrow_BorrowsAgainstCollateral() public {
        // Setup collateral
        // Borrow
        // Verify debt tokens
    }

    function test_Borrow_RevertWhen_HealthFactorTooLow() public {
        vm.expectRevert(/* appropriate error */);
        target.borrow(address(asset), 1 ether);
    }

    // === Repay Tests ===
    // === Liquidate Tests ===
    // === Flash Loan Tests ===
}
```

### Step 3: Write Fuzz Tests

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YourAaveContract} from "../src/path/to/YourAaveContract.sol";
import {MockAaveV3Pool} from "../test/mock/MockAaveV3Pool.sol";
import {MockAaveV3Oracle} from "../test/mock/MockAaveV3Oracle.sol";
import {MockPoolDataProvider} from "../test/mock/MockPoolDataProvider.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract YourAaveContractFuzzTest is Test {
    YourAaveContract public target;
    MockAaveV3Pool public mockPool;
    MockERC20 public asset;

    function setUp() public {
        mockPool = new MockAaveV3Pool();
        mockOracle = new MockAaveV3Oracle();
        mockDataProvider = new MockPoolDataProvider();
        asset = new MockERC20("Test", "TST", 18);
        target = new YourAaveContract(address(mockPool), address(mockOracle), address(mockDataProvider));
        _setupMockReserve(address(asset));
    }

    function testFuzz_Supply_AnyAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000000 ether);
        asset.mint(address(this), amount);
        asset.approve(address(target), amount);
        target.supply(address(asset), amount);
        // Verify aToken balance
    }

    function testFuzz_Withdraw_UpToBalance(uint256 amount) public {
        uint256 supplyAmount = 100 ether;
        vm.assume(amount > 0 && amount <= supplyAmount);
        // Supply first, then fuzz withdraw amount
    }
}
```

### Step 4: Run Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/unit/YourAaveContract.t.sol

# Run with verbosity
forge test -vvv

# Run with gas report
forge test --gas-report

# Run fuzz tests with more iterations
forge test --fuzz-runs 10000
```

### Step 5: Verify Coverage

```bash
# Generate coverage report
forge coverage

# Generate detailed coverage (excluding mocks and tests)
forge coverage --no-match-coverage "test|mock|Mock"

# Generate lcov report
forge coverage --report lcov --report-file coverage/lcov.info
```

**Target: >95% coverage** across all metrics (lines, statements, branches, functions) for the integrated contract. See `guides/test_and_debug.md` Section 9 for the full coverage checklist.

---

## 7. Health Factor Management

### Understanding Health Factor

```
Health Factor = (Total Collateral × Liquidation Threshold) / Total Debt
```

- **HF < 1e18**: Position can be liquidated
- **HF = 1e18**: At liquidation threshold
- **HF > 1e18**: Safe position
- **HF = type(uint256).max**: No debt (completely safe)

### Monitor Health Factor

```solidity
function getHealthFactor() public view returns (uint256) {
    (,,,,, uint256 healthFactor) = pool.getUserAccountData(address(this));
    return healthFactor;
}

function isHealthy() public view returns (bool) {
    return getHealthFactor() >= 1e18;
}
```

### Full Account Data

```solidity
function getAccountData() public view returns (
    uint256 totalCollateralBase,         // Total collateral value (1e8 = 1 USD)
    uint256 totalDebtBase,              // Total debt value (1e8 = 1 USD)
    uint256 availableBorrowsBase,       // Available borrowing power
    uint256 currentLiquidationThreshold, // Weighted liquidation threshold
    uint256 ltv,                        // Weighted loan-to-value ratio
    uint256 healthFactor                // Current health factor
) {
    return pool.getUserAccountData(address(this));
}
```

---

## 8. Advanced Patterns

### 8.1 Supply + Borrow in One Transaction

```solidity
function supplyAndBorrow(
    address supplyAsset,
    uint256 supplyAmount,
    address borrowAsset,
    uint256 borrowAmount
) external {
    IERC20(supplyAsset).transferFrom(msg.sender, address(this), supplyAmount);
    IERC20(supplyAsset).approve(address(pool), supplyAmount);
    pool.supply(supplyAsset, supplyAmount, address(this), 0);

    pool.setUserUseReserveAsCollateral(supplyAsset, true);

    (,,,,, uint256 hf) = pool.getUserAccountData(address(this));
    require(hf > 1e18, "Would be underwater");

    pool.borrow(borrowAsset, borrowAmount, 2, 0, address(this));
}
```

### 8.2 E-Mode (Efficiency Mode)

E-Mode provides higher LTV for correlated assets (e.g., stablecoins):

```solidity
function enableStablecoinEMode() external {
    pool.setUserEMode(1);  // Category 1 is typically stablecoins
}

function disableEMode() external {
    pool.setUserEMode(0);
}
```

### 8.3 Batch Operations

```solidity
function batchSupply(address[] calldata assets, uint256[] calldata amounts) external {
    require(assets.length == amounts.length, "Length mismatch");
    for (uint256 i = 0; i < assets.length; i++) {
        IERC20(assets[i]).transferFrom(msg.sender, address(this), amounts[i]);
        IERC20(assets[i]).approve(address(pool), amounts[i]);
        pool.supply(assets[i], amounts[i], address(this), 0);
    }
}
```

---

## 9. Integration Checklist

### Before Deployment
- [ ] Verified all contract addresses for target chain
- [ ] Confirmed assets are listed and active on Aave V3
- [ ] Interfaces copied to `interface/aavev3/` (or existing ones verified)
- [ ] Tested supply/withdraw on testnet
- [ ] Tested borrow/repay with health factor monitoring
- [ ] Tested edge cases (max amounts, zero balances, unlisted assets)
- [ ] Verified oracle prices are current
- [ ] Mock contracts configured for testing

### Security Checks
- [ ] Reentrancy guard on all external functions
- [ ] Input validation for all addresses and amounts
- [ ] Health factor checks before borrowing
- [ ] Approval handling (never assume user has approved)
- [ ] Slippage protection for complex operations
- [ ] Emergency pause mechanism
- [ ] Access control on admin functions
- [ ] Asset listing verification before any Aave call

### Test Coverage
- [ ] Unit tests written for every Aave operation
- [ ] Fuzz tests for supply/withdraw/borrow amounts
- [ ] All revert conditions tested
- [ ] All branches tested
- [ ] All events tested
- [ ] All state changes verified
- [ ] Coverage >95% confirmed via `forge coverage`

### Gas Optimization
- [ ] Cached storage variables in loops
- [ ] Used `calldata` for function parameters
- [ ] Minimized external calls
- [ ] Batched operations where possible
- [ ] Considered gas costs for each operation

---

## 10. Common Error Handling

```solidity
function safeSupply(address asset, uint256 amount) external {
    // Check asset is listed
    try pool.getReserveData(asset) returns (IPool.ReserveData memory) {
        // Asset is listed, proceed
    } catch {
        revert("Asset not listed on Aave V3");
    }

    require(amount > 0, "Amount must be greater than 0");
    require(IERC20(asset).balanceOf(msg.sender) >= amount, "Insufficient balance");

    IERC20(asset).transferFrom(msg.sender, address(this), amount);
    IERC20(asset).approve(address(pool), amount);
    pool.supply(asset, amount, address(this), 0);
}

function safeBorrow(address asset, uint256 amount) external {
    // Check borrowing is enabled
    (,, bool borrowingEnabled,,,) = dataProvider.getReserveConfigurationData(asset);
    require(borrowingEnabled, "Borrowing not enabled for this asset");

    // Check health factor after borrow
    uint256 price = oracle.getAssetPrice(asset);
    uint256 decimals = IERC20Metadata(asset).decimals();
    uint256 debtValue = amount * price / (10 ** decimals);

    (, uint256 totalDebtBase, uint256 availableBorrowsBase,,,,) = pool.getUserAccountData(address(this));
    require(totalDebtBase + debtValue <= availableBorrowsBase, "Would exceed borrow limit");

    pool.borrow(asset, amount, 2, 0, address(this));
}
```

---

## 11. Event Monitoring

Listen for these events to track Aave V3 activity:

```solidity
// Supply events
event Supply(address indexed reserve, address indexed user, uint256 amount);
event Withdraw(address indexed reserve, address indexed user, address indexed to, uint256 amount);

// Borrow events
event Borrow(
    address indexed reserve,
    address indexed user,
    address indexed onBehalfOf,
    uint256 amount,
    uint8 interestRateMode,
    uint256 borrowRate,
    uint16 referralCode
);
event Repay(
    address indexed reserve,
    address indexed user,
    address indexed repayer,
    uint256 amount,
    bool useATokens
);

// Liquidation events
event LiquidationCall(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 debtToCover,
    uint256 amount,
    address liquidator,
    bool receiveAToken
);

// Flash loan events
event FlashLoan(
    address indexed target,
    address indexed initiator,
    address indexed asset,
    uint256 amount,
    uint8 interestRateMode,
    uint256 premium,
    uint16 referralCode
);
```

---

## 12. Chain-Specific Notes

### Mainnet
- Highest liquidity, most assets available
- Gas costs are higher
- Use for production

### Arbitrum/Optimism (L2)
- Lower gas costs
- Most major assets available
- Good for frequent operations

### Polygon
- Very low gas costs
- Good for testing and lower-value operations
- Some assets may have lower liquidity

### Base
- Growing ecosystem
- Good L2 option for Coinbase users
- Check asset availability

### Avalanche
- Fast finality
- Good for DeFi integrations
- Check specific asset listings

---

## 13. Resources

- [Aave V3 Documentation](https://docs.aave.com/developers/)
- [Aave V3 Core Contracts](https://github.com/aave/aave-v3-core)
- [Deployed Contracts](https://docs.aave.com/developers/deployed-contracts/v3-mainnet)
- [Aave V3 Technical Reference](https://docs.aave.com/developers/guides/technical-reference)
- **Internal References**:
  - Usage patterns: `aave/aave_v3/usage/`
  - Interfaces: `aave/aave_v3/interface/`
  - Mocks: `aave/aave_v3/mocks/`
  - Mock setup guide: `aave/aave_v3/guides/integration_mocks.md`
  - Test guide: `guides/test_and_debug.md`
