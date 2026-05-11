# Solidity Smart Contract Test & Debug Guide

A comprehensive reference for writing, running, debugging, and maintaining Foundry test suites for Solidity smart contracts. The target is **≥95% meaningful coverage** (line, branch, statement, and function) for all `src/` contracts. Read this guide fully before beginning.

---

## 0. Pre-Testing Workflow

Before writing a single test:

1. **Read every contract in `src/`** — understand storage layout, inheritance, and external dependencies
2. **Identify all entry points** — every `external` and `public` function
3. **Map all revert conditions** — every `require`, `revert`, `if/revert`, and custom error
4. **Identify all events** — every `emit` statement
5. **Read existing tests** — avoid duplication and understand coverage gaps
6. **Locate all mock contracts** — reuse existing mocks before writing new ones
7. **Check `foundry.toml`** — note Solidity version, optimizer settings, fuzz configuration

Only after completing this workflow begin writing tests.

---

## 1. Project Setup

```bash
# Verify Foundry is installed
forge --version

# Install all dependencies
forge install

# Verify project compiles cleanly (fix all warnings before testing)
forge build

# Run existing tests to establish baseline
forge test
```

**Checklist:**
- [ ] `forge build` succeeds with zero warnings
- [ ] Existing tests all pass before adding new ones
- [ ] `foundry.toml` reviewed for fuzz configuration

---

## 2. Directory Structure

```
test/
├── unit/               # One test file per src/ contract
│   └── ContractName.t.sol
├── fuzz/               # Property-based and stateful fuzz tests
│   └── ContractName.fuzz.t.sol
├── invariant/          # Invariant / stateful tests
│   └── ContractName.invariant.t.sol
└── mock/               # Test-only mocks not appropriate for src/mocks/
    └── MockAttacker.sol
```

**Naming conventions:**
- Unit test files: `ContractName.t.sol`
- Fuzz test files: `ContractName.fuzz.t.sol`
- Invariant test files: `ContractName.invariant.t.sol`
- Test function names:
  - Happy path: `test_FunctionName_Description()`
  - Revert cases: `test_FunctionName_RevertWhen_Condition()`
  - Fuzz: `testFuzz_FunctionName_Property(uint256 param)`
  - Invariant: `invariant_PropertyName()`

---

## 3. Unit Test Structure

### 3.1 Base Test Contract Template

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {YourContract} from "../../src/path/YourContract.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {MockWETH} from "../../src/mocks/MockWETH.sol";

contract YourContractTest is Test {
    // === Contracts ===
    YourContract public target;
    MockERC20 public token;
    MockWETH public weth;

    // === Actors ===
    address public owner;
    address public alice;
    address public bob;
    address public attacker;

    // === Constants ===
    uint256 constant INITIAL_BALANCE = 100 ether;
    uint256 constant DEPOSIT_AMOUNT = 10 ether;

    // === Events (copy from contract for expectEmit) ===
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function setUp() public {
        // Label all addresses for readable traces
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(attacker, "attacker");

        // Deploy mocks
        token = new MockERC20("Mock Token", "MCK", 18);
        weth = new MockWETH();

        // Deploy contract under test
        target = new YourContract(address(token));

        // Fund actors
        token.mint(alice, INITIAL_BALANCE);
        token.mint(bob, INITIAL_BALANCE);
        vm.deal(alice, INITIAL_BALANCE);
        vm.deal(bob, INITIAL_BALANCE);
    }
}
```

### 3.2 Constructor and Initial State

Always test that the constructor correctly initializes all state variables.

```solidity
// === Constructor / Initial State ===
function test_Constructor_SetsOwner() public view {
    assertEq(target.owner(), owner, "owner should be deployer");
}

function test_Constructor_SetsToken() public view {
    assertEq(address(target.token()), address(token), "token address mismatch");
}

function test_Constructor_InitialBalanceIsZero() public view {
    assertEq(target.totalDeposited(), 0, "initial totalDeposited should be zero");
}

