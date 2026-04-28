# Ignitus Developer Reference

> Version 2026-04 | Ethereum mainnet deployment
>
> Integration-oriented reference for developers and automated tools
> building on or integrating with the Ignitus protocol.

---

## 1. Solidity source mirrors (AI verification)

Plain-text copies of core protocol contracts ship alongside this documentation (synced from `mini_app/app/contracts/`). Use them so assistants can answer from **verbatim** source alongside Etherscan verification.

| File | URL |
|------|-----|
| ProtocolRouter.sol | https://ignitus.network/docs/ignitus/ProtocolRouter.sol |
| EcosystemFactory.sol | https://ignitus.network/docs/ignitus/EcosystemFactory.sol |
| USDCReserveToken.sol | https://ignitus.network/docs/ignitus/USDCReserveToken.sol |
| BackingToken.sol | https://ignitus.network/docs/ignitus/BackingToken.sol |
| FeeParticipationAccumulator.sol | https://ignitus.network/docs/ignitus/FeeParticipationAccumulator.sol |
| MembershipNFT.sol | https://ignitus.network/docs/ignitus/MembershipNFT.sol |
| IEcosystemFactorySponsor.sol | https://ignitus.network/docs/ignitus/IEcosystemFactorySponsor.sol |
| IFeeParticipationAccumulator.sol | https://ignitus.network/docs/ignitus/IFeeParticipationAccumulator.sol |
| IMembershipBackingToken.sol | https://ignitus.network/docs/ignitus/IMembershipBackingToken.sol |

