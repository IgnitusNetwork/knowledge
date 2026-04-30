# Ignitus Bot Integration Guide (Autonomous On-Chain)

This guide is for developers building autonomous bots that interact **directly with Ignitus smart contracts** on Ethereum mainnet.

Use this page together with:
- [[ignitus-core/developer-reference.md]]
- Solidity mirrors (canonical for this repo): `knowledge/ignitus-core/contracts/*.sol`

---

## Scope (what this guide covers)

- **Buy / sell (refund)** IG tokens via `ProtocolRouter` (fee tier auto-applied)
- **Mint / upgrade membership** (soulbound ERC-721) via `MembershipNFT`
- **Claim fee participation rewards** via `FeeParticipationAccumulator`
- **Referrals / sponsoring**: how to supply `sponsor` correctly
- **Operational safety**: approvals, simulation, nonce/gas hygiene, monitoring

This guide does **not** cover trading strategy or profit expectations.

---

## Network and product model

- **Chain**: Ethereum mainnet
- **Chain ID**: `1`
- **Products**:
  - `0`: igUSD (USDC-backed)
  - `1`: igGOLD (XAUT-backed)
  - `2`: igBTC (WBTC-backed)

Ignitus IG tokens are minted/burned against on-chain backing vaults. Membership NFTs are **soulbound** (non-transferable) and adjust trading fees and reward caps.

---

## Canonical contract addresses (mainnet)

These addresses are the source of truth for this repo:

- **ProtocolRouter**: `0x069c0210495ADF194101C71Ff4A68140E9145Bb7`
- **EcosystemFactory** (registry): `0x655d37556a3e922133960B02BFbf4D09ac2985c2`
- **Root affiliate** (valid sponsor for first Bronze mints): `0x44Fc8743E4e8435be210C57dcAF03B393269c557`

Per product, see the full table in [[ignitus-core/developer-reference.md]].

---

## ABIs: do you need Etherscan, or can you generate them?

You have two acceptable ABI sources:

- **Recommended (deterministic / repo-local)**: generate ABIs from the mirrored Solidity sources in `knowledge/ignitus-core/contracts/`.
  - Pros: pinned to the same source used across this knowledge base.
  - Cons: you must ensure your ABI matches the deployed bytecode (see “Verification checklist” below).

- **Alternative (explorer-verified ABI)**: pull the verified ABI for each deployed contract from an explorer UI/API.
  - Pros: directly tied to the deployed contract on that explorer.
  - Cons: explorer rate limits / format drift; still verify bytecode where possible.

### Verification checklist (do this before you let a bot send value)

- **Address verification**: confirm each address matches [[ignitus-core/developer-reference.md]].
- **Bytecode verification**: confirm the address is verified on an explorer and matches expected source (or compare runtime bytecode hash against your deployment artifacts).
- **Function signature check**: confirm the bot is calling the exact functions below (correct parameter types and ordering).

---

## Core call flows (contract-level)

### 1) Buy IG tokens (deposit backing → receive IG)

**Call** (router):

`ProtocolRouter.buy(uint8 productId, uint256 amount)`

Key rules:
- You must **approve the backing ERC-20 to the product IG token contract** (not the router).
- `amount` is in **backing decimals** (USDC is 6; XAUT/WBTC use their own decimals).
- The contracts enforce a small “dust” minimum (`MIN_AMOUNT = 1_000` backing units). The **official app UI** enforces higher minimums for UX:
  - Buy minimums: **0.1 USDC** (product 0), **0.01 XAUT** (product 1), **0.001 WBTC** (product 2)

Reference: [[ignitus-core/developer-reference.md]] (section “Buy IG tokens”).

### 2) Sell (refund) IG tokens (burn IG → receive backing)

**Call** (router):

`ProtocolRouter.refund(uint8 productId, uint256 tokenAmount)`

Key rules:
- `tokenAmount` is in **18 decimals** (IG token units).
- Your fee tier is resolved by the router from your highest membership tier.
- Contracts enforce `MIN_IG_AMOUNT = 0.001 IG`, while the **official app UI** enforces **0.1 IG** minimum on sells (all products).

### 3) Mint / upgrade membership (soulbound NFT)

**Call** (on the product’s `MembershipNFT` contract):

`MembershipNFT.mintMembership(uint8 productId, uint8 desiredTier, address sponsor)`

Key rules:
- **Sequential tiers only**: `desiredTier` must equal `nextTierToBuy[productId][user]`.
- `sponsor` must be valid:
  - For first Bronze (`desiredTier == 0`): `sponsor` must be either the **root affiliate** or an address that already holds membership.
  - For upgrades (`desiredTier > 0`): `sponsor` must pass `isValidSponsor(...)`.
- The NFT contract pulls backing during mint: you must have approved the backing asset to the **IG token contract** (same approval target as buys).

### 4) Claim fee participation rewards

**Call** (on the product’s accumulator):

`FeeParticipationAccumulator.claim()`

Recommended reads:
- `pendingRewards(address user)` to check claimable amount before sending a transaction.

---

## Approvals (common failure point)

For buys and membership mints, the allowance must be:

`backingAsset.approve(igTokenAddress, amount)`

Not:
- approving the router, or
- approving the membership NFT.

If your bot supports “infinite approvals”, treat it as a risk decision and document it (many teams prefer exact approvals per action).

---

## Referral / sponsoring behavior (practical bot rules)

Your bot should treat `sponsor` as:

- **An address** (not a tokenId) when calling `MembershipNFT.mintMembership(...)`.
- For “link-based referrals” (UI flows), you may resolve a sponsor from a membership token, but the on-chain mint still takes a **sponsor address**.

### Official default recommending-member link (first-time Bronze)

If a new user does not have a personal referrer to sponsor their first membership mint, use the official default recommending-member link:

- `https://app.ignitus.network/?Pr=0&R=0`

This link references a specific existing membership NFT (product `0`, tokenId `0`) and lets the app resolve the **sponsor address** from that NFT. On-chain, the actual membership mint still supplies a **sponsor address** to `mintMembership(...)`.

Why this can be used for “first Bronze on any product”:
- For the first tier (`desiredTier == 0`), the sponsor must be either the root affiliate or an address that already holds membership.
- A sponsor who holds membership can sponsor Bronze across products (Ignitus uses a global sponsor check via the ecosystem registry).

Operationally:
- Validate `sponsor != user`
- For Bronze, allow `rootAffiliate` as sponsor when bootstrapping new wallets.

---

## Monitoring without client-side `eth_getLogs`

For production bots, avoid heavy client-side log scanning. Use one of:

- A **subgraph / indexer** (GraphQL) that indexes:
  - `MembershipMinted`
  - (optional) `Bought`, `Refunded`, `Claimed`
- An internal service that writes events to a DB and exposes a small API to your bot.

This keeps bots reliable even when public RPC providers limit `eth_getLogs` range or throughput.

---

## Operational hardening checklist (bots in production)

- **Simulate before sending**: do an `eth_call`/simulation for writes when possible.
- **Nonce management**: serialize sends per wallet; handle stuck transactions.
- **Gas policy**: implement sane max fee / priority fee bounds.
- **Reorg awareness**: treat event confirmation depth as a configurable parameter.
- **Key management**:
  - never paste private keys into chats
  - prefer encrypted keystores / hardware signing for production balances
- **Rate limiting**: do not spam chain reads; cache decimals/addresses and immutable constants.

---

## Safety and disclaimers

This is **not financial advice**. Smart-contract risk, asset-issuer risk, and market volatility apply. Any automated system can lose funds due to bugs, chain conditions, or bad assumptions. Do your own research and test on small amounts first.