function test_Constructor_RevertWhen_ZeroAddress() public {
    vm.expectRevert(YourContract.ZeroAddress.selector);
    new YourContract(address(0));
}
```

---

## 4. Testing Every Function

For **each public/external function**, write tests covering all of the following.

### 4.1 Happy Path Tests

```solidity
function test_Deposit_SuccessfulDeposit() public {
    uint256 amount = DEPOSIT_AMOUNT;

    vm.startPrank(alice);
    token.approve(address(target), amount);
    target.deposit(amount);
    vm.stopPrank();

    assertEq(target.balanceOf(alice), amount, "balance should increase by deposit amount");
    assertEq(target.totalDeposited(), amount, "totalDeposited should increase");
    assertEq(token.balanceOf(alice), INITIAL_BALANCE - amount, "alice token balance should decrease");
    assertEq(token.balanceOf(address(target)), amount, "contract should hold tokens");
}
```

### 4.2 State Change Verification

Always capture state before and after and verify the exact delta.

```solidity
function test_Deposit_UpdatesAllState() public {
    // Capture BEFORE
    uint256 aliceBalBefore = target.balanceOf(alice);
    uint256 totalBefore = target.totalDeposited();
    uint256 aliceTokenBefore = token.balanceOf(alice);

    // Execute
    vm.startPrank(alice);
    token.approve(address(target), DEPOSIT_AMOUNT);
    target.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();

    // Assert AFTER
    assertEq(target.balanceOf(alice), aliceBalBefore + DEPOSIT_AMOUNT);
    assertEq(target.totalDeposited(), totalBefore + DEPOSIT_AMOUNT);
    assertEq(token.balanceOf(alice), aliceTokenBefore - DEPOSIT_AMOUNT);
}
```

### 4.3 Event Verification

Test every event emitted by every function with correct parameters.

```solidity
function test_Deposit_EmitsDepositedEvent() public {
    vm.startPrank(alice);
    token.approve(address(target), DEPOSIT_AMOUNT);

    // Arguments: (checkTopic1, checkTopic2, checkTopic3, checkNonIndexed)
    vm.expectEmit(true, false, false, true);
    emit Deposited(alice, DEPOSIT_AMOUNT);

    target.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();
}
```

**`vm.expectEmit` guide:**
- `checkTopic1` — first `indexed` parameter
- `checkTopic2` — second `indexed` parameter
- `checkTopic3` — third `indexed` parameter
- `checkNonIndexed` — all non-indexed parameters

To record and inspect events manually:
```solidity
vm.recordLogs();
target.deposit(DEPOSIT_AMOUNT);
Vm.Log[] memory logs = vm.getRecordedLogs();
assertEq(logs.length, 1);
assertEq(logs[0].topics[0], keccak256("Deposited(address,uint256)"));
```

### 4.4 Revert Path Tests

Test every possible revert with the exact selector or message.

```solidity
// Custom error (no parameters)
function test_Deposit_RevertWhen_ZeroAmount() public {
    vm.prank(alice);
    vm.expectRevert(YourContract.ZeroAmount.selector);
    target.deposit(0);
}

// Custom error (with parameters)
function test_Deposit_RevertWhen_ExceedsLimit() public {
    uint256 limit = target.depositLimit();
    vm.prank(alice);
    vm.expectRevert(
        abi.encodeWithSelector(YourContract.ExceedsLimit.selector, limit + 1, limit)
    );
    target.deposit(limit + 1);
}

// String revert
function test_Legacy_RevertWith_String() public {
    vm.expectRevert("Only owner");
    target.legacyFunction();
}

// Panic (arithmetic)
function test_Math_RevertOnOverflow() public {
    vm.expectRevert(stdError.arithmeticError);
    target.unsafeAdd(type(uint256).max, 1);
}

// Assert a function does NOT revert
function test_Withdraw_DoesNotRevertForValidAmount() public {
    _setupAliceDeposit();
    vm.prank(alice);
    target.withdraw(DEPOSIT_AMOUNT); // Should succeed without vm.expectRevert
}
```

### 4.5 Branch Coverage

Every `if/else` must be tested in both directions. Map all branches before writing tests.

```solidity
/*
 * Function branches:
 *   1. amount == 0                          → revert ZeroAmount
 *   2. asset == stablecoin                  → stablecoin withdraw path
 *      2a. amount > revenue                 → revert InsufficientAmount
 *      2b. amount <= revenue                → success, decrement stablecoin revenue
 *   3. asset != stablecoin                  → liquidation revenue path
 *      3a. amount > revenue                 → revert InsufficientAmount
 *      3b. amount <= revenue                → success, decrement liquidation revenue
 */

function test_WithdrawRevenue_Branch_StablecoinSuccess() public { }
function test_WithdrawRevenue_Branch_StablecoinInsufficientRevenue() public { }
function test_WithdrawRevenue_Branch_LiquidationSuccess() public { }
function test_WithdrawRevenue_Branch_LiquidationInsufficientRevenue() public { }
function test_WithdrawRevenue_Branch_ZeroAmount() public { }
```

### 4.6 Access Control Tests

Test every access-controlled function from both authorized and unauthorized callers.

```solidity
function test_SetFee_SucceedsAsOwner() public {
    target.setFee(500);  // owner = address(this)
    assertEq(target.fee(), 500);
}

function test_SetFee_RevertWhen_CalledByNonOwner() public {
    vm.prank(alice);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    target.setFee(500);
}

