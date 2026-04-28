# TradFi Service Providers Knowledge Base: Hedge Funds, Portfolio Managers, and Retirement Plans (April 2026 Snapshot)

This is a fact-based compilation drawn exclusively from official documentation, regulatory filings (SEC, DOL/ERISA), court records, academic studies, and linked primary sources. No opinions or projections. Each section lists core mechanics, user/client-POV risks (fees, liability, custody, layered erosion), and key links for verification. Focus is on structural dangers: layered fees from portfolio/fund jumping, central trading entities serving multiple clients with zero direct liability to end investors, and custody/rehypothecation risks.

### 1. Hedge Fund Core Structures (Master-Feeder and Related)
**Core Mechanism**: Most hedge funds use a master-feeder structure: separate feeder funds (onshore for U.S. taxable investors; offshore e.g. Cayman for tax-exempt/foreign) pool capital and invest 100% into a single master fund that executes all trading/investments. Feeder funds handle investor-specific rules (tax, regulation, currency); master fund centralizes portfolio management. Feeder funds may themselves be funds-of-funds (FoF) allocating across multiple masters.

**User/Client-POV Risks**:
- Capital "jumps" layers (investor → feeder → master), with fees at each level.
- Additional admin/NAV calculation costs at master level passed through.
- Illiquidity: redemptions often gated/locked; forced deleveraging in stress.
- No direct control over master-fund trading.

