# NodeFi Tokenomics Whitepaper

## 1. Introduction

NodeFi’s TOKENOMICS whitepaper describes the economic design of the fixed- and variable-supply NODE token, designed to align incentives across staking, liquidity provision, and protocol governance.

## 2. Supply Mechanics

- **Fixed Supply**: 622,000,000 NODE minted at genesis.
- **Floating Mintable Supply**: Up to 68,000,000 NODE (total cap 690M) via on-chain buybacks and commission reallocations.
- **Deflationary Burn**: 1% burn on unstake; supports long-term token value.

## 3. Staking & Shares

- **CoreVault** issues nCORE shares 1:1 initially; share-based minting thereafter:
  

- **Dust Handling**: Remainder dust accumulated and periodically redistributed to an owner-controlled epoch.

## 4. Governance Locks

- **veNODE**: Lock NODE to receive voting power and up to 50% boost on rewards.
- **veUNI**: Lock UNI to receive up to 30% additional boost on UNI yield.

Boost formula:


## 5. Commission & Buyback

- **CommissionManager** charges 10% on NODE rewards, routed to treasury.
- **Buyback** uses treasury to repurchase and burn NODE, up to floating supply cap.

## 6. Liquidity Provider Incentives

- Allocates Uniswap V3/V4 ETH, SOL LP fees to CoreVault, boosting yield.
- **Cross-chain BridgeAdapter** injects SOL yields into Ethereum distribution.

## 7. Sustainability Model

- **12-Month Projections** with ramp-up, Uniswap pool integration, yield capture.
- **Revenue Streams**: Uniswap trading fees, cross-chain yield, commission buys.

| Month | TVL (M) | NODE Price | Yield (%) | Treasury Accrual |
|-------|---------|------------|-----------|------------------|
| 1     | 50      | $0.10      | 12        | $600K            |
| 6     | 200     | $0.25      | 15        | $4.5M            |
| 12    | 500     | $0.50      | 18        | $22.5M           |

## 8. Conclusion

The NodeFi tokenomics frame a sustainable, governance-aligned token economy that rewards long-term LPs and stakers while ensuring protocol security and growth.

