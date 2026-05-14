# Smart Contract Optimization & Analysis Guide

> **⚠️ LLM INSTRUCTION: DO NOT modify any files in the user's codebase.** Perform all analysis, identify optimizations, and document issues. After completing the full analysis, present the findings and **ask for explicit permission** from the user before making any changes whatsoever.

A comprehensive reference for analyzing, optimizing, and improving Solidity smart contract codebases. Use this guide systematically — read it fully before beginning any analysis. Every section applies unless explicitly stated otherwise.

---

## 0. Pre-Analysis Workflow

Before touching any code:

1. **Map the full architecture** — identify every contract, interface, library, and abstract base
2. **Trace inheritance chains** — understand what each contract inherits and overrides
3. **Identify all external dependencies** — OpenZeppelin, Chainlink, Uniswap, Aave, etc.
4. **Locate all entry points** — every `external` and `public` function
5. **Understand storage layout** — read every state variable before analyzing logic
6. **Read existing tests** — understand intended behavior before evaluating correctness
7. **Check `foundry.toml`** — note compiler version, optimizer settings, remappings
8. **Never analyze an isolated snippet** — always retrieve full file context first

Only after completing this workflow proceed to the sections below.

---

## 1. Gas Optimization

### 1.1 Storage Packing

EVM storage slots are 32 bytes. Variables smaller than 32 bytes can share a slot if declared consecutively. Incorrect ordering wastes slots and inflates deployment and access costs.

```solidity
// BAD — 3 slots used (96 bytes wasted)
uint128 public valueA;   // slot 0
uint256 public valueB;   // slot 1 (forces new slot)
uint128 public valueC;   // slot 2

// GOOD — 2 slots used (valueA + valueC share slot 0)
uint256 public valueB;   // slot 0
uint128 public valueA;   // slot 1 (low 128 bits)
uint128 public valueC;   // slot 1 (high 128 bits)
```

Struct packing follows the same rules:

```solidity
// BAD struct — 3 slots
struct Position {
    uint128 amount;   // slot 0
    uint256 price;    // slot 1
    uint128 fee;      // slot 2
}

// GOOD struct — 2 slots
struct Position {
    uint256 price;    // slot 0
    uint128 amount;   // slot 1 (low)
    uint128 fee;      // slot 1 (high)
}
```

**Checklist:**
- [ ] Variables that fit together are packed consecutively
- [ ] Struct members ordered for optimal slot packing
- [ ] `bool` and small integers packed alongside related variables
- [ ] `address` (20 bytes) packed with `uint96` or similar where appropriate
- [ ] No unnecessary `uint256` where smaller types + packing would save slots

### 1.2 `immutable` and `constant`

`constant` values are inlined at compile time. `immutable` values are set once in the constructor and stored in bytecode, not storage. Both avoid `SLOAD` on every access.

```solidity
// BAD — reads from storage on every call
uint256 public MAX_SUPPLY = 1_000_000e18;
address public owner;  // set once in constructor, never changes

// GOOD
uint256 public constant MAX_SUPPLY = 1_000_000e18;
address public immutable owner;
```

**Checklist:**
- [ ] All compile-time fixed values use `constant`
- [ ] All constructor-only set values use `immutable`
- [ ] All magic numbers replaced with named `constant` variables
- [ ] Protocol parameters that never change after deploy use `immutable`

### 1.3 `calldata` vs `memory`

`memory` copies data from calldata into memory (costs gas). For `external` functions that only read parameters, use `calldata`.

```solidity
// BAD — copies array into memory
function processArray(uint256[] memory arr) external pure returns (uint256) { }

// GOOD — reads directly from calldata
function processArray(uint256[] calldata arr) external pure returns (uint256) { }
```

**Checklist:**
- [ ] All `external` function parameters that are not modified use `calldata`
- [ ] Strings and bytes use `calldata` in `external` functions where not modified
- [ ] Nested structs in external functions use `calldata` where applicable

### 1.4 Storage Caching

Every `SLOAD` from cold storage costs 2100 gas; warm reads cost 100 gas. Cache storage reads in local variables when accessed multiple times.

