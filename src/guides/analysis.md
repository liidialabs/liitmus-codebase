# Smart Contract Optimization & Analysis Guide

When analyzing smart contract codebases, systematically check for the following optimization opportunities, code quality improvements, and architectural issues that don't involve security vulnerabilities.

---

## 1. Gas Optimization

### 1.1 Storage Optimization

#### Storage Packing
Pack related state variables into the same storage slot when possible.

```solidity
// Inefficient - uses 3 slots (96 bytes wasted)
uint128 public valueA;
uint256 public valueB;
uint128 public valueC;

// Efficient - uses 2 slots (valueA and valueC share one slot)
uint256 public valueB;
uint128 public valueA;
uint128 public valueC;
```

**Checklist:**
- [ ] Variables that fit together are packed in the same slot
- [ ] `uint256` used instead of smaller types unless packing is beneficial
- [ ] Struct members ordered for optimal packing
- [ ] Boolean values packed with other small types

#### Immutable and Constant Variables
```solidity
// Should be constant
uint256 public MAX_SUPPLY = 1_000_000; // Use: uint256 public constant MAX_SUPPLY = 1_000_000;

// Should be immutable
address public owner; // If set once in constructor, use: address public immutable owner;
```

**Checklist:**
- [ ] Compile-time constants declared as `constant`
- [ ] Constructor-only set values declared as `immutable`
- [ ] Magic numbers replaced with named constants

### 1.2 Memory Optimization

#### Calldata vs Memory
```solidity
// Inefficient
function processArray(uint256[] memory arr) external pure { }

// Efficient - saves copying
function processArray(uint256[] calldata arr) external pure { }
```

**Checklist:**
- [ ] Function parameters use `calldata` instead of `memory` when not modified
- [ ] Large arrays passed by reference, not copied
- [ ] Return values use appropriate types to avoid unnecessary copying

#### Memory Allocation
```solidity
// Inefficient - allocates new memory each iteration
for (uint256 i = 0; i < arr.length; i++) {
    bytes memory data = abi.encodePacked(arr[i]);
}

// More efficient
bytes memory data;
for (uint256 i = 0; i < arr.length; i++) {
    data = abi.encodePacked(arr[i]);
}
```

**Checklist:**
- [ ] Memory allocations minimized in loops
- [ ] Reused memory buffers where possible
- [ ] Unnecessary intermediate variables avoided

### 1.3 Loop Optimization

#### Avoid Storage Access in Loops
```solidity
// Inefficient - reads storage on each iteration
for (uint256 i = 0; i < users.length; i++) {
    total += balances[users[i]]; // Storage read each iteration
}

// Efficient - cache storage in memory
uint256 length = users.length; // Cache length
for (uint256 i = 0; i < length; i++) {
    total += balances[users[i]]; // Still storage read but length is cached
}
```

**Checklist:**
- [ ] Loop bounds cached before iteration
- [ ] Storage reads minimized inside loops
- [ ] Unbounded loops avoided or documented with upper bounds
- [ ] Early exits (`break`, `return`) used when appropriate

### 1.4 Function Call Optimization

#### Internal vs External
```solidity
// Inefficient - external call has overhead
function calculateA() external pure returns (uint256) { }
function calculateB() external view returns (uint256) {
    return this.calculateA(); // External call to self
}

// Efficient
function _calculateA() internal pure returns (uint256) { }
function calculateB() external view returns (uint256) {
    return _calculateA(); // Internal call
}
```

**Checklist:**
- [ ] Internal functions marked `internal` not `external`
- [ ] `private` used for functions not needed by child contracts
- [ ] Unnecessary external calls to self replaced with internal calls

#### Multicall Pattern
```solidity
// Inefficient - multiple transactions
function setA(uint256 _a) external { a = _a; }
function setB(uint256 _b) external { b = _b; }

// Efficient - single transaction
function setAB(uint256 _a, uint256 _b) external {
    a = _a;
    b = _b;
}
```

**Checklist:**
- [ ] Related operations batched into single function
- [ ] Multicall support provided for users who need atomicity

### 1.5 Data Structure Optimization

#### Use Mapping vs Array Appropriately
```solidity
// Inefficient for lookups
address[] public users; // O(n) to find user

// Efficient for lookups
mapping(address => bool) public isUser; // O(1) lookup
```

**Checklist:**
- [ ] Mappings used for frequent lookups
- [ ] Arrays used when iteration order matters
- [ ] Enumerable set used when both iteration and lookup needed
- [ ] Linked lists considered for ordered data with frequent insertions/deletions