Full list also appears in [llms.txt](https://ignitus.network/llms.txt) under **Solidity source mirrors**.

---

## 2. Network

| Property  | Value |
|-----------|-------|
| Chain     | Ethereum Mainnet |
| Chain ID  | `1` |
| Explorer  | https://etherscan.io |

---

## 3. Core contracts

### 3.1 Global

| Contract          | Address | Etherscan |
|-------------------|---------|-----------|
| ProtocolRouter    | `0x069c0210495ADF194101C71Ff4A68140E9145Bb7` | [View](https://etherscan.io/address/0x069c0210495ADF194101C71Ff4A68140E9145Bb7) |
| EcosystemFactory  | `0x655d37556a3e922133960B02BFbf4D09ac2985c2` | [View](https://etherscan.io/address/0x655d37556a3e922133960B02BFbf4D09ac2985c2) |
| Root Affiliate    | `0x44Fc8743E4e8435be210C57dcAF03B393269c557` | [View](https://etherscan.io/address/0x44Fc8743E4e8435be210C57dcAF03B393269c557) |

### 3.2 Product 0 -- igUSD (USDC-backed)

| Contract                   | Address | Etherscan |
|----------------------------|---------|-----------|
| IG Token (USDCReserveToken) | `0xe82D09bDb33aD258E81e1b2c89cDEbb0324C7c34` | [View](https://etherscan.io/address/0xe82D09bDb33aD258E81e1b2c89cDEbb0324C7c34) |
| Membership NFT              | `0x35966d38026286daB7b66cfE45A89d5DDF54a469` | [View](https://etherscan.io/address/0x35966d38026286daB7b66cfE45A89d5DDF54a469) |
| Fee Accumulator             | `0x63C877F2B39ab954b2327b290203C3146177d898` | [View](https://etherscan.io/address/0x63C877F2B39ab954b2327b290203C3146177d898) |
| Backing Asset (USDC)        | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` | [View](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) |

### 3.3 Product 1 -- igGOLD (XAUT-backed)

| Contract                | Address | Etherscan |
|-------------------------|---------|-----------|
| IG Token (BackingToken) | `0xF4CBc849453D64e8776862033A71E87313dF906a` | [View](https://etherscan.io/address/0xF4CBc849453D64e8776862033A71E87313dF906a) |
| Membership NFT          | `0xde0c96c504B948de7D2639F81f64ec3E5626A744` | [View](https://etherscan.io/address/0xde0c96c504B948de7D2639F81f64ec3E5626A744) |
| Fee Accumulator         | `0x41BFFD52e877fCfa63935dB198BB35d3072A73c4` | [View](https://etherscan.io/address/0x41BFFD52e877fCfa63935dB198BB35d3072A73c4) |
| Backing Asset (XAUT)    | `0x68749665FF8D2d112Fa859AA293F07A622782F38` | [View](https://etherscan.io/address/0x68749665FF8D2d112Fa859AA293F07A622782F38) |

### 3.4 Product 2 -- igBTC (WBTC-backed)

| Contract                | Address | Etherscan |
|-------------------------|---------|-----------|
| IG Token (BackingToken) | `0xC9E045A10D91a38E98c393e3D4A3923ea21bdde3` | [View](https://etherscan.io/address/0xC9E045A10D91a38E98c393e3D4A3923ea21bdde3) |
| Membership NFT          | `0x98d2ADfEf71FdA28BCdf8d124A734D65cef00775` | [View](https://etherscan.io/address/0x98d2ADfEf71FdA28BCdf8d124A734D65cef00775) |
| Fee Accumulator         | `0xCb69442CC039664a20cdf6676707e06E280eC05B` | [View](https://etherscan.io/address/0xCb69442CC039664a20cdf6676707e06E280eC05B) |
| Backing Asset (WBTC)    | `0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599` | [View](https://etherscan.io/address/0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599) |

---

## 4. Key entry points

### 4.1 Buy IG tokens

```
ProtocolRouter.buy(uint256 productId, uint256 amount)
```

- `productId`: 0 (USDC), 1 (XAUT), 2 (WBTC)
- `amount`: Backing asset amount (in asset decimals)
- Caller must have approved the **product token contract** (not the router)
  for the backing asset.
- Router resolves the caller's effective fee BPS from their highest
  membership tier and forwards to `buyFromRouter` on the product token.

### 4.2 Sell (refund) IG tokens

```
ProtocolRouter.refund(uint256 productId, uint256 tokenAmount)
```

- `tokenAmount`: IG amount to burn (18 decimals)
- Returns backing asset minus fee.

### 4.3 Mint membership

```
MembershipNFT.mintMembership(uint256 productId, uint8 desiredTier, address sponsor)
```

- Called directly on the product's MembershipNFT contract.
- Requires backing asset approval to the **IG token contract** (NFT
  transfers backing into the vault during mint).

### 4.4 Claim rewards

```
FeeParticipationAccumulator.claim()
```

- Called directly on the product's accumulator.
- Transfers accrued IG tokens to caller. No protocol fee.

---

## 5. Fee constants (from Solidity source)

### 5.1 Trading fee BPS (ProtocolRouter)

| Constant          | BPS | Effective % |
|-------------------|-----|-------------|
| `BPS_NON_MEMBER`  | 100 | 1.00%       |
| `BPS_BRONZE`      | 90  | 0.90%       |
| `BPS_SILVER`      | 88  | 0.88%       |
| `BPS_GOLD`        | 85  | 0.85%       |
| `BPS_PLATINUM`    | 83  | 0.83%       |
| `BPS_DIAMOND`     | 80  | 0.80%       |

### 5.2 Fee split (USDCReserveToken / BackingToken)

| Constant            | Value | Meaning |
|---------------------|-------|---------|
| `BACKING_BOOST_BPS` | 50    | 50% of fee stays as vault backing |
| `POOL_BPS`          | 30    | 30% minted as IG to fee pool |
| `TREASURY_BPS`      | 20    | 20% minted as IG to treasury |
| `BPS_DIVISOR`       | 10,000 | |

### 5.3 Membership tiers (MembershipNFT constructor)

| Tier     | `priceUSDC6` | `tokenCap`      | `affiliateRateBps` |
|----------|--------------|-----------------|---------------------|
| Bronze   | `243e6`      | `1_000 * 1e18`  | `1_000` (10%)       |
| Silver   | `972e6`      | `5_000 * 1e18`  | `1_250` (12.5%)     |
| Gold     | `2430e6`     | `15_000 * 1e18` | `1_500` (15%)       |
| Platinum | `7290e6`     | `60_000 * 1e18` | `1_750` (17.5%)     |
| Diamond  | `21880e6`    | `225_000 * 1e18`| `2_000` (20%)       |

### 5.4 Other constants

| Constant          | Contract             | Value |
|-------------------|----------------------|-------|
| `MIN_AMOUNT`      | USDCReserveToken     | `1_000` (0.001 USDC) |
| `MIN_AMOUNT`      | BackingToken         | `1_000` |
| `MAX_MARKETING_MINTS` | MembershipNFT   | `1` per product (testnet anchor) |
| `MAX_NFT_SCAN`    | FeeParticipationAccumulator | `5` |

---

## 6. Architecture overview

```
User Wallet
  |
  |-- buy/refund --> ProtocolRouter --> Product Token (vault)
  |                                       |
  |                                       |-- 50% fee stays as backing boost
  |                                       |-- 30% fee --> FeeParticipationAccumulator
  |                                       |-- 20% fee --> Treasury (IG mint)
  |
  |-- mintMembership --> MembershipNFT --> Product Token
  |                       |                  (addBackingFromMembership + mintForMembership)
  |                       |
  |                       |-- sponsorHasAnyMembership --> EcosystemFactory
  |
  |-- claim() --> FeeParticipationAccumulator --> IG transfer to user
```

---

## 7. Contract source code

Verify deployed bytecode on Etherscan (links in section 3).

Verbatim Solidity mirrors for AI tools (same files as `mini_app/app/contracts/`): see **section 1** above, or [llms.txt](https://ignitus.network/llms.txt).

---

## 8. Disclaimer

This document describes the live Ethereum mainnet deployment. It is not financial
advice. Smart-contract risk, asset-issuer risk, and market volatility apply.

---

*Last verified against contract sources: 2026-04.*