```solidity
// BAD — multiple SLOADs for same variable
function distribute() external {
    for (uint256 i = 0; i < recipients.length; i++) {
        balances[recipients[i]] += totalReward / recipients.length;
    }
}

// GOOD — cache in memory
function distribute() external {
    uint256 length = recipients.length;           // 1 SLOAD
    uint256 reward = totalReward;                 // 1 SLOAD
    uint256 share = reward / length;
    for (uint256 i = 0; i < length; i++) {
        balances[recipients[i]] += share;
    }
}
```

**Checklist:**
- [ ] Storage variables read more than once in a function are cached locally
- [ ] Loop bounds cached before the loop begins
- [ ] Mappings accessed multiple times in one function use a local pointer or cache value
- [ ] `msg.sender` cached if used more than twice in a function

### 1.5 Loop Optimization

```solidity
// BAD — redundant length read, pre-increment slightly cheaper
for (uint256 i = 0; i < arr.length; i++) { }

// GOOD
uint256 len = arr.length;
for (uint256 i = 0; i < len; ++i) { }
```

**Checklist:**
- [ ] Loop bounds cached before iteration
- [ ] `++i` preferred over `i++` (no temporary variable)
- [ ] Unbounded loops avoided or documented with upper bounds enforced by contract logic
- [ ] Early exits (`break`, `continue`, `return`) used when appropriate
- [ ] No storage writes inside loops that could be batched after the loop
- [ ] No external calls inside loops unless strictly necessary

### 1.6 Function Visibility

```solidity
// BAD — external call overhead when called internally
function _helper() external pure returns (uint256) { return 1; }
function compute() external pure returns (uint256) {
    return this._helper();  // External call to self
}

// GOOD
function _helper() internal pure returns (uint256) { return 1; }
function compute() external pure returns (uint256) {
    return _helper();
}
```

**Checklist:**
- [ ] Functions only called internally are marked `internal` or `private`
- [ ] `private` used when function is not needed by child contracts
- [ ] No `this.func()` calls (external calls to self)
- [ ] View functions marked `view`; pure functions marked `pure`

### 1.7 Custom Errors

Custom errors save gas versus string `require` messages because they encode only a 4-byte selector (and optional parameters) rather than a full string.

```solidity
// BAD — encodes full string
require(msg.sender == owner, "Only the owner can call this function");

// GOOD — 4-byte selector only
error Unauthorized(address caller);
if (msg.sender != owner) revert Unauthorized(msg.sender);
```

**Checklist:**
- [ ] All `require` with string messages converted to custom errors
- [ ] Error names are descriptive and follow `PascalCase`
- [ ] Error parameters include useful context (amounts, addresses, expected vs actual)
- [ ] Errors defined at the file or contract level (not inside functions)

### 1.8 Data Structure Efficiency

```solidity
// BAD — O(n) lookup for membership check
address[] public users;
function isUser(address addr) external view returns (bool) {
    for (uint256 i = 0; i < users.length; i++) {
        if (users[i] == addr) return true;
    }
    return false;
}

// GOOD — O(1) lookup
mapping(address => bool) public isUser;

// When both iteration and lookup are needed — use EnumerableSet
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
```

**Checklist:**
- [ ] Mappings used for O(1) lookups
- [ ] Arrays used only when iteration order matters
- [ ] `EnumerableSet` used when both lookup and iteration are required
- [ ] Linked lists considered for ordered data with frequent insertions/deletions
- [ ] `mapping(address => mapping(address => uint256))` vs flat `mapping(bytes32 => uint256)` evaluated for gas

### 1.9 Bit Packing and Bitmaps

When managing many boolean flags, packing into a `uint256` stores 256 flags per slot instead of 256 slots.

```solidity
// BAD — 256 booleans = 256 storage slots
mapping(uint256 => bool) public isActive;

// GOOD — 256 booleans = 1 storage slot
uint256 private activeFlags;
function isActive(uint8 index) public view returns (bool) {
    return (activeFlags >> index) & 1 == 1;
}
function setActive(uint8 index, bool value) internal {
    if (value) activeFlags |= (1 << index);
    else activeFlags &= ~(uint256(1) << index);
}
```

