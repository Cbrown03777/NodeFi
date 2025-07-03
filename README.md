# NodeFi

NodeFi is a modular, upgradeable protocol that enables:

- **Staking & Vaulting**: Stake ERC-20 (or native ETH/SOL) in a share-based CoreVault with dust handling and configurable slippage.
- **Ve-Boosts**: Lock `NODE` and `UNI` in on-chain `VeToken` and `VeUNI` contracts to boost rewards.
- **Rewards Distribution**: Automated `RewardsDistributor` allocates on-chain and bridged yield with commission routing, deflationary burn, buy-back, and LP exit fees.
- **Cross-Chain Bridge**: `BridgeAdapter` ingests off-chain yield tokens and feeds them into on-chain distribution.
- **Tokenomics**: Fixed and floating supply mechanics, deflationary and buy-back sinks, commission streams, and flywheel integration of Uniswap & Solana liquidity.
- **On-Chain Governance**: `NodeFiTimelockController` + `NodeFiGovernor` enable full DAO proposal/vote/execute.
- **Security & CI**: Slither + ConsenSys Diligence Fuzzing in CI, upgradeable via OZ UUPS proxies, with extensive unit & integration tests.

---

## Table of Contents

1. [Getting Started](#getting-started)  
2. [Architecture Overview](#architecture-overview)  
3. [Contracts & Modules](#contracts--modules)  
4. [Tokenomics & Whitepaper](#tokenomics--whitepaper)  
5. [On-Chain Governance](#on-chain-governance)  
6. [Scripts & Tests](#scripts--tests)  
7. [CI / Security](#ci--security)  
8. [Grant Proposal & Pitch](#grant-proposal--pitch)  
9. [Roadmap](#roadmap)  
10. [Contributing](#contributing)  

---

## Getting Started

### Prerequisites

- Node.js ≥ 16  
- npm or Yarn  
- Hardhat  
- GitHub CLI (for CI integrations)

```bash
# Install dependencies
npm install

# Compile
npx hardhat compile

# Run all tests
npx hardhat test
