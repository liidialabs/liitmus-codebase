# Smart Contract Security Analysis Guide

When analyzing smart contract codebases, systematically check for the following security issues. This guide covers critical vulnerability patterns, access control weaknesses, and economic attack vectors.

---

## 1. Reentrancy

### What to Look For
- External calls (`call`, `transfer`, `send`) before state updates
- Cross-function reentrancy (multiple functions accessing shared state)
- Cross-contract reentrancy (callbacks to untrusted contracts)
- Read-only reentrancy (reading stale state during reentrant call)

### Vulnerable Pattern
```solidity
function withdraw() external {
    uint256 amount = balances[msg.sender]; // Read state
    (bool success,) = msg.sender.call{value: amount}(""); // External call BEFORE update
    require(success);
    balances[msg.sender] = 0; // Update state AFTER external call
}
```

### Secure Pattern (Checks-Effects-Interactions)
```solidity
function withdraw() external {
    if(balances[msg.sender] == 0) revert CannotWithdrawZeroAmount(); // Check
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0; // Update state BEFORE external call 
    (bool success,) = msg.sender.call{value: amount}(""); // Interact
    require(success);
}
```

### Checklist
- [ ] All external calls happen after state mutations (Checks-Effects-Interactions pattern)
- [ ] `ReentrancyGuard` modifier used where appropriate
- [ ] `nonReentrant` covers all functions that make external calls
- [ ] Read-only reentrancy considered for view functions that might be called during callbacks
- [ ] `pull` pattern used instead of `push` for payments where possible

---

## 2. Access Control

### What to Look For
- Missing `onlyOwner` or role-based modifiers on sensitive functions
- Incorrect modifier ordering
- `tx.origin` used for authentication (vulnerable to phishing)
- Implicit trust of external contracts
- Missing input validation on admin functions

### Vulnerable Pattern
```solidity
function setContract(address _addr) external { // No access control
    trustedContract = _addr;
}

// Using tx.origin (vulnerable to relay attacks)
function withdraw() external {
    require(tx.origin == owner); // WRONG: use msg.sender
}
```

### Checklist
- [ ] All state-modifying functions have appropriate access control
- [ ] `msg.sender` used instead of `tx.origin` for authentication
- [ ] Ownership transfer uses two-step pattern (`transferOwnership` + `acceptOwnership`)
- [ ] Role-based access control (RBAC) implemented for multi-admin scenarios
- [ ] `onlyOwner` functions validated for privilege escalation
- [ ] Constructor properly initializes owner/roles
- [ ] Pausable functions can be paused in emergency

---

## 3. Integer Overflow/Underflow

### What to Look For
- Arithmetic operations on user-controlled inputs
- SafeMath usage in Solidity <0.8
- Custom math without overflow checks in Solidity 0.8+
- Casting between different integer types
- Division before multiplication (precision loss)

### Vulnerable Pattern
```solidity
// Solidity 0.7.x
function multiply(uint256 a, uint256 b) public pure returns (uint256) {
    return a * b; // Can overflow without SafeMath
}

// Precision loss
function calculate(uint256 amount) public pure returns (uint256) {
    return amount * 50 / 100; // Should be amount * 50 / 100
}
```

### Checklist
- [ ] SafeMath library used for Solidity <0.8 projects
- [ ] Custom math operations include overflow/underflow checks for Solidity 0.8+
- [ ] Multiplication performed before division to minimize precision loss
- [ ] Type casting validated for bounds (e.g., `uint256` to `uint16`)
- [ ] Exponential calculations checked for overflow

---

## 4. Front-Running & MEV

### What to Look For
- Transactions where order matters (e.g., swaps, auctions)
- Predictable transaction outcomes
- Missing slippage protection
- Block number/timestamp dependency for ordering
- Public mempool visibility of pending transactions

### Vulnerable Pattern
```solidity
function buyTokens(uint256 amount) external {
    uint256 price = getTokenPrice(); // Price based on AMM state
    // Attacker sees this in mempool, buys first, raising price
    require(msg.value >= price * amount);
    transferTokens(msg.sender, amount);
}
```

### Checklist
- [ ] Slippage tolerance parameters provided for swaps/trades
- [ ] Commit-reveal schemes used for sealed-bid auctions
- [ ] Price oracles not manipulable by single transaction
- [ ] Time-weighted average price (TWAP) used instead of spot price
- [ ] Flash loan attack vectors considered for price-dependent operations

---

## 5. Oracle Manipulation