// Role-based access control
function test_Pause_RevertWhen_CalledByNonPauser() public {
    vm.prank(alice);
    vm.expectRevert(
        abi.encodeWithSelector(
            IAccessControl.AccessControlUnauthorizedAccount.selector,
            alice,
            target.PAUSER_ROLE()
        )
    );
    target.pause();
}
```

### 4.7 Edge Cases

```solidity
// Zero values
function test_Deposit_RevertWhen_ZeroAmount() public { }
function test_Withdraw_RevertWhen_ZeroAmount() public { }

// Maximum values
function test_Deposit_MaxUint256() public { }

// Empty arrays
function test_BatchDeposit_EmptyArray_DoesNothing() public {
    target.batchDeposit(new address[](0), new uint256[](0));
    assertEq(target.totalDeposited(), 0);
}

// Address(0)
function test_Transfer_RevertWhen_ZeroRecipient() public { }

// Same address (from == to)
function test_Transfer_ToSelf() public { }

// Boundary values (off-by-one)
function test_Deposit_AtExactLimit() public { }
function test_Deposit_RevertWhen_OneBeyondLimit() public { }
```

---

## 5. Fuzz Tests

Fuzz tests go in `test/fuzz/`. They verify properties hold across a wide range of inputs.

### 5.1 Basic Fuzz Test

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YourContract} from "../../src/YourContract.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

contract YourContractFuzzTest is Test {
    YourContract public target;
    MockERC20 public token;

    function setUp() public {
        token = new MockERC20("Mock", "MCK", 18);
        target = new YourContract(address(token));
    }

    // Property: any valid deposit amount results in correct balance update
    function testFuzz_Deposit_BalanceUpdatesCorrectly(uint256 amount) public {
        // Constrain inputs to valid range
        amount = bound(amount, 1, type(uint128).max);

        token.mint(address(this), amount);
        token.approve(address(target), amount);

        uint256 balanceBefore = target.balanceOf(address(this));
        target.deposit(amount);

        assertEq(target.balanceOf(address(this)), balanceBefore + amount);
    }

    // Property: deposit followed by withdraw returns original amount (no fee scenario)
    function testFuzz_DepositWithdraw_Roundtrip(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);

        token.mint(address(this), amount);
        token.approve(address(target), amount);

        uint256 tokenBalanceBefore = token.balanceOf(address(this));
        target.deposit(amount);
        target.withdraw(amount);
        uint256 tokenBalanceAfter = token.balanceOf(address(this));

        assertEq(tokenBalanceAfter, tokenBalanceBefore, "roundtrip should return same amount");
    }
}
```

### 5.2 `bound` vs `vm.assume`

Prefer `bound` over `vm.assume`. `vm.assume` discards inputs that fail the condition (counts as a rejected run). `bound` clamps the value, resulting in more valid runs and better coverage.

```solidity
// PREFER — uses bound, all runs valid
function testFuzz_Deposit(uint256 amount) public {
    amount = bound(amount, 1, target.maxDeposit());  // Clamps to valid range
    // ...
}

// AVOID — discards runs where condition fails
function testFuzz_Deposit(uint256 amount) public {
    vm.assume(amount > 0 && amount <= target.maxDeposit());  // Wastes runs
    // ...
}

// Use vm.assume for structural/type constraints that cannot be bounded
function testFuzz_Transfer(address to) public {
    vm.assume(to != address(0) && to != address(target));  // Address constraints — OK
    // ...
}
```

### 5.3 Multi-Actor Fuzz Tests

```solidity
function testFuzz_MultiUser_BalancesNeverExceedTotalDeposited(
    uint256 aliceAmount,
    uint256 bobAmount
) public {
    aliceAmount = bound(aliceAmount, 0, 1_000_000e18);
    bobAmount = bound(bobAmount, 0, 1_000_000e18);

    token.mint(alice, aliceAmount);
    token.mint(bob, bobAmount);

    vm.prank(alice);
    token.approve(address(target), aliceAmount);
    vm.prank(alice);
    target.deposit(aliceAmount);

    vm.prank(bob);
    token.approve(address(target), bobAmount);
    vm.prank(bob);
    target.deposit(bobAmount);

    assertLe(
        target.balanceOf(alice) + target.balanceOf(bob),
        target.totalDeposited(),
        "sum of balances must not exceed totalDeposited"
    );
}
```

### 5.4 Fuzz Configuration

```toml
# foundry.toml
[fuzz]
runs = 1000          # Default: 256; increase for critical paths
seed = "0x1234"      # Deterministic seed for reproducibility
max_test_rejects = 65536

[invariant]
runs = 256
depth = 500          # Number of function calls per run
call_override = false
```

---

## 6. Invariant Tests

Invariant tests run a sequence of random function calls and assert that critical properties hold after every call.

### 6.1 Handler-Based Invariant Tests