**Checklist:**
- [ ] Boolean flag arrays evaluated for bitmap conversion
- [ ] Bitwise operations used for efficient flag toggling
- [ ] Permissions or role flags evaluated for bitmap encoding

### 1.10 Batch Operations

Expose batch functions for operations users commonly perform repeatedly, reducing per-call fixed overhead (21000 gas base fee, calldata costs).

```solidity
// BAD — requires N transactions
function approve(address spender, uint256 amount) external { }

// GOOD — one transaction for N approvals
function batchApprove(address[] calldata spenders, uint256[] calldata amounts) external {
    uint256 len = spenders.length;
    if (len != amounts.length) revert LengthMismatch();
    for (uint256 i = 0; i < len; ++i) {
        _approve(msg.sender, spenders[i], amounts[i]);
    }
}
```

**Checklist:**
- [ ] Related operations exposed as batch functions
- [ ] Multicall support provided where contract is called repeatedly
- [ ] Gas limits considered for batch operations (no unbounded batch sizes)

### 1.11 Short-Circuit Evaluation

Place cheaper checks before expensive ones in `&&` and `||` chains. Solidity short-circuits evaluation.

```solidity
// BAD — expensive SLOAD before cheap comparison
if (balances[msg.sender] > 0 && msg.sender != address(0)) { }

// GOOD — cheap check first
if (msg.sender != address(0) && balances[msg.sender] > 0) { }
```

**Checklist:**
- [ ] Cheap conditions (comparisons against constants, `address(0)` checks) evaluated first
- [ ] External calls placed last in conditional chains

---

## 2. Code Quality

### 2.1 Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Contract | PascalCase | `LiquidityPool` |
| Interface | `I` + PascalCase | `ILiquidityPool` |
| Library | PascalCase | `FixedPointMath` |
| Function (public) | camelCase | `transferFrom` |
| Function (internal) | `_` + camelCase | `_transfer` |
| Variable (state) | camelCase | `totalSupply` |
| Variable (storage, prefixed) | `s_` + camelCase | `s_totalSupply` |
| Variable (immutable, prefixed) | `i_` + camelCase | `i_owner` |
| Constant | UPPER_SNAKE_CASE | `MAX_SUPPLY` |
| Event | PascalCase, past tense | `TokenTransferred` |
| Error | PascalCase | `InsufficientBalance` |
| Modifier | camelCase | `onlyOwner` |
| Struct | PascalCase | `UserPosition` |
| Enum | PascalCase | `LoanStatus` |

**Checklist:**
- [ ] All naming follows the table above
- [ ] No single-letter variable names except loop indices
- [ ] No misleading names (e.g., `amount` used for a timestamp)
- [ ] Boolean variables use affirmative names (`isActive`, `hasVoted`, not `notActive`)

### 2.2 Code Organization

Recommended layout within each contract:

```
1. Type declarations (structs, enums, type aliases)
2. State variables (immutable → constant → mutable)
   - Group by: access control, protocol state, accounting, configuration
3. Events
4. Errors
5. Modifiers
6. Constructor / initializer
7. External functions
8. Public functions
9. Internal functions
10. Private functions
11. View/pure functions (external, then internal)
12. receive() and fallback()
```

**Checklist:**
- [ ] SPDX license identifier on every file
- [ ] Solidity pragma present and consistent across files
- [ ] Imports organized: external libraries → internal contracts → interfaces
- [ ] No circular imports
- [ ] Functions ordered by visibility (external → public → internal → private)
- [ ] Related functions grouped together
- [ ] No dead code (unreachable functions, unused imports, unused variables)

### 2.3 NatSpec Documentation

Every `public` and `external` function must have NatSpec. Internal and private functions should have NatSpec for complex logic.

```solidity
/// @notice Transfers `amount` tokens from `from` to `to`
/// @dev Caller must have sufficient allowance. Reverts if `to` is address(0).
/// @param from  Address to transfer tokens from
/// @param to    Address to transfer tokens to
/// @param amount Number of tokens to transfer (in wei units)
/// @return success Whether the transfer succeeded
function transferFrom(
    address from,
    address to,
    uint256 amount
) external returns (bool success) {
```