#### Bit Manipulation
```solidity
// Using bool array - 1 byte per bool
bool public active1;
bool public active2;
bool public active3;

// Packing into uint256 - 256 bools in one slot
uint256 private activeFlags;
function isActive(uint8 index) public view returns (bool) {
    return (activeFlags >> index) & 1 == 1;
}
```

**Checklist:**
- [ ] Boolean flags packed into bitmaps when many exist
- [ ] Bitwise operations used for efficient flag management

### 1.6 Custom Errors

```solidity
// Inefficient - string error costs more gas
require(msg.sender == owner, "Only the owner can call this function");

// Efficient - custom error
error OnlyOwner();
// ...
require(msg.sender == owner, OnlyOwner());
```

**Checklist:**
- [ ] Custom errors defined instead of string require messages
- [ ] Error parameters used instead of string interpolation
- [ ] All error messages replaced with custom errors

---

## 2. Code Quality

### 2.1 Naming Conventions

**Checklist:**
- [ ] Contract names use PascalCase (`MyContract`)
- [ ] Function names use camelCase (`transferFrom`)
- [ ] Variables use camelCase (`totalSupply`)
- [ ] Constants use UPPER_SNAKE_CASE (`MAX_SUPPLY`)
- [ ] Internal functions prefixed with underscore (`_transfer`)
- [ ] Event names use PascalCase (`Transfer`)
- [ ] Error names use PascalCase (`InsufficientBalance`)
- [ ] Interface names prefixed with `I` (`IERC20`)

### 2.2 Code Organization

**Recommended Structure:**
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 1. Imports (external → internal)
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CustomMath} from "../utils/CustomMath.sol";

// 2. Custom errors
error InsufficientBalance(uint256 available, uint256 required);

// 3. Interfaces
interface IMyInterface { }

// 4. Library definitions
library MyLib { }