The recommended approach: create a `Handler` contract that wraps the contract under test with bounded, valid calls.

```solidity
// test/invariant/YourContract.invariant.t.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {YourContract} from "../../src/YourContract.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

// Handler: exposes only valid, bounded actions to the fuzzer
contract YourContractHandler is Test {
    YourContract public target;
    MockERC20 public token;

    address[] public actors;
    uint256 public ghost_totalDeposited;  // Mirror of contract state for assertions

    constructor(YourContract _target, MockERC20 _token) {
        target = _target;
        token = _token;
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
        actors.push(makeAddr("actor3"));
    }

    function deposit(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1, 1_000_000e18);

        token.mint(actor, amount);
        vm.startPrank(actor);
        token.approve(address(target), amount);
        target.deposit(amount);
        vm.stopPrank();

        ghost_totalDeposited += amount;
    }

    function withdraw(uint256 actorSeed, uint256 amount) external {
        address actor = actors[actorSeed % actors.length];
        uint256 balance = target.balanceOf(actor);
        if (balance == 0) return;  // Skip invalid state
        amount = bound(amount, 1, balance);

        vm.prank(actor);
        target.withdraw(amount);

        ghost_totalDeposited -= amount;
    }
}

// Invariant test contract
contract YourContractInvariantTest is Test {
    YourContract public target;
    MockERC20 public token;
    YourContractHandler public handler;

    function setUp() public {
        token = new MockERC20("Mock", "MCK", 18);
        target = new YourContract(address(token));
        handler = new YourContractHandler(target, token);

        // Tell fuzzer to call handler functions only
        targetContract(address(handler));
    }

    // INVARIANT: totalDeposited always equals sum of all user balances
    function invariant_TotalDepositedEqualsGhostTotal() public view {
        assertEq(
            target.totalDeposited(),
            handler.ghost_totalDeposited(),
            "totalDeposited must match sum of deposits minus withdrawals"
        );
    }

    // INVARIANT: contract token balance always >= totalDeposited
    function invariant_ContractHoldsEnoughTokens() public view {
        assertGe(
            token.balanceOf(address(target)),
            target.totalDeposited(),
            "contract token balance must cover all deposits"
        );
    }

    // INVARIANT: no individual user balance exceeds totalDeposited
    function invariant_NoUserExceedsTotal() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; ++i) {
            assertLe(target.balanceOf(actors[i]), target.totalDeposited());
        }
    }
}
```

### 6.2 Common Invariants to Write

| Protocol Type | Invariant |
|---|---|
| ERC20 | `sum(balances) == totalSupply` |
| Vault / ERC-4626 | `totalAssets >= sum(shares) * exchangeRate` |
| Lending | `totalBorrowed <= totalDeposited` |
| Staking | `totalStaked == sum(userStakes)` |
| Fee Accounting | `feeAccrued >= 0` and `feeAccrued <= totalVolume * maxFeeRate` |
| Access Control | `roleMembers(ADMIN_ROLE).length >= 1` (no lockout) |

---

## 7. Security-Focused Tests

### 7.1 Reentrancy Tests

Deploy a malicious reentrant contract and verify the guard works.

```solidity
contract ReentrantAttacker {
    YourContract public target;
    uint256 public attackCount;

    constructor(address _target) {
        target = YourContract(_target);
    }

    function attack() external {
        target.withdraw(1 ether);
    }

    receive() external payable {
        ++attackCount;
        if (attackCount < 3) {
            target.withdraw(1 ether);  // Attempt reentry
        }
    }
}

function test_Withdraw_ReentrancyGuard_PreventsReentry() public {
    // Setup: fund the contract and the attacker
    vm.deal(address(target), 10 ether);
    vm.deal(address(attacker), 1 ether);

    ReentrantAttacker malicious = new ReentrantAttacker(address(target));
    vm.deal(address(malicious), 1 ether);

    vm.expectRevert(); // ReentrancyGuard should revert the nested call
    malicious.attack();

    assertEq(malicious.attackCount(), 1, "attack should only execute once");
}
```

### 7.2 Access Control Exhaustive Tests

Test every privileged function against every non-privileged role.

```solidity
address[] internal unauthorizedCallers;

function setUp() public {
    // ...
    unauthorizedCallers = [alice, bob, attacker, address(0x1337)];
}

function test_OwnerFunctions_RevertForAllUnauthorized() public {
    bytes[] memory calls = new bytes[](3);
    calls[0] = abi.encodeWithSelector(target.setFee.selector, 100);
    calls[1] = abi.encodeWithSelector(target.pause.selector);
    calls[2] = abi.encodeWithSelector(target.setOracle.selector, address(0x1));

    for (uint256 i = 0; i < unauthorizedCallers.length; ++i) {
        for (uint256 j = 0; j < calls.length; ++j) {
            vm.prank(unauthorizedCallers[i]);
            (bool success,) = address(target).call(calls[j]);
            assertFalse(success, "unauthorized call should fail");
        }
    }
}
```