**Checklist:**
- [ ] `@notice` on every external/public function (user-facing description)
- [ ] `@dev` where implementation details are non-obvious
- [ ] `@param` for every parameter
- [ ] `@return` for every return value
- [ ] `@inheritdoc` used on overrides instead of duplicating docs
- [ ] Contract-level `@title`, `@notice`, `@author` present
- [ ] Inline comments explain non-obvious arithmetic, bit operations, or protocol decisions

### 2.4 Event Completeness

Events are the off-chain API. Every meaningful state change must emit an event.

```solidity
// BAD — silent state change
function setFee(uint256 newFee) external onlyOwner {
    fee = newFee;
}

// GOOD — observable state change
event FeeUpdated(uint256 oldFee, uint256 newFee, address updatedBy);

function setFee(uint256 newFee) external onlyOwner {
    emit FeeUpdated(fee, newFee, msg.sender);
    fee = newFee;
}
```

**Checklist:**
- [ ] Every storage mutation emits an event
- [ ] Events include old value, new value, and actor where useful
- [ ] Events use up to 3 `indexed` parameters for the most commonly filtered fields
- [ ] Critical admin actions (ownership transfer, pausing, upgrades) always emit events
- [ ] Event names use past tense (`Deposited`, `Withdrawn`, `FeeUpdated`)
- [ ] No events with redundant or misleading data

### 2.5 Error Completeness and Consistency

**Checklist:**
- [ ] Custom errors used for all revert paths
- [ ] Errors include relevant context as parameters
- [ ] Error names are consistent in style with the rest of the codebase
- [ ] No `require(false)` or empty reverts
- [ ] Errors defined at file level (accessible to tests without importing the contract internals)

### 2.6 Dead Code and Redundant Logic

**Checklist:**
- [ ] No unreachable code paths
- [ ] No unused imports, variables, or parameters
- [ ] No duplicate logic (extract to shared internal function or library)
- [ ] No commented-out code blocks (remove or track via issue)
- [ ] No `TODO` comments without a linked issue reference

---

## 3. Architecture & Design Patterns

### 3.1 Single Responsibility

Each contract should do one thing well. Large monolithic contracts are hard to audit, test, and upgrade.

**Checklist:**
- [ ] Each contract has a clear, single purpose
- [ ] Storage, logic, and configuration concerns are separated
- [ ] Utility/math logic is extracted into libraries
- [ ] Protocol flow logic is separated from token logic

### 3.2 Interface Quality

**Checklist:**
- [ ] All cross-contract interactions use interfaces, not concrete types
- [ ] Interfaces include complete NatSpec
- [ ] Interfaces do not expose implementation details
- [ ] Interface file naming uses `I` prefix (`IVault.sol`)
- [ ] Interfaces versioned if protocol expects future breaking changes

### 3.3 Inheritance and Composition

**Checklist:**
- [ ] Inheritance depth is shallow (preferably ≤3 levels)
- [ ] No diamond inheritance problems
- [ ] Overridden functions call `super` where required
- [ ] Abstract base contracts use `virtual` on overrideable functions
- [ ] Composition preferred over deep inheritance for unrelated concerns

### 3.4 Library Usage

**Checklist:**
- [ ] Reusable pure/view logic extracted into libraries
- [ ] OpenZeppelin libraries used instead of custom implementations for: `SafeERC20`, `ECDSA`, `MerkleProof`, `EnumerableSet`, `Strings`, `Math`
- [ ] Libraries declared as `library` (stateless) not as contracts
- [ ] No libraries with storage state (anti-pattern)

### 3.5 Upgradeability

**Checklist:**
- [ ] Upgrade pattern documented (Transparent, UUPS, Beacon, or none)
- [ ] `initialize()` used instead of `constructor()` if upgradeable
- [ ] `_disableInitializers()` called in proxy implementation constructors
- [ ] Storage gaps (`uint256[50] private __gap`) reserved in base contracts
- [ ] Storage layout documented and version-tracked
- [ ] No storage collisions between proxy and implementation

