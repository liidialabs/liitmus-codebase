# Solidity Smart Contract Test & Debug Guide

This guide provides step-by-step instructions for writing, running, and debugging comprehensive tests for Solidity smart contracts using Foundry. It is intended for use by an LLM to write and run tests on a codebase, either from scratch or for updates. The goal is to achieve **>95% test coverage** across all contracts.

---

## 1. Framework Identification And Project Understanding

The project shoukd be using **Foundry (Forge)** exclusively.

- **Indicators**: `foundry.toml` in the project root, `lib/` directory with git submodules, `test/` directory containing `.t.sol` files
- **Test command**: `forge test`
- **Test file naming**: `ContractName.t.sol`
- **Solidity version**: Follow the pragma defined in each source contract

Go through the codebase to better understand the contract functionality and any integrations that have been made made with any external protocol.

---

## 2. Project Setup

### Verify Foundry Installation
```bash
forge --version
```

### Install Dependencies (if not installed)
```bash
# Install forge-std and other library dependencies
forge install
```

### Verify Project Compiles
```bash
forge build
```

---

## 3. Test Directory Structure

All tests live under `test/` with the following structure:

```
test/
├── unit/          # Unit tests — one test contract per source contract
├── fuzz/          # Fuzz and invariant tests
└── mock/          # Mock test harnesses and helper contracts (if needed beyond src/mocks/)
```

### 3.1 `test/unit/` — Unit Tests

- **One test contract per source contract** in `src/`
- File naming: `ContractName.t.sol`
- Each test contract inherits from `forge-std/Test.sol`
- Tests every public/external function thoroughly:
  - Happy path
  - All revert conditions
  - All branches (if/else, require guards)
  - Events emitted
  - State changes
  - Access control

### 3.2 `test/fuzz/` — Fuzz & Invariant Tests

- File naming: `ContractName.fuzz.t.sol` or `ContractName.invariant.t.sol`
- Property-based testing with Foundry's built-in fuzzing
- Invariant tests for system-level guarantees
- Use `vm.assume()` to constrain inputs meaningfully

### 3.3 `test/mock/` — Test Mocks

- Mock contracts needed only for testing purposes
- For external protocol mocks (Aave, oracles, etc.), **reference the mocks already provided in `src/`**:
  - `src/mocks/MockERC20.sol` — Generic ERC20 mock with minting
  - `src/mocks/MockWETH.sol` — WETH mock
  - `src/aave/aave_v3/mocks/MockAaveV3Pool.sol` — Aave V3 Pool mock
  - `src/aave/aave_v3/mocks/MockAaveV3Oracle.sol` — Aave V3 Oracle mock
  - `src/aave/aave_v3/mocks/MockPoolDataProvider.sol` — Pool data provider mock
- Additional test-only mocks go here if not appropriate for `src/mocks/`

---

## 4. Writing Unit Tests

### 4.1 Test Contract Structure

Each contract in `src/` gets its own test contract in `test/unit/`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {YourContract} from "../src/path/to/YourContract.sol";

// Import mocks from src/ when needed
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockWETH} from "../src/mocks/MockWETH.sol";

