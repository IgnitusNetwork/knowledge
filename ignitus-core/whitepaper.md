# Ignitus Protocol — Whitepaper

**IGNITUS PROTOCOL**    
**Version 1.28**    
**April 2026**  
**Ethereum Mainnet Deployment**

## 1. Abstract

Ignitus is a **fully backed, on-chain token system** consisting of three independent products, igUSD, igGOLD, and igBTC. Each product maintains its own isolated vault of real backing assets (USDC, XAUT, and WBTC respectively); it issues IG tokens at a dynamic backing-per-token ratio that can only increase under normal operation due to the permanent backing-boost mechanism.

The protocol combines:
- Deterministic minting and redemption at the on-chain backing price
- Tiered membership NFTs that reduce trading fees and grant access to fee participation rewards
- A transparent fee structure that permanently increases backing-per-token over time
- Cross-product sponsor and affiliate mechanics

All rules, pricing, fees, and membership logic are enforced exclusively by **immutable smart contracts** on Ethereum. There is no off-chain trading engine. **Prior to planned renunciation** after mainnet testing, the **factory owner** has **only narrow, deployment-ordered duties**: chiefly **updating the treasury receiving address** on the factory once the **team Treasury Vault** is deployed and configured—the Treasury Vault is **deployed after** the core Ignitus contracts so that routing can be set correctly; when configuration is complete, the **vault address is written to the factory**, and **renouncement follows**. The intended end state is **fully autonomous** on-chain economics with **no remaining admin keys**.

## 2. Problem Statement

Most tokenized assets today suffer from one or more of the following issues:
- Lack of verifiable, isolated backing
- Opaque or centralized fee mechanisms
- No clear incentive alignment between users, liquidity providers, and long-term holders
- High barriers to participation and reward sharing

Ignitus addresses these by creating **isolated, fully backed vaults** with on-chain price discovery, transparent fee distribution, and optional membership tiers that directly reward holding and participation.

## 3. Core Architecture

### 3.1 Three Independent Products

| Product   | IG Token | Backing Asset      | Backing Type     |
|-----------|----------|--------------------|------------------|
| igUSD     | ERC-20   | USDC               | Stablecoin (1:1) |
| igGOLD    | ERC-20   | Tether Gold (XAUT) | Physical gold    |
| igBTC     | ERC-20   | Wrapped Bitcoin    | Bitcoin          |

Each product operates in its own isolated vault with separate:
- IG token contract
- Backing asset vault (`totalBacking`)
- Membership NFT collection
- Fee participation accumulator

Ignitus Protocol Ethereum Addresses:
- igUSD: `0xe82D09bDb33aD258E81e1b2c89cDEbb0324C7c34`
- igGOLD: `0xF4CBc849453D64e8776862033A71E87313dF906a`
- igBTC: `0xC9E045A10D91a38E98c393e3D4A3923ea21bdde3`

### 3.2 ProtocolRouter & EcosystemFactory

- **ProtocolRouter**: Single user entrypoint for buys and refunds. Applies tier-based fee discounts and routes to the correct product.
- **EcosystemFactory**: Registers and coordinates product infrastructure (token, NFT, accumulator). Handles cross-product sponsor validation.

Non-USDC products use **Chainlink-style oracle spot** pricing for membership mint paths, with on-chain staleness bounds (see developer reference).

## 4. Token Mechanics

### 4.1 Minting & Redemption (Buy / Refund)

- **Buy**: User deposits backing asset → full amount added to `totalBacking` → IG tokens minted at current backing-per-token ratio minus protocol fee.
- **Refund (Sell)**: User burns IG tokens → receives backing asset at current ratio minus protocol fee.
- Price formula: `getPricePerToken() = (totalBacking × 1e18) / totalSupply()`

### 4.2 Fee Structure & Allocation

Base fee is 1.00%. Membership tiers reduce it:

| Tier      | Fee   |
|-----------|-------|
| None      | 1.00% |
| Bronze    | 0.90% |
| Silver    | 0.88% |
| Gold      | 0.85% |
| Platinum  | 0.83% |
| Diamond   | 0.80% |

Every fee is split as follows:
- **50%** → Permanent **backing boost** (stays in vault, no new IG minted)
- **30%** → Fee participation pool (claimable by members)
- **20%** → Protocol development treasury

This structure creates continuous upward pressure on the backing-per-token ratio.

## 5. Membership & Affiliates

Membership NFTs are **soulbound**: they **cannot be transferred to another wallet** (no secondary sale or gift of the NFT itself). Tier, product, and caps remain **fully on-chain**; optional **metadata** (NFT artwork) may be served from **ignitus.network** while traits are encoded in `tokenURI`.

