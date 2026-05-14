# Smart Contract Security Analysis Guide

> **⚠️ LLM INSTRUCTION: DO NOT modify any files in the user's codebase.** Perform all security analysis, identify vulnerabilities, and document findings. After completing the full analysis, present the findings and **ask for explicit permission** from the user before making any changes whatsoever.

A comprehensive reference for auditing, hardening, and validating Solidity smart contracts. Read every section before beginning any security analysis. Never audit an isolated snippet — always retrieve full contract context, inheritance chain, and related tests first.

---

## 0. Pre-Audit Workflow

Before identifying vulnerabilities:

1. **Read the full architecture** — every contract, interface, and library
2. **Trace all inheritance chains** — inherited functions are attack surface
3. **Map all external calls** — every call to an untrusted address is a risk
4. **Identify all state-modifying functions** — trace all paths that change storage
5. **Identify all privileged roles** — owner, admin, operator, guardian
6. **Identify all economic flows** — deposits, withdrawals, fees, liquidations
7. **Read all existing tests** — understand intended behavior before evaluating actual behavior
8. **Understand the upgrade pattern** — proxy type, initializer, storage layout

Only after completing this workflow proceed to the vulnerability categories below.

---

## 1. Reentrancy

### 1.1 Standard Reentrancy

External calls before state updates allow a malicious contract to re-enter and exploit stale state.

```solidity
// VULNERABLE — state updated after external call
function withdraw() external {
    uint256 amount = balances[msg.sender];            // Read stale state
    (bool success,) = msg.sender.call{value: amount}(""); // Attacker re-enters here
    require(success);
    balances[msg.sender] = 0;                         // State updated too late
}

// SECURE — Checks-Effects-Interactions pattern
function withdraw() external {
    uint256 amount = balances[msg.sender];
    if (amount == 0) revert CannotWithdrawZero();
    balances[msg.sender] = 0;                         // Effect before interaction
    (bool success,) = msg.sender.call{value: amount}("");
    if (!success) revert TransferFailed();
}
```

### 1.2 Cross-Function Reentrancy

Two functions share state; an external call in one re-enters the other.

```solidity
// VULNERABLE
function deposit() external payable {
    balances[msg.sender] += msg.value;
}

function withdrawAll() external {
    uint256 amount = balances[msg.sender];
    (bool ok,) = msg.sender.call{value: amount}(""); // Attacker calls deposit() here
    balances[msg.sender] = 0;                         // Deposit already credited
}
```

### 1.3 Read-Only Reentrancy

View functions read state that is temporarily inconsistent during a callback. Other contracts integrating with your protocol may rely on these view functions.

```solidity
// VULNERABLE — price view reads state mid-update
function getPrice() external view returns (uint256) {
    return totalAssets / totalShares;  // Can be manipulated during callback
}
```

### 1.4 Callback Abuse

ERC-777 `tokensReceived`, ERC-721 `onERC721Received`, and `IERC3156FlashBorrower.onFlashLoan` are all re-entry vectors.

**Checklist:**
- [ ] All external calls follow Checks-Effects-Interactions (CEI) order
- [ ] `ReentrancyGuard` (`nonReentrant`) applied to all functions that make external calls
- [ ] `nonReentrant` applied consistently — not just to the entry function
- [ ] Cross-function reentrancy analyzed across all functions sharing storage
- [ ] Read-only reentrancy considered for view functions used by external integrators
- [ ] ERC-777, ERC-721, ERC-1155 callbacks analyzed for reentry vectors
- [ ] Flash loan callbacks analyzed for reentry vectors
- [ ] Pull payment pattern preferred over push for ETH transfers

---

## 2. Access Control

### 2.1 Missing Authorization

```solidity
// VULNERABLE — no access control on critical function
function setOracle(address newOracle) external {
    oracle = newOracle;  // Anyone can redirect price feed
}

// SECURE
function setOracle(address newOracle) external onlyOwner {
    if (newOracle == address(0)) revert ZeroAddress();
    emit OracleUpdated(oracle, newOracle);
    oracle = newOracle;
}
```