contract YourContractTest is Test {
    YourContract public target;
    MockERC20 public mockToken;
    MockWETH public mockWeth;

    address public owner;
    address public user;
    address public nonOwner;

    function setUp() public {
        owner = address(this);
        user = makeAddr("user");
        nonOwner = makeAddr("nonOwner");

        mockToken = new MockERC20("Mock Token", "MCK", 18);
        mockWeth = new MockWETH();

        target = new YourContract(/* constructor args */);
    }

    // === Constructor / Initial State Tests ===
    function test_Constructor_SetsOwner() public view {
        assertEq(target.owner(), owner);
    }

    // === Function Tests ===
    // Group tests per function using naming convention:
    //   test_FunctionName_Description()
    //   test_FunctionName_RevertWhen_Condition()
}
```

### 4.2 Testing Every Function — Checklist

For **each public/external function**, write tests covering:

1. **Happy path** — normal successful execution
2. **State changes** — verify all storage variables updated correctly
3. **Events emitted** — verify all events with correct parameters
4. **All revert conditions** — every `require`, `revert`, custom error
5. **All branches** — every `if/else`, ternary, and conditional path
6. **Access control** — `onlyOwner`, role checks, pausable guards
7. **Edge cases** — zero values, max values, empty arrays, address(0)

### 4.3 State Change Testing

Always verify state before and after the function call.

```solidity
function test_Deposit_UpdatesBalance() public {
    uint256 amount = 1 ether;
    mockWeth.deposit{value: amount}();
    mockWeth.approve(address(target), amount);

    uint256 balanceBefore = target.balanceOf(user);

    vm.prank(user);
    target.deposit(address(mockWeth), amount);

    uint256 balanceAfter = target.balanceOf(user);
    assertEq(balanceAfter, balanceBefore + amount);
}
```

### 4.4 Event Testing

Test every event emitted by each function. Use `vm.expectEmit()` with correct indexed parameters.

```solidity
function test_Deposit_EmitsEvent() public {
    uint256 amount = 1 ether;
    mockWeth.deposit{value: amount}();
    mockWeth.approve(address(target), amount);

    vm.expectEmit(true, true, false, true);
    emit YourContract.Deposited(user, address(mockWeth), amount, block.timestamp);

    vm.prank(user);
    target.deposit(address(mockWeth), amount);
}
```

**Indexed parameter guide for `vm.expectEmit(check1, check2, check3, checkAll)`:**
- `check1`: first indexed parameter
- `check2`: second indexed parameter
- `check3`: third indexed parameter
- `checkAll`: non-indexed parameters

### 4.5 Revert Testing

Test every possible revert condition with the exact error.

```solidity
// Custom error selector
function test_Withdraw_RevertWhen_InsufficientBalance() public {
    vm.prank(user);
    vm.expectRevert(YourContract.InsufficientBalance.selector);
    target.withdraw(1 ether);
}

// String revert
function test_Withdraw_RevertWhen_NotOwner() public {
    vm.prank(nonOwner);
    vm.expectRevert("Only owner");
    target.withdraw(1 ether);
}

// Panic code
function test_Math_RevertOnOverflow() public {
    vm.expectRevert(stdError.arithmeticError);
    target.riskyMathOperation(type(uint256).max, 1);
}
```

### 4.6 Branch Testing

Test every conditional branch independently.

```solidity
// Example: function with multiple branches
function withdrawRevenue(address to, address asset, uint256 amount) external {
    if (to == address(0) || asset == address(0)) {
        revert ZeroAddress();
    }
    if (asset == usdc || asset == usdt) {
        if (amount > s_protocolRevenueAccrued || s_protocolRevenueAccrued == 0) {
            revert InsufficientAmount();
        }
        s_protocolRevenueAccrued -= amount;
    } else {
        uint256 revenue = s_liquidationRevenue[asset];
        if (amount > revenue || revenue == 0) {
            revert InsufficientAmount();
        }
        s_liquidationRevenue[asset] -= amount;
    }
    IERC20(asset).safeTransfer(to, amount);
    emit RevenueWithdrawn(to, asset, amount, uint32(block.timestamp));
}
```

Corresponding tests:

```solidity
// Branch 1: Stablecoin path (USDC/USDT)
function test_WithdrawRevenue_StablecoinPath() public {
    // Setup: accrue protocol revenue in USDC
    target.setProtocolRevenueAccrued(1000e6);

    uint256 balanceBefore = mockUsdc.balanceOf(treasury);

    vm.expectEmit(true, true, false, true);
    emit YourContract.RevenueWithdrawn(treasury, address(mockUsdc), 500e6, uint32(block.timestamp));

    target.withdrawRevenue(treasury, address(mockUsdc), 500e6);

    assertEq(target.protocolRevenueAccrued(), 500e6);
    assertEq(mockUsdc.balanceOf(treasury), balanceBefore + 500e6);
}

// Branch 2: Liquidation revenue path (other tokens)
function test_WithdrawRevenue_LiquidationPath() public {
    target.setLiquidationRevenue(address(weth), 10 ether);

    uint256 balanceBefore = weth.balanceOf(treasury);

    target.withdrawRevenue(treasury, address(weth), 5 ether);

    assertEq(target.liquidationRevenue(address(weth)), 5 ether);
    assertEq(weth.balanceOf(treasury), balanceBefore + 5 ether);
}