### 7.3 Pausable Contract Tests

```solidity
function test_CriticalFunction_RevertWhen_Paused() public {
    target.pause();

    vm.prank(alice);
    vm.expectRevert(Pausable.EnforcedPause.selector);
    target.deposit(DEPOSIT_AMOUNT);
}

function test_CriticalFunction_SucceedsAfterUnpause() public {
    target.pause();
    target.unpause();

    vm.startPrank(alice);
    token.approve(address(target), DEPOSIT_AMOUNT);
    target.deposit(DEPOSIT_AMOUNT);  // Should succeed
    vm.stopPrank();

    assertEq(target.balanceOf(alice), DEPOSIT_AMOUNT);
}
```

### 7.4 Signature Replay Tests

```solidity
function test_Permit_RevertWhen_NonceReplayed() public {
    uint256 privateKey = 0xA11CE;
    address signer = vm.addr(privateKey);
    uint256 nonce = target.nonces(signer);
    uint256 deadline = block.timestamp + 1 hours;

    bytes32 digest = _buildPermitDigest(signer, address(target), DEPOSIT_AMOUNT, nonce, deadline);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

    // First use: succeeds
    target.permitAndDeposit(signer, DEPOSIT_AMOUNT, deadline, v, r, s);

    // Replay: reverts
    vm.expectRevert(YourContract.InvalidNonce.selector);
    target.permitAndDeposit(signer, DEPOSIT_AMOUNT, deadline, v, r, s);
}

function test_Permit_RevertWhen_Expired() public {
    uint256 privateKey = 0xA11CE;
    address signer = vm.addr(privateKey);
    uint256 deadline = block.timestamp - 1;  // Already expired

    bytes32 digest = _buildPermitDigest(signer, address(target), DEPOSIT_AMOUNT, 0, deadline);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

    vm.expectRevert(YourContract.SignatureExpired.selector);
    target.permitAndDeposit(signer, DEPOSIT_AMOUNT, deadline, v, r, s);
}
```

---

## 8. Mock Contracts

### 8.1 Using Existing Mocks

Always check for existing mocks before creating new ones:

| Mock | Location | Use For |
|---|---|---|
| `MockERC20` | `src/mocks/MockERC20.sol` | Standard ERC20 with `mint(address, uint256)` |
| `MockWETH` | `src/mocks/MockWETH.sol` | WETH with `deposit()` and `withdraw()` |
| `MockAaveV3Pool` | `src/aave/aave_v3/mocks/` | Aave V3 Pool interactions |
| `MockAaveV3Oracle` | `src/aave/aave_v3/mocks/` | Price oracle simulation |
| `MockPoolDataProvider` | `src/aave/aave_v3/mocks/` | Pool data queries |

### 8.2 `vm.mockCall` — Lightweight Mocking

```solidity
function test_WithMockedOracle() public {
    address oracle = address(0x1234);
    uint256 mockedPrice = 2000e8;

    // Mock specific call
    vm.mockCall(
        oracle,
        abi.encodeWithSelector(IOracle.latestPrice.selector),
        abi.encode(mockedPrice, block.timestamp)
    );

    // Execute function that reads the oracle
    uint256 result = target.getCollateralValue(1 ether);

    // Verify mock was used correctly
    assertEq(result, 1 ether * mockedPrice / 1e8);

    // Clear mocks after test
    vm.clearMockedCalls();
}
```

### 8.3 `vm.etch` — Bytecode Substitution

Replace a known address (e.g., mainnet token) with mock bytecode:

```solidity
function test_WithRealTokenAddress() public {
    // Deploy mock
    MockERC20 mock = new MockERC20("USDC", "USDC", 6);

    // Place mock at known USDC address
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    vm.etch(USDC, address(mock).code);

    // Now USDC calls will use mock behavior
    MockERC20(USDC).mint(alice, 1000e6);
    assertEq(MockERC20(USDC).balanceOf(alice), 1000e6);
}
```

### 8.4 `vm.expectCall` — Call Verification

```solidity
function test_Deposit_CallsTokenTransferFrom() public {
    vm.startPrank(alice);
    token.approve(address(target), DEPOSIT_AMOUNT);

    // Verify exact external call is made with correct parameters
    vm.expectCall(
        address(token),
        abi.encodeCall(IERC20.transferFrom, (alice, address(target), DEPOSIT_AMOUNT))
    );

    target.deposit(DEPOSIT_AMOUNT);
    vm.stopPrank();
}
```

---

## 9. Foundry Cheat Codes Reference