### 2.2 `tx.origin` Authentication

`tx.origin` is the original EOA that initiated the transaction. It is vulnerable to phishing attacks where a malicious contract tricks a user into calling it, which then calls your contract.

```solidity
// VULNERABLE
require(tx.origin == owner);  // Attacker contract passes this check

// SECURE
require(msg.sender == owner);
```

### 2.3 Privilege Escalation

**Checklist:**
- [ ] All `external`/`public` state-modifying functions have appropriate access control
- [ ] `msg.sender` used exclusively for authentication (never `tx.origin`)
- [ ] Two-step ownership transfer used (`Ownable2Step` from OpenZeppelin)
- [ ] Role-based access control (`AccessControl`) used for multi-admin systems
- [ ] Role assignment (`grantRole`) itself protected behind admin role
- [ ] No role can grant itself roles it does not already possess
- [ ] Constructor initializes ownership/roles correctly
- [ ] `renounceRole` / `renounceOwnership` cannot cause unrecoverable lockout
- [ ] Emergency pause capability (`Pausable`) exists for critical functions
- [ ] Admin function inputs validated (zero address, out-of-range values)

---

## 3. Integer Overflow, Underflow, and Precision

### 3.1 Overflow/Underflow

Solidity 0.8+ reverts on overflow/underflow by default. Use `unchecked` blocks only when overflow is provably impossible.

```solidity
// DANGEROUS — suppress overflow check without justification
unchecked {
    uint256 result = a + b;  // Can silently overflow if inputs are unconstrained
}

// ACCEPTABLE — only when bounds are proven
unchecked {
    // i < arr.length < 2^256, so ++i cannot overflow
    ++i;
}
```

### 3.2 Precision Loss

Division before multiplication causes precision loss. Always multiply first.

```solidity
// VULNERABLE — precision loss
uint256 fee = (amount / 100) * feeRate;  // Truncates before multiplying

// SECURE
uint256 fee = (amount * feeRate) / 100;  // Preserves precision
```

### 3.3 Unsafe Casting

```solidity
// VULNERABLE — silently truncates if value > type(uint128).max
uint256 largeValue = type(uint256).max;
uint128 small = uint128(largeValue);  // Silent truncation

// SECURE
uint128 small = SafeCast.toUint128(largeValue);  // Reverts on overflow
```

**Checklist:**
- [ ] All `unchecked` blocks have explicit comments proving overflow impossibility
- [ ] Multiplication always performed before division
- [ ] All narrowing type casts use `SafeCast` from OpenZeppelin
- [ ] Division results analyzed for rounding behavior (see Economic Analysis section)
- [ ] No mixed signed/unsigned arithmetic without explicit bounds checking
- [ ] No `uint256` to `int256` cast without range check

---

## 4. Front-Running and MEV

### 4.1 Slippage Attacks

```solidity
// VULNERABLE — no slippage protection
function swap(uint256 amountIn) external {
    uint256 amountOut = calculateOut(amountIn);  // Price can change before execution
    token.transfer(msg.sender, amountOut);
}

// SECURE
function swap(uint256 amountIn, uint256 minAmountOut) external {
    uint256 amountOut = calculateOut(amountIn);
    if (amountOut < minAmountOut) revert SlippageExceeded(amountOut, minAmountOut);
    token.transfer(msg.sender, amountOut);
}
```

### 4.2 Commit-Reveal

For auctions and lottery mechanisms where submission order creates unfair advantages, use a two-phase commit-reveal scheme.

```solidity
// Phase 1: Submit commitment
mapping(address => bytes32) public commitments;
function commit(bytes32 commitment) external {
    commitments[msg.sender] = commitment;
}

// Phase 2: Reveal
function reveal(uint256 value, bytes32 salt) external {
    bytes32 expected = keccak256(abi.encodePacked(value, salt, msg.sender));
    if (commitments[msg.sender] != expected) revert InvalidCommitment();
    // Process revealed value
}
```