// Revert: zero address
function test_WithdrawRevenue_RevertWhen_ZeroRecipient() public {
    vm.expectRevert(YourContract.ZeroAddress.selector);
    target.withdrawRevenue(address(0), address(mockUsdc), 100e6);
}

function test_WithdrawRevenue_RevertWhen_ZeroAsset() public {
    vm.expectRevert(YourContract.ZeroAddress.selector);
    target.withdrawRevenue(treasury, address(0), 100e6);
}

// Revert: insufficient amounts (both branches)
function test_WithdrawRevenue_RevertWhen_InsufficientStablecoinRevenue() public {
    vm.expectRevert(YourContract.InsufficientAmount.selector);
    target.withdrawRevenue(treasury, address(mockUsdc), 1000e6);
}

function test_WithdrawRevenue_RevertWhen_InsufficientLiquidationRevenue() public {
    vm.expectRevert(YourContract.InsufficientAmount.selector);
    target.withdrawRevenue(treasury, address(weth), 10 ether);
}
```

### 4.7 Access Control Testing

Test that restricted functions reject unauthorized callers.

```solidity
function test_OnlyOwner_Function_RevertWhen_NonOwner() public {
    vm.prank(nonOwner);
    vm.expectRevert(YourContract.Unauthorized.selector);
    target.ownerOnlyFunction();
}

function test_OnlyOwner_Function_SucceedsForOwner() public {
    target.ownerOnlyFunction(); // owner = address(this)
    // Assert expected state change
}
```

Use `vm.prank()` to simulate calls from different addresses:

```solidity
vm.prank(addressToImpersonate);
target.someFunction();

// Or with value:
vm.prank(user);
target.someFunction{value: 1 ether}();
```

---

## 5. Writing Fuzz Tests

Fuzz tests go in `test/fuzz/`. They test properties across a wide range of inputs.

### 5.1 Basic Fuzz Testing

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YourContract} from "../src/path/to/YourContract.sol";

contract YourContractFuzzTest is Test {
    YourContract public target;

    function setUp() public {
        target = new YourContract();
    }

    function testFuzz_Deposit_AnyAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount < type(uint256).max);
        vm.assume(amount <= target.maxDeposit());

        uint256 balanceBefore = target.balanceOf(address(this));
        target.deposit(amount);
        uint256 balanceAfter = target.balanceOf(address(this));

        assertEq(balanceAfter, balanceBefore + amount);
    }
}
```

### 5.2 Invariant Testing

Invariant tests verify system properties that must always hold.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YourContract} from "../src/path/to/YourContract.sol";

contract YourContractInvariantTest is Test {
    YourContract public target;

    function setUp() public {
        target = new YourContract();
    }

    function invariant_TotalSupplyNeverZero() public view {
        assertGt(target.totalSupply(), 0);
    }

    function invariant_BalancesSumToSupply() public view {
        // Verify sum of all tracked balances equals totalSupply
        assertEq(target.sumOfBalances(), target.totalSupply());
    }
}
```

### 5.3 Fuzz Test Configuration

Control fuzz runs in `foundry.toml` or via CLI:

```bash
# More fuzz runs for thorough testing
forge test --fuzz-runs 10000