### 9.1 Context Manipulation

| Cheat Code | Description |
|---|---|
| `vm.prank(addr)` | Set `msg.sender` for the next call only |
| `vm.startPrank(addr)` | Set `msg.sender` for all subsequent calls |
| `vm.stopPrank()` | Stop `startPrank` |
| `vm.prank(addr, origin)` | Set `msg.sender` and `tx.origin` |
| `vm.warp(timestamp)` | Set `block.timestamp` |
| `vm.roll(blockNumber)` | Set `block.number` |
| `vm.fee(baseFee)` | Set `block.basefee` |
| `vm.chainId(id)` | Set `block.chainid` |
| `vm.deal(addr, amount)` | Set ETH balance |
| `vm.store(addr, slot, value)` | Write directly to storage slot |
| `vm.load(addr, slot)` | Read directly from storage slot |

### 9.2 Assertions and Expectations

| Cheat Code | Description |
|---|---|
| `vm.expectRevert()` | Expect any revert |
| `vm.expectRevert(selector)` | Expect specific custom error |
| `vm.expectRevert(bytes)` | Expect specific revert data |
| `vm.expectEmit(c1,c2,c3,cData)` | Expect event with checked fields |
| `vm.expectCall(addr, data)` | Expect a call to be made |
| `vm.expectCallMinGas(addr, data, gas)` | Expect call with min gas |

### 9.3 Account Management

| Cheat Code | Description |
|---|---|
| `makeAddr(string)` | Create deterministic address |
| `vm.label(addr, name)` | Label address in traces |
| `vm.addr(privateKey)` | Derive address from private key |
| `vm.sign(privateKey, digest)` | Sign digest, returns (v, r, s) |
| `vm.getNonce(addr)` | Get account nonce |

### 9.4 State Management

| Cheat Code | Description |
|---|---|
| `vm.snapshot()` | Take state snapshot, returns `snapshotId` |
| `vm.revertTo(snapshotId)` | Restore state to snapshot |
| `vm.record()` | Start recording storage accesses |
| `vm.accesses(addr)` | Get recorded reads/writes for address |
| `vm.recordLogs()` | Start recording emitted logs |
| `vm.getRecordedLogs()` | Get recorded logs (`Vm.Log[]`) |

### 9.5 Mocking

| Cheat Code | Description |
|---|---|
| `vm.mockCall(addr, data, retData)` | Mock a specific call |
| `vm.mockCallRevert(addr, data, revertData)` | Mock a call to revert |
| `vm.clearMockedCalls()` | Clear all active mocks |
| `vm.etch(addr, bytecode)` | Replace bytecode at address |

### 9.6 Fuzzing

| Cheat Code | Description |
|---|---|
| `vm.assume(condition)` | Discard fuzz input if false |
| `bound(value, min, max)` | Clamp fuzz input to range (prefer over assume) |

---

## 10. Running Tests

```bash
# Run full test suite
forge test

# Run specific file
forge test --match-path test/unit/YourContract.t.sol

# Run specific contract
forge test --match-contract YourContractTest

# Run specific test function
forge test --match-test test_Deposit_UpdatesBalance

# Run all revert tests
forge test --match-test ".*Revert.*"

# Run all fuzz tests
forge test --match-contract ".*Fuzz.*"

# Run all invariant tests
forge test --match-contract ".*Invariant.*"

# Verbosity levels
forge test -v        # Test names
forge test -vv       # console.log output
forge test -vvv      # Stack traces on failures
forge test -vvvv     # Full traces (all calls)
forge test -vvvvv    # Maximum trace detail

# Full trace on single failing test
forge test -vvvvv --match-test test_FailingTest

# Gas report
forge test --gas-report

# Gas snapshot (write)
forge snapshot

# Gas snapshot (compare against baseline)
forge snapshot --diff .gas-snapshot

# Coverage
forge coverage

# Coverage with detailed output
forge coverage --report lcov --report-file coverage/lcov.info

# Coverage excluding test files and mocks
forge coverage --no-match-coverage "test|mock|Mock|script"

# Fuzz with more runs
forge test --fuzz-runs 10000

# Invariant with more depth
forge test --invariant-depth 1000
```

---

## 11. Coverage — Achieving ≥95%

### 11.1 Coverage Report Interpretation

```
File                    | % Lines        | % Statements   | % Branches     | % Funcs
------------------------|----------------|----------------|----------------|--------
src/YourContract.sol    | 98.5% (100/102)| 97.2% (95/98) | 95.0% (19/20) | 100% (10/10)
```

Target: **all four columns ≥ 95%** for each source file.

### 11.2 Coverage Checklist

