# Uniswap Foundation Grant Proposal

## 1. Executive Summary

NodeFi is a DeFi-native staking and yield-aggregation protocol that leverages Uniswap V3/V4 liquidity to bootstrap and expand validator networks on Solana and Ethereum. By routing a portion of trading fees and cross-chain yields into on-chain validators—and rewarding liquidity providers with our NODE token—NodeFi creates a self-reinforcing flywheel that:

- **Expands decentralization** of both Solana and Ethereum.
- **Incentivizes Uniswap** LPs with enhanced staking yield.
- **Strengthens network security** through commission and buyback mechanics.
- **Aligns Uni governance** via veNODE and veUNI locking.

We request a **$100,000** grant to build, audit, and launch NodeFi, with milestones tied to smart-contract audits, testnet deployments, and community incentives.

## 2. Problem Statement

- **Validator Centralization**: Solana and Ethereum PoS ecosystems risk concentration of stake among a handful of large operators.
- **Yield Fragmentation**: LPs on Uniswap lack seamless access to staking yield without manual steps.
- **Governance Misalignment**: Protocols struggle to align token incentives across staking, LP rewards, and governance.

## 3. Solution Overview

NodeFi unites staking, DeFi, and governance:

1. **CoreVault**: Users deposit ETH/SOL or stablecoins; CoreVault mints nCORE shares.
2. **RewardsDistributor**: Aggregates on-chain yield (via BridgeAdapter) and distributes NODE/UNI rewards with veToken/veUNI boosts.
3. **VeToken & VeUNI**: veNODE and veUNI locking boost rewards and align long-term governance.
4. **Commission & Buyback**: A % of rewards funds commissionManager for protocol treasury and buybacks.
5. **Uniswap Integration**: Routes a portion of trading fees from designated UNI/SOL/ETH pools into NodeFi’s yield engine.

## 4. Architecture & Workflow

See [architecture_overview.png](architecture_overview.png).

1. **Deposit**: LPs deposit tokens → CoreVault.
2. **Lock**: NODE & UNI locked in veContracts for boosts.
3. **Yield Capture**: BridgeAdapter captures cross-chain and Uniswap fee yield.
4. **Distribution**: RewardsDistributor allocates rewards with boost logic.
5. **Commission & Buyback**: Treasury accrues and repurchases NODE.
6. **Governance**: veNODE/veUNI holders govern upgrades and parameter changes.

## 5. Deliverables & Timeline

| Milestone                            | Duration  | Deliverable                              |
|--------------------------------------|-----------|------------------------------------------|
| Smart Contract Development           | 2 months  | Deployed CoreVault, Distributor, veContracts |
| Audit & Security Review              | 1 month   | Audited code; Slither, Diligence Fuzzing |
| Testnet Deployment & Incentives Pilot| 1 month   | Live testnet; 10,000 users onboarded     |
| Mainnet Launch & Marketing           | 1 month   | Mainnet deployment; $500K in TVL         |
| Uniswap Partnership & Integration    | Ongoing   | UNI pool integrations; grant milestones  |

## 6. Budget

| Category                | Amount (USD) |
|-------------------------|--------------|
| Development             | 200,000      |
| Audits & Security       | 100,000      |
| Testnet Incentives      | 50,000       |
| Marketing & Community   | 50,000       |
| **Total**               | **400,000**  |

## 7. Team

- @Cbrown03777 – Lead Protocol Engineer 
- **[Teammate]** – Smart-Contract Developer (Ex-OpenZeppelin).
- **[Advisor]** – PoS Validator Ops (Ex-Blockchain Infrastructure).

## 8. Conclusion

NodeFi will deepen Uniswap’s role in securing PoS networks while providing LPs with seamless, high-yield staking. We look forward to partnering with the Uniswap Foundation to realize this vision.