### 3.6 Access Control Architecture

**Checklist:**
- [ ] Role-based access control (`AccessControl`) preferred over single `Ownable` for multi-admin systems
- [ ] Roles are minimal — avoid overly broad roles
- [ ] Admin role separation: protocol admin vs pauser vs operator
- [ ] Two-step ownership transfer (`Ownable2Step`) used if single owner model
- [ ] Emergency pause functionality implemented for critical protocols

### 3.7 Protocol Extensibility

**Checklist:**
- [ ] New asset/strategy/module types can be added without full redeployment
- [ ] Hook patterns used where integrators need customization points
- [ ] Fee/parameter changes go through timelock or governance
- [ ] Circuit breakers / emergency stop mechanisms present

---

## 4. Solidity Version & Compiler Settings

### 4.1 Version Selection

**Checklist:**
- [ ] Solidity version is recent (prefer `^0.8.20` minimum)
- [ ] Pragma uses `^` range, not pinned exact version in library code
- [ ] Breaking changes reviewed when upgrading versions
- [ ] Custom errors used (requires 0.8.4+)
- [ ] `unchecked` blocks used where overflow is provably impossible (0.8.0+)
- [ ] User-defined value types considered for domain safety (0.8.8+)

### 4.2 Compiler Settings

```toml
# foundry.toml
[profile.default]
optimizer = true
optimizer_runs = 200   # Use 10000+ for deployment-heavy contracts
via_ir = true          # Better optimization, avoids "stack too deep"
```

**Optimizer runs guidance:**
- `200` — optimize for runtime execution cost (most DeFi contracts)
- `10000+` — optimize for deployment cost (rarely called contracts, factories)

**Checklist:**
- [ ] Optimizer enabled
- [ ] `optimizer_runs` tuned for expected call frequency
- [ ] `via_ir = true` for complex contracts prone to stack-too-deep errors
- [ ] All compiler warnings resolved (unused variables, shadowing, unreachable code)
- [ ] No `unchecked` blocks without proof of overflow impossibility

---

## 5. Performance Bottlenecks

### 5.1 Expensive Operations Reference

| Operation | Approximate Gas Cost | Notes |
|---|---|---|
| Cold SLOAD | 2100 | First read of a storage slot in a transaction |
| Warm SLOAD | 100 | Subsequent reads of the same slot |
| SSTORE (new) | 22100 | Setting a zero slot to non-zero |
| SSTORE (update) | 2900 | Modifying an existing non-zero value |
| SSTORE (clear) | 2900 (+ 4800 refund) | Setting non-zero slot to zero |
| External call | 700+ | Minimum overhead for any external call |
| ECDSA verify | ~3000 | `ecrecover` precompile |
| Keccak256 (32 bytes) | ~30 | Per 32-byte word |
| LOG (1 topic) | ~750 | Event emission base cost |
| Memory expansion | Quadratic | Grows quadratically after 724 bytes |

### 5.2 Common Bottleneck Patterns

**Redundant storage access:**
```solidity
// BAD — 3 SLOADs for `totalSupply`
if (totalSupply > 0) {
    shares = (amount * totalSupply) / totalAssets();
    emit Deposit(amount, totalSupply);
}

// GOOD — 1 SLOAD cached
uint256 supply = totalSupply;
if (supply > 0) {
    shares = (amount * supply) / totalAssets();
    emit Deposit(amount, supply);
}
```

**String and bytes operations:**  
Minimize string operations on-chain. Use `bytes32` identifiers instead of `string` where possible. If strings are necessary, keep them short.

**ECDSA verification:**  
Each `ecrecover` call costs ~3000 gas. For systems verifying many signatures, consider Merkle proof allowlists or EIP-1271 smart account signatures to batch verification off-chain.

### 5.3 Benchmarking

```bash
# Gas report for all tests
forge test --gas-report

# Snapshot gas usage for regression tracking
forge snapshot

# Compare against previous snapshot
forge snapshot --diff .gas-snapshot
```