- **Tiers**: Bronze → Silver → Gold → Platinum → Diamond
- **Requirements**:
  - Sequential progression
  - 50% hold of previous tier’s IG cap to upgrade
  - Valid sponsor (root affiliate or existing member)
- **Benefits**: Lower trading fees + higher participation cap in fee rewards

**Affiliate System**:
- In every new membership or upgrade, the affiliate reward to the referring member (10%–20% depending on tier) is allocated automatically.
- Sponsor is permanently recorded per product for future upgrades.

## 6. Fee Participation & Rewards

- 30% of every trade fee is minted as IG and deposited into the `FeeParticipationAccumulator`.
- Rewards use a classic reward-per-token index model.
- User’s eligible balance is capped by their highest membership tier.
- Users claim rewards directly from the pool (no additional protocol fee).

## 7. Liquidity Pools & Arbitrage Flywheel

IG tokens are freely tradable on DEX liquidity pools (when created). This creates a natural arbitrage loop:

- **DEX Market Price** vs **On-chain Backing Price**
- Arbitrageurs buy/sell IG on DEX to capture the spread
- Every trade through official Ignitus contracts applies the fee split → 50% permanent backing boost
- This steadily increases the backing-per-token ratio, widening the gap and generating new arbitrage opportunities

**The Flywheel**:
1. DEX trading moves market price
2. Arbitrage flows through Ignitus contracts
3. Backing boost increases contract price
4. Larger price gap → more arbitrage volume
5. Increased volume → more fees → stronger backing boost + member rewards
6. Member rewards → higher retention → more direct trading and membership mints

Liquidity pools do not compete with Ignitu. they **amplify** its growth mechanics.

## 8. Planned: Ignitus Vault Wallet

A self-custodial mobile wallet with:
- No seed phrases (PIN + 2FA only)
- Per-user isolated contract vaults on multiple chains
- Device-bound encrypted keys
- Deployment fees routed into ig-tokens reserves
- Cosmic brute-force security with modern bank-app convenience

This extends the flywheel by turning user adoption into additional protocol backing. *(This product vision is distinct from on-chain vault accounting inside each IG token contract.)*

## 9. Formal verification (Certora)

Core Ignitus contracts are subject to **public [Certora Prover](https://www.certora.com/)** runs: **six CVL specification files** with **pinned reports** covering, in aggregate, **25 / 25** stated rule and invariant obligations across:

| Contract | CVL spec (report linked on Security page) |
|----------|---------------------------------------------|
| `EcosystemFactory` | `ignitus-factory.spec` |
| `FeeParticipationAccumulator` | `ignitus-accumulator.spec` |
| `BackingToken` | `ignitus-backing-token.spec` |
| `USDCReserveToken` | `ignitus-usdc-reserve-token.spec` |
| `ProtocolRouter` | `ignitus-router.spec` |
| `MembershipNFT` | `ignitus-membership-nft.spec` |

**Full job names, Solidity paths, “what the proof covers,” and one-click **View Certora report** links** are maintained on the website:

**[https://ignitus.network/Security](https://ignitus.network/Security)**

Formal proofs apply to **modeled properties and environments** only; they complement (and do not replace) audits, monitoring, and economic review. Foundry fuzzing, stateful invariants, and Slither are documented on the same page.

## 10. Risks

- **Smart-contract risk**: Bugs can exist in any code; proofs and tests are scoped to stated properties.
- **Asset-issuer risk**: USDC, XAUT, and WBTC depend on their issuers
- **Market volatility**: igGOLD and igBTC track volatile assets
- **Irreversibility**: All actions are final on-chain
- **Governance transition**: Until planned renunciation after mainnet testing, limited owner capabilities exist for configuration only. In practice, primarily setting the treasury receiving address after the team Treasury Vault is live. After renounce, no admin keys, pause functions, or rescue mechanisms will remain.

Users should only risk capital they can afford to lose.

## 11. Conclusion

Ignitus combines fully backed assets, transparent on-chain mechanics, and incentive-aligned membership into a self-reinforcing ecosystem. The protocol is designed for long-term holders, arbitrageurs, and participants who value verifiable backing and deterministic rules over centralized promises.

All core contracts are open-source, backed by **public Certora verification** (see **[Security / Certora](https://ignitus.network/Security)**), heavy Foundry testing, and planned **post-deployment renunciation** where applicable. The Ignitus protocol is deployed on **Ethereum mainnet**; verify live addresses in `deployments/mainnet.json` and the app registry. Multi-chain expansion may follow through the Vault Wallet roadmap.

---