### What to Look For
- Price fetched from single DEX pool
- Price calculated from spot reserves instead of TWAP
- Missing validation of oracle data
- Self-oracle (token's own price calculated from its liquidity)
- Stale price data not detected

### Vulnerable Pattern
```solidity
function getCollateralValue() public view returns (uint256) {
    // Spot price from single pool - easily manipulated
    (uint256 reserveA, uint256 reserveB) = IUniswapV2Pair(pair).getReserves();
    return (reserveA * 1e18) / reserveB;
}
```

### Checklist
- [ ] Decentralized oracle used (Chainlink, etc.)
- [ ] TWAP from multiple sources if using AMM prices
- [ ] Stale price detection implemented
- [ ] Price deviation bounds checked
- [ ] Flash loan manipulation considered

---

## 6. Logic Errors & Business Logic Vulnerabilities

### What to Look For
- Incorrect fee calculations
- Missing validation of function parameters
- Incorrect state machine transitions
- Round-trip errors (deposit/withdraw mismatch)
- Unchecked return values from external calls

### Vulnerable Pattern
```solidity
function deposit() external payable {
    uint256 shares = msg.value / totalSupply(); // Division by zero if totalSupply == 0
    _mint(msg.sender, shares);
}

function execute(address target, bytes memory data) external onlyOwner {
    target.call(data); // Return value not checked
}
```

### Checklist
- [ ] Division by zero checked
- [ ] All `require` conditions have clear error messages
- [ ] External call return values checked
- [ ] State machine prevents invalid transitions
- [ ] Fee calculations rounded in favor of protocol (not users)
- [ ] Input validation for all user-provided parameters
- [ ] Boundary conditions tested (0, 1, max values)

---

## 7. Denial of Service (DoS)

### What to Look For
- Unbounded loops over user-provided data
- External calls in loops that can fail
- Gas griefing attacks on complex operations
- Contracts that rely on being able to receive ETH
- Auctions/bidding mechanisms that can be blocked

### Vulnerable Pattern
```solidity
// Unbounded loop
function distributeRewards() external {
    for (uint256 i = 0; i < users.length; i++) { // Can exceed block gas limit
        payable(users[i]).send(rewardAmount);
    }
}

// Failed send blocks contract
function withdraw() external {
    // If user's fallback reverts, this function is permanently blocked
    msg.sender.transfer(balances[msg.sender]);
}
```

### Checklist
- [ ] No unbounded loops over arrays that can grow arbitrarily
- [ ] Pull pattern used instead of push for payments
- [ ] External call failures don't block critical functions
- [ ] `receive()` and `fallback()` functions handle edge cases
- [ ] Gas limits considered for batch operations
- [ ] Pagination or chunking used for large data operations

---

## 8. Signature Replay & Missing Validation

### What to Look For
- Missing nonce tracking for signatures
- Missing chain ID validation
- Missing contract address in signed data
- Signatures that can be reused across transactions
- EIP-712 not used (raw ECDSA)

### Vulnerable Pattern
```solidity
function executeWithSignature(
    address user,
    uint256 amount,
    bytes memory signature
) external {
    bytes32 hash = keccak256(abi.encodePacked(user, amount)); // Missing nonce, chainId, address
    require(verifySignature(user, hash, signature));
    transfer(user, amount);
}
```

### Checklist
- [ ] Nonce used and incremented after each signature use
- [ ] Chain ID included in signed data
- [ ] Contract address included in signed data
- [ ] EIP-712 used for typed data signing
- [ ] Signature expiry implemented
- [ ] `ecrecover` return value checked (returns address(0) on invalid signature)

---

## 9. Flash Loan Attacks

### What to Look For
- Price calculations that don't account for temporary liquidity changes
- Governance voting based on token balance at single point
- Collateral calculations vulnerable to price manipulation
- Incentive calculations based on spot metrics

### Checklist
- [ ] Price oracles resistant to flash loan manipulation
- [ ] Voting power not based solely on instantaneous token balance
- [ ] Collateral ratios account for price volatility
- [ ] Incentive mechanisms resistant to temporary balance inflation
- [ ] Slippage checks prevent exploitation of price changes

---

## 10. Proxy & Upgrade Vulnerabilities

### What to Look For
- Storage collisions between proxy and implementation
- Missing initializer protection
- Unprotected upgrade functions
- `delegatecall` to untrusted contracts
- Constructor code that doesn't work with proxies

### Vulnerable Pattern
```solidity
contract MyContract {
    uint256 public value;

    constructor() {
        owner = msg.sender; // Constructor doesn't run in proxy context
    }

    function initialize() external {
        // Missing onlyInitializing modifier, can be called multiple times
        owner = msg.sender;
    }
}
```

### Checklist
- [ ] Storage layout documented and compatible between versions
- [ ] Initializer protected against re-initialization
- [ ] Upgrade functions restricted to authorized addresses
- [ ] No constructors used (use `initialize()` instead)
- [ ] `delegatecall` only to whitelisted/trusted contracts
- [ ] ERC-1967 storage slots used for proxy state
- [ ] Storage gaps reserved for future upgrades

---

## 11. Cross-Chain & Bridge Vulnerabilities

### What to Look For
- Message verification on bridge contracts
- Finality assumptions
- Replay protection across chains
- Incorrect domain/chain ID validation

### Checklist
- [ ] Bridge messages properly authenticated
- [ ] Replay protection implemented
- [ ] Finality requirements met before processing messages
- [ ] Chain-specific validation in place

---

## 12. Cryptographic Vulnerabilities

### What to Look For
- Weak randomness (`block.timestamp`, `block.number`, `blockhash`)
- Reusable hashes
- Missing validation of Merkle proofs
- Incorrect signature verification

### Vulnerable Pattern
```solidity
// Predictable randomness
function randomWinner() external view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 10;
}
```

### Checklist
- [ ] No `block.timestamp`, `block.number`, or `blockhash` used for randomness
- [ ] Chainlink VRF or commit-reveal used for randomness
- [ ] Merkle proofs validated with proper leaf hashing
- [ ] ECDSA signatures use EIP-712 or proper hash prefixes

---

## Security Analysis Workflow

1. **Identify entry points** - Find all `external` and `public` functions
2. **Trace state changes** - Follow how state is modified through each function
3. **Check access control** - Verify who can call each function
4. **Analyze external calls** - Identify all calls to untrusted contracts
5. **Check economic assumptions** - Verify price, balance, and incentive logic
6. **Review upgrade paths** - Check proxy and upgrade patterns
7. **Verify invariants** - Ensure critical properties always hold
8. **Consider edge cases** - Test with zero, max, and unusual values