# Set in foundry.toml:
# [fuzz]
# runs = 256
#
# [invariant]
# runs = 256
# depth = 500
```

---

## 6. Using Mock Contracts

### 6.1 Mocks from `src/mocks/`

These are the core mock contracts available for all tests:

| Mock | Location | Purpose |
|------|----------|---------|
| `MockERC20` | `src/mocks/MockERC20.sol` | Standard ERC20 with `mint(address, uint256)` |
| `MockWETH` | `src/mocks/MockWETH.sol` | WETH with `deposit()` and `withdraw()` |

### 6.2 Mocks from `src/aave/aave_v3/mocks/`

For tests involving Aave V3 protocol interactions:

| Mock | Location | Purpose |
|------|----------|---------|
| `MockAaveV3Pool` | `src/aave/aave_v3/mocks/MockAaveV3Pool.sol` | Simulates Aave Pool (supply, borrow, withdraw, repay) |
| `MockAaveV3Oracle` | `src/aave/aave_v3/mocks/MockAaveV3Oracle.sol` | Simulates price oracle |
| `MockPoolDataProvider` | `src/aave/aave_v3/mocks/MockPoolDataProvider.sol` | Simulates pool data queries |

### 6.3 Mocking with `vm.mockCall`

For mocking external calls without deploying full mock contracts:

```solidity
function test_WithMockedExternalCall() public {
    address externalContract = address(0x123);

    // Mock a specific call
    vm.mockCall(
        externalContract,
        abi.encodeWithSelector(IExternal.price.selector, asset),
        abi.encode(1000e18)
    );

    // Execute function that calls the mocked contract
    target.functionUsingExternalPrice();

    // Clear mock if needed
    vm.clearMockedCalls();
}
```

### 6.4 Mocking with `vm.etch`

Replace an existing contract's bytecode:

```solidity
function test_WithEtchedContract() public {
    // Deploy mock
    MockERC20 mock = new MockERC20("Test", "TST", 18);

    // Etch bytecode at a specific address (e.g., a well-known token address)
    address targetAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    vm.etch(targetAddress, address(mock).code);

    // Now calls to targetAddress will execute mock's code
}
```

---

## 7. Foundry Test Cheat Codes

Common `vm.` cheat codes used in tests:

| Cheat Code | Purpose |
|------------|---------|
| `vm.prank(address)` | Set `msg.sender` for next call |
| `vm.startPrank(address)` | Set `msg.sender` for multiple calls |
| `vm.stopPrank()` | Stop impersonating |
| `vm.warp(uint256)` | Set `block.timestamp` |
| `vm.roll(uint256)` | Set `block.number` |
| `vm.deal(address, uint256)` | Set ETH balance |
| `vm.assume(bool)` | Constrain fuzz inputs |
| `vm.expectRevert()` | Expect next call to revert |
| `vm.expectEmit(...)` | Expect event emission |
| `vm.mockCall(...)` | Mock external contract call |
| `vm.snapshot()` / `vm.revertTo()` | State snapshot and rollback |
| `vm.makeAddr(string)` | Create deterministic address |
| `vm.label(address, string)` | Label address in traces |
| `vm.expectCall(...)` | Expect a call to be made |
| `vm.getNonce(address)` | Get account nonce |
| `vm.computeCreateAddress(address, uint256)` | Predict contract address |

---

## 8. Running Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/unit/YourContract.t.sol

# Run specific test contract
forge test --match-contract YourContractTest

# Run specific test function
forge test --match-test test_Deposit_UpdatesBalance

# Run tests with pattern (regex)
forge test --match-test "test_.*Revert.*"

# Run with verbosity (show console.log)
forge test -vv

# Run with full traces (debug level)
forge test -vvvv

# Run with gas reporting
forge test --gas-report

# Run fuzz tests with more iterations
forge test --fuzz-runs 10000

# Run only fuzz tests
forge test --match-contract ".*Fuzz.*"

# Run only invariant tests
forge test --match-contract ".*Invariant.*"

# Show test traces only on failure
forge test -vvvv --show-progress

# Run tests with coverage
forge coverage

# Run coverage with detailed report
forge coverage --report lcov --report-file lcov.info
```

---

## 9. Test Coverage — Achieving >95%

### 9.1 Running Coverage

```bash
# Generate coverage report
forge coverage

# Generate in lcov format for tooling
forge coverage --report lcov --report-file coverage/lcov.info

# Ignore test files and mocks from coverage
forge coverage --no-match-coverage "test|mock|Mock"
```

### 9.2 Coverage Checklist

For each source contract, verify:

- [ ] **Every public/external function** has at least one happy path test
- [ ] **Every internal/private function** is exercised through public function tests
- [ ] **Every branch** (`if/else`, `require`, ternary) is tested in both directions
- [ ] **Every revert** is tested with the exact error/selector
- [ ] **Every event** is tested for correct emission and parameters
- [ ] **Every state variable** that changes is verified after mutation
- [ ] **Access control** is tested for both authorized and unauthorized callers
- [ ] **Edge cases** are tested: zero, max, min, empty arrays, address(0)
- [ ] **Fuzz tests** cover the general properties of state transitions
- [ ] **Invariant tests** verify system-wide guarantees