// 5. Contract definition
contract MyContract {
    // 6. State variables (immutable → constant → mutable)
    address public immutable owner;
    uint256 public constant MAX_SUPPLY = 1_000_000;
    uint256 public totalSupply;

    // 7. Events
    event Transfer(address from, address to, uint256 amount);

    // 8. Constructor
    constructor(address _owner) {
        owner = _owner;
    }

    // 9. External functions
    function externalFunc() external { }

    // 10. Public functions
    function publicFunc() public { }

    // 11. Internal functions
    function _internalFunc() internal { }

    // 12. Private functions
    function _privateFunc() private { }

    // 13. Receive and fallback
    receive() external payable { }
}
```

**Checklist:**
- [ ] SPDX license identifier present
- [ ] Solidity version pragma specified with appropriate range
- [ ] Imports organized by source (external → internal)
- [ ] Functions ordered by visibility (external → private)
- [ ] Related functions grouped together

### 2.3 Documentation

```solidity
/// @notice Transfers tokens from sender to recipient
/// @dev Internal function for token transfer logic
/// @param from Address to transfer tokens from
/// @param to Address to transfer tokens to
/// @param amount Number of tokens to transfer
/// @return success Whether the transfer succeeded
function _transfer(address from, address to, uint256 amount) internal returns (bool success) {
```

**Checklist:**
- [ ] NatSpec comments on all public/external functions
- [ ] `@notice` explains what function does (user-facing)
- [ ] `@dev` explains implementation details (developer-facing)
- [ ] `@param` documented for all parameters
- [ ] `@return` documented for return values
- [ ] Complex logic explained with inline comments
- [ ] TODO comments with issue references for incomplete code

---

## 3. Architecture & Design Patterns

### 3.1 Modularity

**Checklist:**
- [ ] Single responsibility principle applied (one contract = one purpose)
- [ ] Reusable logic extracted into libraries
- [ ] Interfaces defined for contract interactions
- [ ] Inheritance hierarchy is shallow and clear
- [ ] OpenZeppelin contracts used instead of custom implementations where appropriate

### 3.2 Upgradeability Patterns

**Checklist:**
- [ ] Transparent proxy or UUPS pattern chosen and documented
- [ ] Storage layout compatible with upgrade path
- [ ] Initializer pattern used instead of constructor
- [ ] Storage gaps reserved for future versions
- [ ] Version control mechanism in place

### 3.3 Event Emission

```solidity
// Insufficient events
function setValue(uint256 _value) external {
    value = _value; // No event emitted
}

// Good - event emitted
event ValueChanged(uint256 oldValue, uint256 newValue, address changedBy);

function setValue(uint256 _value) external {
    emit ValueChanged(value, _value, msg.sender);
    value = _value;
}
```

**Checklist:**
- [ ] All state changes emit events
- [ ] Events include relevant context (old value, new value, who changed)
- [ ] Events indexed appropriately (up to 3 indexed parameters)
- [ ] Critical actions logged (ownership changes, pausing, upgrades)
- [ ] Event names follow convention (past tense: `Transferred`, `Updated`)

---

## 4. Solidity Version & Compatibility

### 4.1 Version Selection

**Checklist:**
- [ ] Solidity version is recent (0.8.20+ for latest features)
- [ ] Version pragma uses range (`^0.8.20`) not exact (`0.8.20`)
- [ ] Breaking changes reviewed when upgrading version
- [ ] Custom errors available (0.8.4+)
- [ ] User-defined value types available (0.8.8+)
- [ ] EIP-712 support available (0.8.16+)

### 4.2 Compiler Settings

```solidity
// Foundry: foundry.toml
[profile.default]
optimizer = true
optimizer_runs = 200
via_ir = true

// Hardhat: hardhat.config.ts
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: { enabled: true, runs: 200 },
      viaIR: true,
    },
  },
};
```

**Checklist:**
- [ ] Optimizer enabled
- [ ] Optimizer runs configured for expected usage (low: 10000+ for deployment-heavy, high: 200 for execution-heavy)
- [ ] `viaIR` used for complex contracts to avoid stack too deep errors
- [ ] Compiler warnings addressed (no unused variables, no shadowing)

---

## 5. Testing Quality

### 5.1 Test Coverage

**Checklist:**
- [ ] All public/external functions have tests
- [ ] Happy path tested for each function
- [ ] Edge cases tested (zero values, max values, empty arrays)
- [ ] Revert conditions tested
- [ ] Access control tested (owner vs non-owner)
- [ ] Fuzz tests for parameterized inputs
- [ ] Invariant tests for critical properties
- [ ] Gas usage measured for expensive functions

### 5.2 Test Structure

**Checklist:**
- [ ] Test files organized by contract
- [ ] Setup/teardown properly implemented
- [ ] Test names describe expected behavior
- [ ] Test assertions include meaningful error messages
- [ ] Mock contracts used for external dependencies

---

## 6. Performance Bottlenecks

### 6.1 Common Bottlenecks

**String Operations:**
```solidity
// Expensive - string concatenation in Solidity
function buildString(string memory a, string memory b) internal pure returns (string memory) {
    return string(abi.encodePacked(a, b));
}
```
**Recommendation:** Minimize string operations; use bytes32 identifiers instead where possible.

**ECDSA Verification:**
```solidity
// Costs ~200k+ gas per verification
require(ECDSA.recover(hash, signature) == signer, "Invalid signature");
```
**Recommendation:** Batch signature verification or use merkle proofs instead.

**Storage Writes:**
```solidity
// Each SSTORE costs 2900 gas (cold) or 2900 gas (warm, modified)
mapping(address => uint256) public balances;
balances[msg.sender] += amount;
```
**Recommendation:** Minimize storage writes; use memory caching where possible.

### 6.2 Benchmarking

```bash
# Foundry - gas report
forge test --gas-report

# Hardhat - gas reporter
REPORT_GAS=true npx hardhat test
```

**Checklist:**
- [ ] Gas costs measured for critical functions
- [ ] Gas usage compared before/after optimizations
- [ ] Block gas limit considered for complex operations
- [ ] User-facing functions optimized for low gas cost

---

## 7. Economic Analysis

### 7.1 Token Economics

**Checklist:**
- [ ] Total supply and distribution model documented
- [ ] Inflation/deflation mechanisms analyzed
- [ ] Vesting schedules properly implemented
- [ ] Fee structure sustainable
- [ ] Incentive alignment verified

### 7.2 Mechanism Design

**Checklist:**
- [ ] Reward/punishment mechanisms balanced
- [ ] No unintended incentive loops
- [ ] Game theory assumptions validated
- [ ] Edge cases in economic model considered
- [ ] Attack costs calculated and documented

---

## Analysis Workflow

1. **Read all contracts** - Understand the full architecture
2. **Identify entry points** - Map external/public functions
3. **Trace data flow** - Follow how data moves through the system
4. **Check gas patterns** - Identify storage, loop, and call optimizations
5. **Review code quality** - Naming, organization, documentation
6. **Analyze architecture** - Modularity, upgradeability, patterns
7. **Evaluate economics** - Incentives, fees, token mechanics
8. **Benchmark performance** - Measure gas costs and identify bottlenecks
9. **Document findings** - List all issues by severity (critical, high, medium, low, informational)
