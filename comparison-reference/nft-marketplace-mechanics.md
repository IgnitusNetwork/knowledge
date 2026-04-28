# NFT Marketplace Mechanics (Bot Reference Only)

Use only when a user explicitly asks about NFT marketplaces (or explicitly asks to compare Ignitus to an NFT marketplace they named).

## Core mechanism (user POV)

Marketplaces allow buying and selling NFTs via signed orders, atomic fulfillment, and on-chain settlement. Some marketplace designs include royalty enforcement, loans, or liquidity aggregation.

## User-POV safety facts

- Contracts are usually open-source and verified, but this varies by marketplace and chain.
- Audits tend to focus on order fulfillment, access control, signature validation, and re-entrancy protections.
- Many designs are non-custodial (the user signs and settles on-chain), but user experience layers can still add risk.
- Risks can include royalty bypass attempts, order signature exploits, unexpected execution paths, or chain-specific risks (congestion, MEV, finality edge cases).
- Users should verify contract addresses and test with small amounts.

## Usage constraint

Do not mention marketplace names unless the user has already named them or explicitly asks for named examples.