**Key Links**:
- Carta: Dissecting Master-Feeder (https://carta.com/learn/private-funds/structures/master-feeder/)
- Investopedia: Master-Feeder Structure (https://www.investopedia.com/terms/m/master-feeder-fund.asp)
- FINRA: Feeder Funds Limitations (https://www.finra.org/investors/insights/feeder-funds)

### 2. Fee Structures and Layered Erosion (Portfolio/Fund Jumping)
**Core Mechanism**: Standard "2 and 20" (or variants) remains the pricing anchor: 2% annual management fee on AUM + 20% performance/incentive fee on profits (often above hurdle rate/high-water mark). Fees are typically charged at feeder level; master may pass through expenses. In FoF or multi-layer structures, each layer adds its own management (1–2%) + performance (10–20%) fees. Switching funds (portfolio jumping) triggers entry/exit fees, redemption gates, or new high-water marks. In 2026, average fees for established/large funds have compressed to approximately 1.5% management + 17–20% performance.

**User/Client-POV Risks**:
- Every layer extracts fees before capital reaches actual trading (e.g., investor pays feeder fee → feeder pays master fee → master pays sub-managers).
- Pass-through fees (legal, audit, admin) on top; net returns eroded even in flat markets.
- Performance fees paid on gross profits but calculated after management fees; no clawback in many cases for future losses.
- Fund switching: exit fees + new entry fees + reset high-water marks mean paying repeatedly for the same "alpha."
- Example: $10M in FoF → FoF charges 1% mgmt + 10% perf → underlying hedge funds charge 2/20 → total drag can exceed 3–4% annually + perf.

**Key Links**:
- Preqin: Hedge Fund Fees (https://www.preqin.com/academy/lesson-3-hedge-funds/hedge-fund-fees-types-and-structures)
- Investopedia: Two and Twenty (https://www.investopedia.com/terms/t/two_and_twenty.asp)

### 3. Liability (Hedge Funds and Portfolio Managers)
**Core Mechanism**: Funds structured as limited partnerships/LLCs: investors = limited partners (LPs) with limited liability (lose only committed capital). General partner (GP)/manager = investment adviser with fiduciary duty (if SEC-registered). Portfolio managers often operate through the GP or sub-advisers. One central trading/master entity can serve hundreds of feeder clients or hedge funds via prime brokerage/managed accounts.

**User/Client-POV Risks**:
- Liability = 0 for hedge fund/GP beyond invested capital; investors bear 100% of losses (no recourse if manager takes excessive risk for performance fees).
- Central trading desk (master or prime broker) has no direct liability to end LPs—only to its immediate clients (the hedge funds).
- Conflicts: performance fees incentivize riskier bets; manager can collect fees while investors lose principal.

**Key Links**:
- iCapital: How Hedge Funds Work (https://icapital.com/insights/hedge-funds/understanding-how-hedge-funds-work/)
- Proskauer: Hedge Fund Structuring (https://www.proskauer.com/pub/proskauer-hedge-start-key-structuring-issues)

### 4. Prime Brokerage / Outsourced Trading (One Entity Serving Hundreds of Hedge Funds)
**Core Mechanism**: Prime brokers provide custody, financing, execution, and clearing to multiple hedge funds. One broker can handle hundreds of clients; hedge funds outsource actual trading/ops while collecting their own fees. Assets are often rehypothecated (reused as collateral by broker). In the U.S., rehypothecation is limited to 140% of the client’s net liability (Reg T / Rule 15c3-3).

**User/Client-POV Risks**:
- Central entity controls actual trading/custody; hedge funds act as fee collectors with no skin in execution.
- Rehypothecation risk: client assets pledged/reused; in broker failure, assets frozen or lost.
- No direct liability chain to end investors—hedge fund LPs have claims only against their fund, not the prime broker.
- Modern trend: many managers now diversify across 2–3 prime brokers to reduce single-point failure risk.

**Key Links**:
- BIS: Prime Broker–Hedge Fund Nexus (https://www.bis.org/publ/qtrpdf/r_qt2403y.htm)
- Capco Outsourced Trading Whitepaper (https://thehedgefundjournal.com/wp-content/uploads/2020/10/Capco_Outsourced-Trading_Whitepaper.pdf)

### 5. Lehman Brothers Case Study (Prime Broker Failure Example)
**Core Mechanism**: Lehman acted as prime broker for ~100 hedge funds, providing custody/financing. Rehypothecated ~$22B of $40B client assets. Bankruptcy (Sept 15, 2008) froze positions; hedge funds could not trade or switch brokers.

**User/Client-POV Risks and Details**:
- Client assets trapped for years (prime brokerage claims took ~5 years to resolve).
- Hedge funds forced to delever, sit on cash, incur opportunity costs; failure rate of Lehman clients doubled vs. peers.
- Systemic: $737B decline in securities lending collateral; market dislocation amplified losses.
- End investors (LPs in those hedge funds) bore full losses with zero liability/recourse from Lehman or their hedge fund managers.
- Highlighted custody/rehypothecation dangers: assets not fully segregated; unsecured creditor status in bankruptcy.

**Key Links**:
- NY Fed: Customer Losses (https://libertystreeteconomics.newyorkfed.org/2019/01/customer-and-employee-losses-in-lehmans-bankruptcy/)
- Aragon Study: Hedge Funds as Liquidity Providers (https://jhfinance.web.unc.edu/wp-content/uploads/sites/12369/2016/02/Hedge-Funds-as-Liquidity-Providers-Evidence-From-The-Lehman-Bankruptcy.pdf)

### 6. Portfolio Managers and Fund Switching (Jumping Generates Fees)
**Core Mechanism**: Portfolio managers allocate across multiple hedge funds/master vehicles. Switching (rebalancing) moves capital through new feeders/masters, resetting fees and triggering gates/exit charges.

**User/Client-POV Risks**:
- Every jump: new management fees + potential performance fee resets + exit penalties.
- Layered drag compounds; net returns to client eroded at each step while managers collect regardless of overall performance.

**Key Links**: See Fee Structures section above + FINRA Feeder Funds.

### 7. Retirement Plans / Service Providers (401(k), Pensions, ERISA)
**Core Mechanism**: Plans invest in hedge funds/alts via target-date funds or lineups. ERISA imposes fiduciary duties (prudence, loyalty, reasonable fees). "Plan assets" rule: if benefit-plan investors ≥25% of hedge fund equity, fund manager becomes ERISA fiduciary. Recordkeepers/custodians add layers. On March 30, 2026, the DOL proposed a process-based safe harbor for fiduciaries selecting alternative investments in 401(k) plans (six-factor prudence framework, target-date funds as primary channel).

**User/Client-POV Risks**:
- Layered fees: plan recordkeeper + investment manager + hedge fund 2/20 + pass-throughs.
- Excessive fee lawsuits rising (fiduciaries liable for imprudent high-cost alts).
- Illiquidity/valuation risks in 401(k) (daily liquidity required but alts are gated).
- Fiduciary liability on plan sponsor (not participant): personal liability for losses if fees deemed unreasonable or monitoring failed.
- DOL 2026 proposal provides a safe harbor but still requires objective, thorough analysis of performance, fees, liquidity, valuation, benchmarks, and complexity.

**Key Links**:
- DOL: Understanding Retirement Plan Fees (https://www.dol.gov/agencies/ebsa/about-ebsa/our-activities/resource-center/publications/understanding-retirement-plan-fees-and-expenses)
- DOL Proposed Safe Harbor (March 30, 2026) (https://www.dol.gov/newsroom/releases/ebsa/ebsa20260330)
- Proskauer: ERISA Benefit Plan Investors (https://www.proskauer.com/pub/proskauer-hedge-start-accepting-investments-from-benefit-plan-investors-subject-to-erisa)

**Verification Note**: All facts extracted from linked primary sources (SEC/DOL filings, academic papers, official reports). Users should review latest Form ADV filings, partnership agreements, prime brokerage contracts, and ERISA plan documents on EDGAR or directly with providers. Custody, counterparty, fee drag, and regulatory risks apply. This database is for informational reference only. Consult licensed professionals and DYOR with the provided links.

