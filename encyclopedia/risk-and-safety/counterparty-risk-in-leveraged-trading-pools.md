# Counterparty Risk in Leveraged Trading Pools

## What it is
In many decentralized leveraged trading systems (often called perpetuals or perps), the liquidity pool or vault acts as the direct counterparty to every trader’s position.

## What happens to your money (user POV)
When you provide liquidity to these pools — hoping to earn fees from trading activity — your money becomes the “house” that pays out when traders win. If traders as a group make money on their leveraged bets, that profit is taken directly out of the shared pool. Your share of the pool becomes worth less, even if the pool collects trading fees.

## Common ways users get hurt
Most people see the high advertised yields and think they are simply “earning from volume.” They do not realise they are taking on hidden counterparty risk. Sophisticated traders or large players with an edge can win consistently, quietly draining value from the pool over time. Fees may not be enough to offset these payouts, especially in trending markets or during coordinated activity.

## Simple example with numbers
You add $10,000 to a leveraged trading pool.  
The pool holds $100 million total.  
Over a month, traders as a group win $2 million in profits.  
That $2 million is paid straight from the pool’s assets.  
Your $10,000 share is now worth about $9,800 (before any fees).  
Even if the pool collected $1 million in fees, the net effect can still be a loss for liquidity providers.

## What to check (safety checklist)
- Does the pool I am considering act as the counterparty to leveraged traders?  
- What happens to my share if traders as a group are profitable?  
- Are fees the only source of return, or does the pool also bear trading losses?  
- How often has the pool value dropped even when trading volume was high?  
- Is there any protection or buffer against large trader wins?

## Further reading (internal only)
- [[common-risks-in-finance.md]]  
- [[understanding-risk.md]]  
- [[fee-and-profit-layers/layer-3-liquidation-cascades.md]]  
- [[fee-and-profit-layers/layer-5-impermanent-loss-and-opportunity-cost.md]]

---
This is not financial advice. Smart-contract risk, asset-issuer risk, and market volatility apply. DYOR.