**Checklist:**
- [ ] All swap/trade functions include user-specified slippage parameters (`minAmountOut`, `maxAmountIn`)
- [ ] Deadline parameters on time-sensitive operations
- [ ] Commit-reveal used for auctions and sealed-bid mechanisms
- [ ] TWAP oracles used instead of spot prices for price-sensitive operations
- [ ] No sensitive parameters derived from `block.timestamp` alone
- [ ] Sandwich attack vectors analyzed for AMM-integrated functions

---

## 5. Oracle Manipulation

### 5.1 Spot Price Manipulation

```solidity
// VULNERABLE — single-block spot price from AMM
function getPrice() external view returns (uint256) {
    (uint256 reserveA, uint256 reserveB,) = IUniswapV2Pair(pair).getReserves();
    return (reserveA * 1e18) / reserveB;  // Manipulable with flash loans
}

// SECURE — use TWAP or Chainlink
function getPrice() external view returns (uint256) {
    (, int256 answer,, uint256 updatedAt,) = priceFeed.latestRoundData();
    if (block.timestamp - updatedAt > STALE_PRICE_THRESHOLD) revert StalePrice();
    if (answer <= 0) revert InvalidPrice();
    return uint256(answer);
}
```

### 5.2 Multi-Oracle Architecture

For high-value protocols, use multiple independent oracle sources and validate agreement.