- [ ] Every `external`/`public` function: at least one happy path test
- [ ] Every `internal`/`private` function: exercised via public function tests
- [ ] Every `if/else` and ternary: both branches covered
- [ ] Every `require`/custom error: tested with exact selector
- [ ] Every `emit`: tested with correct parameters
- [ ] Every state variable mutation: verified before and after
- [ ] Every access control modifier: tested for authorized and unauthorized callers
- [ ] Edge cases: `0`, `type(uint256).max`, `address(0)`, empty arrays
- [ ] Fuzz tests for all user-controlled numeric inputs
- [ ] Invariant tests for all protocol-level accounting guarantees

### 11.3 Finding Uncovered Lines

```bash
# Generate lcov report
forge coverage --report lcov --report-file coverage/lcov.info

# Use genhtml to generate HTML report
genhtml coverage/lcov.info --output-directory coverage/html
# Open coverage/html/index.html in browser
```

Uncovered lines appear highlighted. Common causes:
- Missing revert path tests
- Dead code (unreachable branches)
- Missing access control tests for non-owner roles

---

## 12. Debugging Failed Tests

### 12.1 Diagnose by Error Type

| Error | Symptom | Fix |
|---|---|---|
| `AssertionError` | Values don't match | Add `console.log` before assertion to inspect state |
| `Expected revert, no revert` | Function didn't revert | Check msg.sender, state setup, and exact condition |
| `Unexpected revert` | Function reverted unexpectedly | Use `-vvvvv` to see revert reason |
| `OutOfGas` | Transaction OOG | Check for infinite loops or missing bounds |
| `Panic (0x01)` | Failed assertion | Check assertions in contract code |
| `Panic (0x11)` | Arithmetic overflow | Check for unchecked math |
| `Panic (0x12)` | Division by zero | Check denominator before division |
| `Panic (0x32)` | Array out of bounds | Check array length before indexing |

### 12.2 Debug Logging

```solidity
import {console} from "forge-std/Test.sol";

function test_Debug() public {
    uint256 result = target.compute(42);

    // Log values
    console.log("result:", result);
    console.log("expected:", 100);
    console.logAddress(target.owner());
    console.logBytes32(target.domainSeparator());

    assertEq(result, 100);
}
```

Run with `-vv` to see console output:
```bash
forge test -vv --match-test test_Debug
```

### 12.3 Full Call Traces

```bash
forge test -vvvvv --match-test test_FailingTest
```

The trace shows:
- Every function call and its caller
- Parameters and return values
- Gas used per call
- Revert reason and error selector

### 12.4 Storage Inspection

```solidity
function test_InspectStorage() public {
    // Read raw storage slot
    bytes32 slot0 = vm.load(address(target), bytes32(uint256(0)));
    console.logBytes32(slot0);

    // Write to storage directly (for test setup)
    vm.store(address(target), bytes32(uint256(1)), bytes32(uint256(9999)));
    assertEq(target.someStateVar(), 9999);
}
```

### 12.5 State Snapshots for Isolation

```solidity
function test_StateIsolation() public {
    uint256 snapshot = vm.snapshot();

    target.setValue(42);
    assertEq(target.value(), 42);

    vm.revertTo(snapshot);
    assertEq(target.value(), 0);  // State fully restored
}
```

### 12.6 Common Issues Checklist

- [ ] **Wrong `msg.sender`** — use `vm.prank()` or `vm.startPrank()`
- [ ] **Missing approval** — call `approve()` before `transferFrom()`
- [ ] **Token decimals** — verify actual decimals, don't assume 18
- [ ] **Timestamp dependency** — use `vm.warp()` to set correct timestamp
- [ ] **Block number dependency** — use `vm.roll()` to advance blocks
- [ ] **ETH balance** — use `vm.deal()` to fund addresses
- [ ] **Not calling `setUp()`** — verify contract deploys fresh each test
- [ ] **Wrong revert selector** — use `-vvvvv` to see actual vs expected selector

---

## 13. Test Patterns Library

### 13.1 Time-Locked Operations

```solidity
function test_Lock_CannotWithdrawBeforeExpiry() public {
    uint256 lockDuration = 30 days;
    _setupLockedDeposit(alice, DEPOSIT_AMOUNT, lockDuration);

    vm.warp(block.timestamp + lockDuration - 1);  // 1 second before expiry
    vm.prank(alice);
    vm.expectRevert(YourContract.StillLocked.selector);
    target.withdraw(DEPOSIT_AMOUNT);
}

function test_Lock_CanWithdrawAfterExpiry() public {
    uint256 lockDuration = 30 days;
    _setupLockedDeposit(alice, DEPOSIT_AMOUNT, lockDuration);

    vm.warp(block.timestamp + lockDuration);  // Exactly at expiry
    vm.prank(alice);
    target.withdraw(DEPOSIT_AMOUNT);
    assertEq(target.balanceOf(alice), 0);
}
```