**Checklist:**
- [ ] Gas costs measured for all critical user-facing functions
- [ ] `forge snapshot` committed to repo for regression tracking
- [ ] No function expected to be called in normal usage exceeds 300k gas without justification
- [ ] Batch operations tested at realistic scale (e.g., 100 users)

---

## 6. Economic & Accounting Analysis

### 6.1 Rounding Direction

Rounding errors always favor the protocol over users to prevent value extraction.

```solidity
// Deposits: round DOWN shares minted (user gets less)
shares = (amount * totalShares) / totalAssets;

// Withdrawals: round UP assets required (user pays more)
assetsRequired = (shares * totalAssets + totalShares - 1) / totalShares;
// Or use OpenZeppelin Math.ceilDiv:
assetsRequired = Math.ceilDiv(shares * totalAssets, totalShares);
```

**Checklist:**
- [ ] All division operations have explicit rounding direction comments
- [ ] Deposits/minting rounds down (user receives fewer shares)
- [ ] Withdrawals/burning rounds up (user provides more assets)
- [ ] Fee calculations round in protocol's favor
- [ ] No precision loss from division before multiplication

### 6.2 Accounting Invariants

**Checklist:**
- [ ] Sum of all user balances equals total tracked supply
- [ ] Deposited assets never exceed claimed protocol holdings
- [ ] Fee accounting does not create phantom balances
- [ ] Integer accounting never silently loses dust

### 6.3 Fee Mechanics

**Checklist:**
- [ ] Fee cannot be set to 100% (user would receive nothing)
- [ ] Fee changes have bounded effect (cap on maximum fee)
- [ ] Fee-on-transfer token behavior handled correctly
- [ ] Fee accrual and distribution are separate and auditable

### 6.4 Token Economics

**Checklist:**
- [ ] Total supply and distribution documented
- [ ] Inflation/deflation mechanisms are transparent and bounded
- [ ] Vesting and lockup schedules are enforced on-chain
- [ ] No unbounded mint capability without governance

---

## 7. Testing Quality (Analysis Perspective)

When evaluating an existing test suite:

### 7.1 Coverage Evaluation

```bash
forge coverage --no-match-coverage "test|mock|Mock|script"
```

Target: **≥95% line, statement, branch, and function coverage** for all `src/` contracts.

**Checklist:**
- [ ] Every `external` and `public` function has at least one happy path test
- [ ] Every revert path is tested with the exact error
- [ ] Every `if/else` branch is covered in both directions
- [ ] Every event is tested for correct parameters
- [ ] Fuzz tests exist for all functions accepting user-controlled numeric inputs
- [ ] Invariant tests exist for all protocol-level accounting guarantees

### 7.2 Test Quality Signals

**Checklist:**
- [ ] Tests are deterministic (no randomness without `vm.assume`)
- [ ] Tests are independent (no shared mutable state between tests)
- [ ] Assertion messages are present and meaningful
- [ ] No tests that only check that a function does not revert (they miss logic bugs)
- [ ] Gas-sensitive functions have gas snapshot tests

---

## 8. Analysis Output Format

Structure all findings using the following format:

```
## Context Retrieved
- Files inspected: [list]
- Architecture summary: [brief description]
- External dependencies: [list]

## Issues Identified
### [CATEGORY] [SEVERITY] — [Short title]
- Location: `ContractName.sol:functionName` (line N)
- Description: [What the issue is]
- Impact: [What it costs or risks]
- Recommendation: [Specific fix]

## Changes Made
- [File]: [What was changed and why]

## Why The Changes Improve The Codebase
[Explanation of tradeoffs and improvements]

## Validation Actions
- [ ] forge build (no errors)
- [ ] forge test (all pass)
- [ ] forge snapshot --diff (gas delta acceptable)

## Remaining Recommendations
[Issues not yet addressed, prioritized]

## Final Status
[Summary: ready / needs review / blocked on X]
```

Severity scale:
- **Critical** — immediate exploit or fund loss possible
- **High** — significant gas waste, broken functionality, or architectural flaw
- **Medium** — suboptimal patterns, moderate gas inefficiency, or maintainability issues
- **Low** — style issues, minor inefficiencies, missing documentation
- **Informational** — observations with no direct impact