### 9.3 Interpreting Coverage Reports

```
File               | % Lines          | % Statements     | % Branches      | % Funcs
-------------------|------------------|------------------|-----------------|--------
src/YourContract.sol | 98.5% (100/102) | 97.2% (95/98)   | 95.0% (19/20)  | 100% (10/10)
```

- **Lines**: Percentage of source lines executed
- **Statements**: Percentage of individual statements executed
- **Branches**: Percentage of `if/else` paths taken
- **Funcs**: Percentage of functions called

Target: **All columns >= 95%** for each source contract.

---

## 10. Debugging Failed Tests

### Step 1: Read the Error Message

```
[FAIL] test_Withdraw_RevertWhen_InsufficientBalance()
    Error: Expected revert, but contract did not revert
```

Common error types:
- **AssertionError**: Values don't match expected
- **RevertError**: Transaction reverted unexpectedly (or didn't revert when expected)
- **OutOfGas**: Transaction ran out of gas
- **Panic**: Arithmetic overflow, division by zero, invalid array access

### Step 2: Add Debug Logging

```solidity
import {console} from "forge-std/Test.sol";

function test_DebugExample() public {
    uint256 result = target.compute();
    console.log("Result:", result);
    console.log("Expected:", 42);
    console.logAddress(target.someAddress());
    console.logUint(target.someUint());
    console.logBytes32(target.someBytes32());
    assertEq(result, 42);
}
```

Run with `-vv` to see console output:
```bash
forge test -vv --match-test test_DebugExample
```

### Step 3: Use Full Call Traces

```bash
forge test -vvvvv --match-test test_FailingTest
```

This shows:
- Every function call in the execution path
- Parameters passed to each call
- Return values
- Revert reasons and error selectors
- Gas usage per call

### Step 4: Isolate the Problem

Create a minimal test case:

```solidity
function test_MinimalRepro() public {
    // Strip down to the minimum code that still fails
    target.setupState();
    target.problematicFunction();
    // Add assertions one at a time
}
```

### Step 5: Check Common Issues

| Issue | Symptom | Fix |
|-------|---------|-----|
| Wrong `msg.sender` | `expectRevert` doesn't trigger | Use `vm.prank()` to set correct caller |
| State not updated | Assertion fails after call | Verify function is not `view`/`pure` |
| Wrong revert reason | `expectRevert("wrong")` fails | Match exact error string or selector |
| Gas limit exceeded | Transaction reverts with OOG | Check for infinite loops or heavy computation |
| Timestamp wrong | Time-dependent tests fail | Use `vm.warp()` to set correct timestamp |
| ETH balance wrong | Incorrect amounts | Remember most tokens use 18 decimals |
| Approval missing | Transfer fails | Call `approve()` before `transferFrom()` |

---

## 11. Debugging Strategies

### 11.1 State Snapshots

```solidity
function test_StateRollback() public {
    uint256 snapshot = vm.snapshot();

    target.setValue(42);
    assertEq(target.value(), 42);

    vm.revertTo(snapshot);
    assertEq(target.value(), 0); // Back to initial state
}
```

### 11.2 Event Recording

```solidity
function test_EventDebug() public {
    vm.recordLogs();
    target.emitEvent();
    Vm.Log[] memory logs = vm.getRecordedLogs();
    assertEq(logs.length, 1);
}
```

### 11.3 Expecting Calls

Verify that your contract makes the expected external calls:

```solidity
function test_MakesExternalCall() public {
    vm.expectCall(
        address(mockToken),
        abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount)
    );
    target.functionThatTransfers();
}
```

---

## 12. Best Practices

### Test Organization

1. **One test file per contract** in `test/unit/`
2. **Group tests by function** using naming conventions:
   - `test_FunctionName_Description()` for happy paths
   - `test_FunctionName_RevertWhen_Condition()` for revert cases
   - `testFuzz_FunctionName_Property()` for fuzz tests
3. **Order tests logically**: constructor/state, then each function alphabetically
4. **Use `setUp()`** for common initialization, not per-test duplication

### Test Quality

1. **Tests should be independent** — no test should depend on another test's state
2. **Use descriptive test names** — `test_Withdraw_RevertWhen_InsufficientBalance` not `test_Withdraw1`
3. **Test one thing per test function** — makes failures easier to debug
4. **Avoid magic numbers** — use named constants or descriptive variables
5. **Label addresses** for readable traces: `vm.label(user, "user")`

### Smart Contract Specific

1. **Test reentrancy** — verify `nonReentrant` modifiers work
2. **Test with real token decimals** — check the actual decimals, don't assume 18
3. **Test with multiple users** — interactions between users reveal bugs
4. **Test upgrade paths** — if using proxies, test upgrade scenarios
5. **Test gas behavior** — verify functions don't exceed block gas limits
6. **Test with `vm.prank` on edge addresses** — `address(0)`, `address(1)`, contract addresses

### Assertion Usage

```solidity
assertEq(actual, expected);      // Equality
assertNotEq(a, b);               // Not equal
assertGt(actual, expected);      // Greater than
assertGe(actual, expected);      // Greater than or equal
assertLt(actual, expected);      // Less than
assertLe(actual, expected);      // Less than or equal
assertTrue(condition);           // Boolean true
assertFalse(condition);          // Boolean false
assertApproxEqAbs(a, b, maxDelta);  // Approximate equality (absolute)
assertApproxEqRel(a, b, maxPercent); // Approximate equality (relative)
```

---

## 13. Continuous Testing Workflow

When implementing or updating smart contracts:

1. **Write tests first** or alongside the contract code
2. **Run tests frequently** after each small change: `forge test --match-contract YourContractTest`
3. **Fix failures immediately** before adding more code
4. **Verify with fuzz tests** to catch edge cases: `forge test --match-contract YourContractFuzzTest`
5. **Run full test suite** before considering work complete: `forge test`
6. **Check coverage** to ensure >95%: `forge coverage`
7. **Review gas report** if applicable: `forge test --gas-report`

---

## 14. Common Test Patterns

### 14.1 Pausable Contracts

```solidity
function test_Function_RevertWhen_Paused() public {
    target.pause();
    vm.prank(user);
    vm.expectRevert(YourContract.Paused.selector);
    target.normalFunction();
}

function test_Function_SucceedsWhenUnpaused() public {
    target.pause();
    target.unpause();
    target.normalFunction(); // Should succeed
}
```

### 14.2 Reentrancy Protection

```solidity
function test_ReentrancyGuard_PreventsReentrantCall() public {
    // Deploy a reentrant attacker contract or use vm.mockCall to simulate
    vm.expectRevert(YourContract.ReentrantCall.selector);
    attacker.attack();
}
```

### 14.3 Token Transfer Tests

```solidity
function test_TransferTokens() public {
    uint256 amount = 1000e18;
    mockToken.mint(user, amount);

    vm.prank(user);
    mockToken.transfer(recipient, amount);

    assertEq(mockToken.balanceOf(recipient), amount);
    assertEq(mockToken.balanceOf(user), 0);
}
```

### 14.4 Multi-User Interaction Tests

```solidity
function test_MultipleUsers_CanDepositAndWithdraw() public {
    address[] memory users = new address[](3);
    users[0] = makeAddr("user1");
    users[1] = makeAddr("user2");
    users[2] = makeAddr("user3");

    uint256 depositAmount = 100 ether;

    for (uint256 i = 0; i < users.length; i++) {
        vm.deal(users[i], depositAmount);
        mockWeth.deposit{value: depositAmount}();
        mockWeth.approve(address(target), depositAmount);

        vm.prank(users[i]);
        target.deposit(depositAmount);

        assertEq(target.balanceOf(users[i]), depositAmount);
    }
}
```

### 14.5 Time-Dependent Tests

```solidity
function test_TimeLock_CannotWithdrawBeforeMaturity() public {
    uint256 lockTime = 30 days;
    target.depositWithLock(1 ether, lockTime);

    // Try to withdraw before lock expires
    vm.warp(block.timestamp + 15 days);
    vm.expectRevert(YourContract.Locked.selector);
    target.withdraw(1 ether);

    // Withdraw after lock expires
    vm.warp(block.timestamp + 16 days);
    target.withdraw(1 ether);
    assertEq(target.balanceOf(address(this)), 0);
}
```