### 13.2 Multi-User Interaction Tests

```solidity
function test_MultipleUsers_IndependentBalances() public {
    uint256 aliceAmount = 10 ether;
    uint256 bobAmount = 20 ether;

    token.mint(alice, aliceAmount);
    token.mint(bob, bobAmount);

    vm.startPrank(alice);
    token.approve(address(target), aliceAmount);
    target.deposit(aliceAmount);
    vm.stopPrank();

    vm.startPrank(bob);
    token.approve(address(target), bobAmount);
    target.deposit(bobAmount);
    vm.stopPrank();

    assertEq(target.balanceOf(alice), aliceAmount, "alice balance wrong");
    assertEq(target.balanceOf(bob), bobAmount, "bob balance wrong");
    assertEq(target.totalDeposited(), aliceAmount + bobAmount, "total wrong");
}
```

### 13.3 Upgrade Tests (Proxy Contracts)

```solidity
function test_Upgrade_StatePreservedAfterUpgrade() public {
    // Set state in V1
    target.deposit(DEPOSIT_AMOUNT);
    uint256 balanceBeforeUpgrade = target.balanceOf(address(this));

    // Upgrade to V2
    YourContractV2 implV2 = new YourContractV2();
    proxy.upgradeTo(address(implV2));
    YourContractV2 targetV2 = YourContractV2(address(proxy));

    // Verify state preserved
    assertEq(targetV2.balanceOf(address(this)), balanceBeforeUpgrade);

    // Verify new V2 functionality works
    targetV2.newFunction();
}

function test_Upgrade_RevertWhen_UnauthorizedUpgrader() public {
    YourContractV2 implV2 = new YourContractV2();
    vm.prank(alice);
    vm.expectRevert();
    proxy.upgradeTo(address(implV2));
}
```

### 13.4 Fee Calculation Tests

```solidity
function test_Fee_CalculatedCorrectly() public {
    uint256 feeBps = 50;  // 0.5%
    target.setFee(feeBps);

    uint256 depositAmount = 10_000e18;
    uint256 expectedFee = (depositAmount * feeBps) / 10_000;
    uint256 expectedNet = depositAmount - expectedFee;

    vm.startPrank(alice);
    token.mint(alice, depositAmount);
    token.approve(address(target), depositAmount);
    target.deposit(depositAmount);
    vm.stopPrank();

    assertEq(target.balanceOf(alice), expectedNet, "net balance wrong");
    assertEq(target.accruedFees(), expectedFee, "accrued fee wrong");
}

function test_Fee_RoundsInProtocolFavor() public {
    // Deposit an amount where fee is not a whole number
    uint256 depositAmount = 3;  // 3 wei * 0.5% = 0.015 wei
    uint256 feeBps = 50;
    target.setFee(feeBps);

    // Fee rounds up (ceil), user receives floor
    uint256 expectedFee = 1;  // ceil(0.015) = 1
    uint256 expectedNet = depositAmount - expectedFee;  // 2

    vm.startPrank(alice);
    token.mint(alice, depositAmount);
    token.approve(address(target), depositAmount);
    target.deposit(depositAmount);
    vm.stopPrank();

    assertEq(target.balanceOf(alice), expectedNet);
}
```

---

## 14. Best Practices Summary

### Test Organization
1. One test file per source contract, in `test/unit/`
2. Group tests by function in the order functions appear in the source contract
3. Name tests descriptively: `test_FunctionName_WhenCondition_ExpectedOutcome`
4. Use `setUp()` for shared initialization — never duplicate setup code

### Test Quality
1. Tests must be independent — no shared mutable state between tests
2. Test one behavioral property per test function
3. Always assert; never write tests that only check no revert
4. Use meaningful assertion messages as the third parameter
5. Label all addresses with `vm.label()` for readable traces

### Assertion Reference
```solidity
assertEq(actual, expected, "message");          // a == b
assertNotEq(a, b, "message");                   // a != b
assertGt(a, b, "message");                      // a > b
assertGe(a, b, "message");                      // a >= b
assertLt(a, b, "message");                      // a < b
assertLe(a, b, "message");                      // a <= b
assertTrue(condition, "message");               // condition == true
assertFalse(condition, "message");              // condition == false
assertApproxEqAbs(a, b, maxDelta, "message");   // |a - b| <= maxDelta
assertApproxEqRel(a, b, maxPct, "message");     // |a - b| / b <= maxPct (1e18 = 100%)
```

### Continuous Testing Workflow
```bash
# During development: run specific contract tests on every save
forge test --match-contract YourContractTest --watch

# Before committing: run full suite with gas snapshot
forge test && forge snapshot

# Before PR: verify coverage
forge coverage --no-match-coverage "test|mock|Mock|script"
```