**Checklist:**
- [ ] No protocol uses spot price from a single AMM pool for collateral valuation
- [ ] Chainlink price feeds used with staleness check (`updatedAt`)
- [ ] Chainlink answer validated as positive and within expected bounds
- [ ] TWAP length appropriate for asset liquidity (longer TWAP = harder to manipulate)
- [ ] Self-referential oracle (protocol's own token prices its own collateral) avoided
- [ ] Flash loan oracle manipulation considered for all price-dependent operations
- [ ] Circuit breaker exists for extreme price deviations
- [ ] Price deviation bounds checked against secondary oracle

---

## 6. Logic and Business Logic Vulnerabilities

### 6.1 Division by Zero

```solidity
// VULNERABLE
uint256 shares = (amount * totalShares) / totalAssets;  // Reverts if totalAssets == 0

// SECURE
if (totalAssets == 0 || totalShares == 0) {
    shares = amount;  // Initial deposit: 1:1 ratio
} else {
    shares = (amount * totalShares) / totalAssets;
}
```

### 6.2 Unchecked Return Values

```solidity
// VULNERABLE
token.transfer(recipient, amount);  // ERC20 `transfer` may return false without reverting

// SECURE — use SafeERC20
token.safeTransfer(recipient, amount);  // Reverts if transfer returns false or reverts
```

### 6.3 Incorrect State Machine Transitions

```solidity
// BAD — any state can transition to any other state
enum Status { Pending, Active, Closed }
function close() external {
    status = Status.Closed;  // Works even if status is Pending (skips Active)
}

// GOOD — enforce valid transitions
function close() external {
    if (status != Status.Active) revert InvalidStateTransition(status, Status.Closed);
    status = Status.Closed;
}
```

### 6.4 First Depositor / Inflation Attack

In ERC-4626-style vaults, the first depositor can inflate the share price to steal from subsequent depositors.

```solidity
// VULNERABLE — shares = amount * totalShares / totalAssets
// Attack: deposit 1 wei, donate large amount to vault, totalAssets inflates

// SECURE MITIGATIONS:
// 1. Enforce minimum initial deposit
// 2. Use virtual offset (dead shares)
// 3. Mint initial shares to dead address (address(0xdead))
uint256 constant VIRTUAL_SHARES = 1e6;
uint256 constant VIRTUAL_ASSETS = 1;
```

**Checklist:**
- [ ] Division by zero on all divisions (both paths: zero denominator case handled)
- [ ] All ERC20 transfers use `safeTransfer` / `safeTransferFrom` (OpenZeppelin `SafeERC20`)
- [ ] All external call return values checked
- [ ] State machine transitions validated explicitly
- [ ] Fee-on-transfer tokens handled (check balance before and after transfer)
- [ ] Rebasing token behavior considered where applicable
- [ ] First depositor inflation attack mitigated in vault contracts
- [ ] `type(uint256).max` approvals safe (not vulnerable to front-run approval exploit)

---

## 7. Denial of Service (DoS)

### 7.1 Unbounded Loops

```solidity
// VULNERABLE — loops over user-controlled array
function distributeRewards() external {
    for (uint256 i = 0; i < users.length; ++i) {  // users.length unbounded
        _transfer(users[i], rewards[users[i]]);
    }
}

// SECURE — pull pattern + pagination
mapping(address => uint256) public claimable;
function claim() external {
    uint256 amount = claimable[msg.sender];
    if (amount == 0) revert NothingToClaim();
    claimable[msg.sender] = 0;
    token.safeTransfer(msg.sender, amount);
}
```

### 7.2 Push vs Pull Payments

Never use push payments (transferring to external addresses in loops). Use pull payments where each user claims their own funds.

### 7.3 External Call Failure in Critical Path

```solidity
// VULNERABLE — one failed transfer blocks all others
function batchTransfer(address[] calldata recipients, uint256 amount) external {
    for (uint256 i = 0; i < recipients.length; ++i) {
        token.transfer(recipients[i], amount);  // One revert blocks all
    }
}

// SECURE — skip failures or handle individually
function batchTransfer(address[] calldata recipients, uint256 amount) external {
    for (uint256 i = 0; i < recipients.length; ++i) {
        try token.transfer(recipients[i], amount) {} catch {
            emit TransferFailed(recipients[i], amount);
        }
    }
}
```

### 7.4 Forced ETH Rejection DoS

If your contract checks `address(this).balance` and a contract cannot receive ETH, an attacker can `selfdestruct` ETH into it.

**Checklist:**
- [ ] No unbounded loops over user-controlled arrays
- [ ] Pull payment pattern used for all reward/withdrawal mechanics
- [ ] External call failures in batch operations do not block the entire operation
- [ ] Contract logic does not depend on `address(this).balance` being exact
- [ ] `receive()` and `fallback()` defined and handle edge cases
- [ ] Gas limits considered for all loops (with N=100, N=1000 scenarios)
- [ ] Pagination or Merkle claim trees used for large distributions

---

## 8. Signature Security

### 8.1 Replay Attacks

```solidity
// VULNERABLE — signature can be replayed
function execute(address user, uint256 amount, bytes memory sig) external {
    bytes32 hash = keccak256(abi.encodePacked(user, amount));
    address recovered = ECDSA.recover(hash, sig);
    if (recovered != user) revert InvalidSignature();
    _transfer(user, amount);  // Attacker replays same sig indefinitely
}

// SECURE — EIP-712 with nonce
function execute(
    address user,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes memory sig
) external {
    if (block.timestamp > deadline) revert SignatureExpired();
    if (nonces[user] != nonce) revert InvalidNonce();

    bytes32 structHash = keccak256(
        abi.encode(EXECUTE_TYPEHASH, user, amount, nonce, deadline)
    );
    bytes32 hash = _hashTypedDataV4(structHash);
    address recovered = ECDSA.recover(hash, sig);
    if (recovered != user) revert InvalidSignature();

    nonces[user]++;
    _transfer(user, amount);
}
```

### 8.2 EIP-712 Compliance

**Checklist:**
- [ ] Nonces tracked per signer and incremented after each use
- [ ] Chain ID included in domain separator (prevents cross-chain replay)
- [ ] Contract address included in domain separator (prevents cross-contract replay)
- [ ] EIP-712 used for all structured data signing
- [ ] Signature expiry (`deadline`) enforced
- [ ] `ecrecover` return value checked (returns `address(0)` for invalid signatures)
- [ ] `ECDSA.recover` from OpenZeppelin used (validates `v` value and `s` range)
- [ ] Domain separator recomputed if contract is deployed behind a proxy that changes address
- [ ] Batch signatures validate each individual sub-message

---

## 9. Flash Loan Attacks

### 9.1 Price Manipulation via Flash Loan

```solidity
// ATTACK SCENARIO
// 1. Attacker flash-borrows large amount
// 2. Dumps tokens into AMM → price crashes
// 3. Calls your protocol's liquidation at artificially low price
// 4. Profits on liquidation bonus
// 5. Repays flash loan

// DEFENSES:
// - Use Chainlink price feeds (not AMM spot prices)
// - Use TWAP with sufficient period
// - Add price deviation circuit breaker
// - Separate price fetch from state update by at least one block
```

### 9.2 Governance Flash Loan

```solidity
// VULNERABLE — snapshot-free governance
function vote(uint256 proposalId, bool support) external {
    uint256 weight = token.balanceOf(msg.sender);  // Flash borrowed balance
    _castVote(proposalId, msg.sender, support, weight);
}

// SECURE — use snapshot-based voting weight
function vote(uint256 proposalId, bool support) external {
    uint256 snapshotBlock = proposals[proposalId].snapshotBlock;
    uint256 weight = token.getPastVotes(msg.sender, snapshotBlock);
    _castVote(proposalId, msg.sender, support, weight);
}
```

**Checklist:**
- [ ] Price oracles resistant to single-block flash loan manipulation
- [ ] Governance voting uses historical balance snapshots (not current balance)
- [ ] Collateral ratios account for asset price volatility, not just current price
- [ ] Flash loan callbacks analyzed for protocol state manipulation
- [ ] Economic cost of flash loan attack exceeds potential profit

---

## 10. Proxy and Upgrade Vulnerabilities

### 10.1 Storage Collisions

In upgradeable proxies, the proxy and implementation share storage slots. Collisions corrupt state.

```solidity
// DANGEROUS — implementation slot 0 collides with proxy admin slot 0
contract ProxyAdmin {
    address admin;  // slot 0
}
contract Implementation {
    address token;  // slot 0 — COLLISION!
}

// SECURE — use ERC-1967 randomized slots
bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
```

### 10.2 Unprotected Initializers

```solidity
// VULNERABLE — can be called multiple times
function initialize(address _owner) external {
    owner = _owner;
}

// SECURE — use OpenZeppelin Initializable
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

function initialize(address _owner) external initializer {
    owner = _owner;
}
```

### 10.3 Constructor in Upgradeable Contracts

```solidity
// VULNERABLE — constructor runs in implementation context, not proxy
constructor() {
    owner = msg.sender;  // Sets implementation's storage, not proxy's
}

// SECURE — disable initializers in implementation constructor
constructor() {
    _disableInitializers();
}
```

**Checklist:**
- [ ] Storage layout documented and versioned between upgrades
- [ ] ERC-1967 randomized slots used for proxy admin and implementation addresses
- [ ] `initializer` modifier on `initialize()` prevents re-initialization
- [ ] `_disableInitializers()` called in implementation constructors
- [ ] `delegatecall` targets whitelisted — no arbitrary `delegatecall`
- [ ] Storage gaps (`uint256[50] private __gap`) reserved in all base contracts
- [ ] Upgrade authorization restricted to timelock or multisig
- [ ] UUPS `_authorizeUpgrade` protected by access control
- [ ] No `selfdestruct` in implementation contracts
- [ ] New storage variables appended, never inserted, in upgrades

---

## 11. Cross-Chain and Bridge Vulnerabilities

**Checklist:**
- [ ] All bridge messages include origin chain ID and destination chain ID
- [ ] Replay protection: processed message hashes stored and checked
- [ ] Finality requirements met before executing cross-chain messages (not just receipt finality)
- [ ] Trusted relayers/validators validated on-chain
- [ ] Bridge failure modes do not result in fund loss (messages can be retried)
- [ ] No assumptions about block ordering or finality across chains

---

## 12. Cryptographic Vulnerabilities

### 12.1 Weak Randomness

```solidity
// VULNERABLE — miner-manipulable
function pickWinner() external view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(
        block.timestamp,   // Miner can influence ±15s
        block.prevrandao,  // PoS: validator can bias
        msg.sender
    ))) % participants.length;
}

// SECURE — use Chainlink VRF
function requestRandomWinner() external {
    uint256 requestId = COORDINATOR.requestRandomWords(
        keyHash, subscriptionId, requestConfirmations, callbackGasLimit, numWords
    );
    emit RandomnessRequested(requestId);
}
```

### 12.2 Merkle Proof Vulnerabilities

```solidity
// VULNERABLE — leaf collision with internal node
bytes32 leaf = keccak256(abi.encodePacked(account, amount));

// SECURE — double-hash to prevent second preimage attack
bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
```

**Checklist:**
- [ ] No `block.timestamp`, `block.number`, or `blockhash` used as sole randomness source
- [ ] Chainlink VRF or commit-reveal used for all on-chain randomness
- [ ] Merkle leaves double-hashed to prevent second preimage attacks
- [ ] `ecrecover` return value always validated (non-zero address check)
- [ ] Hash inputs include domain context to prevent cross-context collisions

---

## 13. Dangerous Patterns Reference

| Pattern | Risk | Secure Alternative |
|---|---|---|
| `transfer()` / `send()` for ETH | 2300 gas limit causes failures with complex receivers | `call{value: amount}("")` with return check |
| `tx.origin` auth | Phishing / relay attack | `msg.sender` |
| Spot AMM price | Flash loan manipulation | Chainlink + TWAP |
| `block.timestamp` for randomness | Miner bias | Chainlink VRF |
| `address(this).balance` checks | Force-fed ETH via `selfdestruct` | Internal accounting variable |
| Unrestricted `delegatecall` | Arbitrary storage write | Whitelisted targets only |
| `selfdestruct` in upgradeable | Destroys implementation | Remove or guard strictly |
| Low-level `call` without return check | Silent failures | Check `success` boolean |
| Inline assembly without justification | Bypasses safety checks | Solidity where possible |
| `approve(max)` pattern | Front-run allowance exploit | `safeIncreaseAllowance` or EIP-2612 permit |

---

## 14. Security Analysis Output Format

Structure all security findings using the following format:

```
## Context Retrieved
- Contracts reviewed: [list with line counts]
- External dependencies: [list]
- Attack surface: [entry points, privileged roles, external calls]

## Attack Surface Analysis
[Brief description of all external-facing functions, trust boundaries, and economic flows]

## Vulnerabilities Identified

### [SEVERITY] — [Short title]
- Category: [Reentrancy / Access Control / Oracle / etc.]
- Location: `ContractName.sol:functionName` (line N)
- Description: [What the vulnerability is and how it can be exploited]
- Impact: [What an attacker gains; likelihood and severity]
- Proof of Concept: [Minimal attack scenario in pseudocode or Solidity]
- Recommendation: [Specific, actionable fix]
- References: [SWC number, EIP, or relevant audit precedent]

## Security Patches Applied
- [File:function]: [What was changed and why]

## Security Tests Added
- [TestFile]: [Test name and what it validates]

## Validation Results
- [ ] forge build (no errors)
- [ ] forge test (all pass including new security tests)
- [ ] Exploit paths verified as mitigated

## Remaining Risks
[Known risks not yet mitigated, with justification for deferral]

## Final Security Assessment
[Overall risk rating: Critical / High / Medium / Low]
[Summary of protocol security posture]
```

**Severity Classification:**
- **Critical** — direct theft of funds, complete protocol compromise, or permanent DoS
- **High** — significant fund loss under specific conditions, broken core invariants
- **Medium** — partial fund loss, access control bypass for non-critical functions, DoS under normal conditions
- **Low** — best practice violations, edge-case issues with minimal financial impact
- **Informational** — code quality, documentation, or style issues with no direct security impact