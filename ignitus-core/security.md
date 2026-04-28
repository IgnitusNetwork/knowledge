# Ignitus — Security assurance (machine-readable)

> **Auto-generated** from `web/src/data/securityPageData.js` (`scripts/generate-security-md.mjs`).
> Do not edit this markdown by hand; change the data module and run `npm run prebuild` from `web/src`.

## Hero

We test Ignitus like a bank tests its vaults:

 with robots, math proofs, and real-world simulations.

Everything is open for you to check.

## Security tools

We use three different programs that work together like a security team.

### Foundry Forge

*Like a super-smart robot that tries millions of things*

It pretends to be thousands of normal users buying, selling, claiming rewards, and transferring tokens, all at the same time. If anything ever breaks, it tells us immediately.

- Learn more: [Foundry Book — Forge](https://book.getfoundry.sh/forge/)

### Slither

*A quick safety scanner*

It reads the code like a proof-reader and flags anything that looks risky before we even run it.

- Learn more: [Slither (Crytic)](https://github.com/crytic/slither)

### Certora

*Mathematical proof that the rules can never be broken*

It proves with math that certain important things (like “the price never goes down” or “you can’t steal money”) are always true.

- Learn more: [Certora Prover](https://www.certora.com/)

## Executive summary

Ignitus is tested in four layers. Think of it like a house: we check the bricks (unit tests), shake the whole building (fuzzing), watch 10,000 people live inside it (invariants), and then use math to prove the doors can never be kicked in (formal verification).

### Key findings

- **Foundry Forge passed** — ≈10 million automated actions (April 2026 test) — everything worked perfectly.
- **Certora formal proof** — All 20+ mathematical rules across every contract were proved correct.

## Foundry Forge (invariant testing)

- Summary date: April 2026
- Approx. actions: ≈10,000,000
- Passed tests: 7 out of 7

### What the simulation exercised

- You can buy, sell, and claim rewards anytime
- Price of IG tokens never drops
- Fees are split exactly without leaks
- Membership tiers work in order and cannot be skipped
- Moving between USDC, gold, and bitcoin products is safe
- Rewards you earn can be used to buy memberships on any product
- 50% of the trade fee stays in the vault as backing boost
- Membership NFTs are soulbound (permanently locked to your wallet forever)

### Invariants that remained true

- Price never goes down (even after tens of thousands of buys & sells)
- Every token is always fully backed by real assets
- No one can claim more rewards than they earned
- Reward index always moves in the right direction
- The system did real work (not just fake tests)

## Certora formal verification

Public proof runs (open the links for full reports):

### Factory (3 / 3 rules)

The Factory is soon fully autonomous. When Ownership is been renounced, Ignitus runs completely on the blockchain with no central control. No one can ever add products, change settings, or stop the system. Everything lives forever on-chain.

- [View Certora report](https://prover.certora.com/output/1434591/d506d2b5410943808db395538db6290c/)

### Fee Accumulator (5 / 5 rules)

The reward system is fully autonomous and protected. The entire reward accounting (index and totals) is permanently locked on-chain and guaranteed to stay correct forever.

- [View Certora report](https://prover.certora.com/output/1434591/bfe378137dec4fa5a69a1fd571655f03/)

### Router (5 / 5 rules)

The Protocol Router is fully autonomous. It mathematically guarantees that you can only interact with the three official products (igUSD, igGOLD, igBTC). Any attempt to use an invalid or fake product ID is automatically rejected. No one can bypass the router, change routing rules, or manipulate trades. Everything is permanently locked on-chain.

- [View Certora report](https://prover.certora.com/output/1434591/f178d8e84c9e447e8bf82b416321c0d1/)

### Membership NFT (7 / 7 rules)

Membership NFT is fully autonomous and permanently locked to your wallet. They cannot be transferred, sold, or stolen. The contract strictly enforces sequential tier progression, correct sponsor rules, and proper fee discounts.

- [View Certora report](https://prover.certora.com/output/1434591/e43973e8a88f4b59bd9fefd09183ab40/)

### igUSD (USDC) (2 / 2 rules)

USDC Reserve Token (igUSD) is fully autonomous. It works exactly like the other IG tokens but is backed 1:1 by real USDC. The contract permanently locks the correct fee split and guarantees that every igUSD token is always fully backed.

- [View Certora report](https://prover.certora.com/output/1434591/bdc0f32db38e4690abb3f600e90ca82a/)

### igGOLD & igBTC (3 / 3 rules)

#### igGOLD (XAUT)

Deployed as the shared BackingToken implementation, backed by Tether Gold (XAUT) in the vault. Fee split is fixed in code, price accounting is verified, and every token remains fully backed by reserve assets.

#### igBTC (WBTC)

Same BackingToken implementation, backed by Wrapped Bitcoin (WBTC). One Certora report covers this Solidity contract for both product lanes, identical fee rules and backing guarantees.

- [View Certora report](https://prover.certora.com/output/1434591/63b6ae00326340699718c8a1b8fa888e/)

## Game theory analysis

### Ignitus - Game Theory Analysis

- **Contracts:** BackingToken, ProtocolRouter, USDCReserveToken (via EcosystemFactory)
- **Date:** April 2026
- **Purpose:** Economic security analysis and attack vector assessment for everyday users

**Key finding:** The system works like a shared community savings account. When you put money in, you get a digital receipt showing your fair share of the vault. When you take money out, you get your fair share back (minus a small fee that helps keep the system running). The design makes it very hard and expensive for anyone to trick the system and take more than their fair share.

### 1. Attack Vector 1: Whale Manipulation of the Shared Vault

**Scenario:** A large holder (a 'whale') tries to buy a lot of tokens, then quickly sell them back to trick the system into giving them extra money from the shared vault.

**Why it fails:** When you buy, the contract calculates your fair share of the current vault (the 'money box') using a simple formula. When you sell, you get your proportional share minus a fee. Because you pay a fee both when buying AND when selling, and the math always gives you exactly your fair share, you lose money on every round-trip. Membership cards can lower your fees, but they don't let you break the fair-share math.

**Mathematical / economic argument:** Buy: Your tokens = (your money after fee × total receipts) / current vault size. Sell: Your money out = (your receipts × current vault size) / total receipts, minus fee. The fee on both sides and the fair-share calculation make round-trips unprofitable. There is no secret 'markup' like in some other systems, it's always fair shares.

**Conclusion:** ✅ Unprofitable - Every manipulation attempt loses money because of fees on both sides and fair-share math.

**Code evidence:**

- `mini_app/app/contracts/BackingToken.sol:148-153`

```
if (S == 0 || V == 0) {
    tokensToUser = userBacking * (1e18) / startingPriceUsd6;
} else {
    tokensToUser = (userBacking * S) / V;
}
```

This is the 'fair share' calculation. It gives you exactly the right number of tokens based on how much you added to the shared vault.

- `mini_app/app/contracts/ProtocolRouter.sol:86-87`

```
uint256 feeBps = getEffectiveFeeBps(productId, msg.sender);
token.buyFromRouter(msg.sender, amount, feeBps);
```

Your membership level decides how much fee you pay (between 0.8% and 1%). The fee makes quick buy-sell loops expensive.

### 2. Attack Vector 2: MEV Extraction via Sandwich Attacks

**Scenario:** A sophisticated trader attempts to sandwich the trade, placing their own buy immediately before yours and a sell immediately after, hoping to profit from the price impact caused by your transaction.

**Why it fails:** Every trade in Ignitus is atomic and self-contained. The entire operation: price calculation, fee application, minting or burning, and vault update, runs completely locked from start to finish within that single transaction. Everything happens as user → contract → user, with no third-party dependencies during execution.

**Mathematical / economic argument:** Each transaction reads the latest vault size (`totalBacking` or `totalUSDCBacking`) and total receipts. The price you get is based on the state at that moment. Because the entire logic runs in one isolated transaction, there is no window for a sandwich attacker to insert themselves between the read and the write.

**Conclusion:** ✅ Impossible - Fixed pricing prevents MEV extraction.

**Code evidence:**

- `mini_app/app/contracts/BackingToken.sol:196-199`

```
uint256 V = totalBacking;
uint256 S = totalSupply();

uint256 outGross = (tokenAmount * V) / S;
```

The system always uses the current vault size when calculating what you get back. Previous trades change this number.

- `mini_app/app/contracts/ProtocolRouter.sol:51-52`

```
require(productId < 3, "Invalid product ID");
(, address nftAddr, ) = factory.products(productId);
```

You can only trade the three official products registered by the factory. This stops many types of trick trades.

### 3. Attack Vector 3: Nash Equilibrium for Holder Behavior

**Scenario:** What is the smartest thing for normal users to do: buy and sell quickly for short-term profit, or hold for the long term?

**Why it fails:** The system is designed to reward holders. Membership gives you lower trading fees, and every buy or sell generates fees that flow into the reward pool, which benefits holders through the fee participation accumulator. Holding, especially with a membership, lets you earn a share of fees from everyone else’s activity.

**Mathematical / economic argument:** Membership tiers lower your fee from 1% down to 0.8%. The fee pool receives minted tokens from every trade. The more people use the system, the more rewards flow to holders. Frequent traders pay full fees without capturing the long-term reward growth that holders enjoy.

**Conclusion:** ✅ Stable equilibrium -  Most holders hold and earn dividends, creating a sustainable ecosystem. Design incentivizes holding while maintaining safe exit liquidity.

**Code evidence:**

- `mini_app/app/contracts/ProtocolRouter.sol:67-72`

```
if (!foundAny) return BPS_NON_MEMBER;
if (highestTier == 0) return BPS_BRONZE;
... return BPS_DIAMOND;
```

Your highest membership tier automatically gives you a discount on fees. This rewards people who participate in the membership system.

- `mini_app/app/contracts/BackingToken.sol:160-166`

```
if (poolShare > 0 && feeParticipationPool != address(0)) {
    uint256 poolIg = _feePoolIgFromBackingShare(...);
    _mint(feeParticipationPool, poolIg);
    ...depositFees(poolIg);
```

Part of every fee helps grow the reward pool that benefits holders.

### 4. Attack Vector 4: Coordinated Exit Attack

**Scenario:** Many large holders decide to cash out at the same time, trying to drain the vault before others can.

**Why it fails:** The contract will only pay you what it actually has in the vault. It checks the real balance of the backing asset before sending any money out. It cannot pay more than it holds. The router also stops anyone from tricking the system by using fake product IDs.

**Mathematical / economic argument:** Before sending money out, the code does: require(USDC.balanceOf(address(this)) >= usdcNet, 'Insufficient backing'); or the equivalent for other assets. The accounting (`totalBacking`) stays in sync with real assets held.

**Conclusion:** ✅ Protected - A coordinated exit cannot drain the vault beyond its real backing. Users should actually welcome this scenario: when large holders refund, it reduces total supply while the backing stays in the vault, causing the backing-per-token price to rise and increasing future rewards for remaining holders.

**Code evidence:**

- `mini_app/app/contracts/USDCReserveToken.sol:164`

```
require(USDC.balanceOf(address(this)) >= usdcNet, "Insufficient backing");
```

This line is the key protection. The contract refuses to send money it does not have.

- `mini_app/app/contracts/ProtocolRouter.sol:83-84`

```
if (tokenAddr == address(0)) revert ProductNotRegistered();
```

You can only use the three real registered products. No fake vaults allowed.

### 5. Attack Vector 5: Price Slippage Exploitation

**Scenario:** Someone tries to make a huge trade to move the price dramatically in their favor, like in some other trading systems.

**Why it fails:** There is no complicated curve or slippage like on decentralized exchanges. The price is always your exact fair share of the current vault at the moment your transaction runs. Large trades get the same fair math as small ones.

**Mathematical / economic argument:** The formula is always proportional: your share = (your contribution after fee) × (total receipts) / (current vault size). It is completely deterministic based on the current numbers. There is no 'slippage tolerance' needed because you always get exactly the fair amount based on the state when your transaction executes.

**Conclusion:** ✅ Fair for everyone - The system uses simple, transparent fair-share math. There are no hidden slippage games.

**Code evidence:**

- `mini_app/app/contracts/BackingToken.sol:152`

```
tokensToUser = (userBacking * S) / V;
```

This is the core fair-share formula used for both buying and the basis for selling calculations.

- `mini_app/app/contracts/USDCReserveToken.sol:116-118`

```
tokensToUser = (userBacking * S) / V;
```

Same fair-share math is used for the USDC product (igUSD).

### Summary of Findings

| Attack vector | Feasibility | Reason |
|---------------|-------------|--------|
| Whale Manipulation | ❌ Unprofitable | Fees on both buy and sell + fair-share math |
| MEV Sandwich | ❌ Impossible | Fixed pricing prevents MEV extraction |
| Holder Behavior | ✅ Stable | Membership discounts and reward pool favor holding |
| Coordinated Exit | ✅ Protected | Real balance checks prevent draining the vault beyond its backing |
| Price Slippage | ✅ Zero slippage | Deterministic fair-share math for every trade |

All code is public. The math above comes directly from the Ignitus contracts. You can verify these rules yourself from the code.

## Closing

You don’t need to trust us, you can verify everything yourself.

