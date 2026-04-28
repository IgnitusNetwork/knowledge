# Counterparty Model vs Pure Backed Asset Model

## What it is
Two fundamentally different ways DeFi systems handle user funds and trading activity.

**Counterparty Model**: The liquidity pool or vault acts as the direct opponent to every trader.  
**Pure Backed Asset Model**: User funds sit in isolated vaults that hold only the exact backing asset. The system is not betting against traders.

## What happens to your money (user POV)

**In the Counterparty Model**  
Your money becomes part of a shared pool that pays out when traders win their leveraged bets. Trading fees may flow in, but if traders as a group make money, that profit is taken directly from the pool. Your share can lose value even when trading volume is high.

**In the Pure Backed Asset Model**  
You deposit an asset (e.g. dollars, gold, or bitcoin) and receive a token representing exact 1:1 backing. The vault only holds the real asset. Trading fees are added to the vault as extra backing, which mathematically increases the value per token over time. The system is never on the opposite side of any trader.

## Common ways users get hurt

**Counterparty Model**  
Many users believe they are simply “earning fees from volume.” They do not realise they are funding other traders’ profits. Sophisticated traders can extract value systematically, causing the pool value to drop even while fees are collected.

**Pure Backed Asset Model**  
The main risks are slower growth if usage is low, or problems with the underlying backing asset itself. There is no hidden transfer of value from passive holders to active traders.

## Simple example with numbers

**Counterparty Model**  
You add $10,000 to a pool.  
Traders as a group win $3 million in profits over a month.  
The pool pays those wins directly → your share drops by ~3% (before fees).  
Even with $1.5 million in fees collected, the net effect can still be a loss for providers.

**Pure Backed Asset Model**  
You deposit $10,000 worth of an asset and receive tokens at exact current backing.  
$200,000 in total trading fees occurs.  
50% of those fees ($100,000) is permanently added to the vault as extra backing.  
Your tokens are now worth slightly more than before (higher backing per token), with no trader winning at your expense.

## What to check (safety checklist)
- Does the system act as the counterparty to leveraged traders, or does it only hold the exact backing asset?  
- If traders win big, whose money pays for those wins?  
- Are fees used to strengthen the backing for all holders, or do they only partially offset losses?  
- Can my funds be taken to pay other users’ profits?  
- How transparent and verifiable is the backing at all times?

## Further reading (internal only)
- [[counterparty-risk-in-leveraged-trading-pools.md]]  
- [[understanding-risk.md]]  
- [[fee-and-profit-layers/layer-5-impermanent-loss-and-opportunity-cost.md]]  
- [[on-chain-transparency/checking-balances-and-backing.md]]

---
This is not financial advice. Smart-contract risk, asset-issuer risk, and market volatility apply. DYOR.

