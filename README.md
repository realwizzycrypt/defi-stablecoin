# DeFi Stablecoin Protocol

A decentralized Stablecoin smart contract project built using Solidity and Foundry.
This protocol allows users to provide crypto collateral and mint a decentralized stablecoin pegged to $1 USD via algorithmic collateralization rules.

## About Stablecoins

Stablecoins are an essential primitive in decentralized finance (DeFi). They provide price stability - usually pegged to a fiat currency like USD - and are widely used for trading, lending, borrowing, and yield strategies within the DeFi ecosystem.


## Overview

This repository contains a Solidity-based implementation of a DeFi stablecoin protocol where:

- Users deposit crypto collateral (wETH or wBTC) to mint stablecoins

- Minting requires enough collateral at a safe ratio

- Price feeds (using Chainlink) is used for real-time pricing

This setup reflects foundational DeFi stablecoin mechanics - collateralization, minting logic, and algorithmic stability control.


## Key Concepts

- **Stablecoin**

A cryptocurrency token designed to maintain a stable value relative to a fiat currency (usually USD).

- **Collateralization**

Users must lock up crypto assets to demonstrate value backing before minting stablecoins.

- **Algorithmic Stability**

Smart contract logic enforces economic parameters that help preserve the stablecoin’s peg.


## Features

✔️ Deposit crypto collateral (wETH or wBTC)

✔️ Mint stablecoins when over-collateralized

✔️ Built with Solidity and developer tooling (Foundry)

✔️ Tests included for core logic and invariants


## Tech Stack

| Component                | Purpose                      |
| ------------------------ | ---------------------------- |
| **Solidity**             | Smart contract logic         |
| **Foundry**              | Testing & deployment tooling |
| **Chainlink**            | On-chain price feeds         |


## Installation & Development

### 1. Clone the repo

```bash 
git clone https://github.com/realwizzycrypt/defi-stablecoin.git
cd defi-stablecoin
```

### 2. Install dependencies
(Assuming Foundry is installed — see Foundry docs)

```bash
forge install
```

### 3. Build & compile

```bash
forge build
```

### 4. Run tests

```bash 
forge test
```


## 📂 Directory Structure

```graphql
├── src/               # Smart contract source code
├── test/              # Test scripts (Foundry)
├── script/            # Deployment scripts and mocks
├── foundry.toml       # Foundry configuration
└── README.md          # Project overview
```


## How it Works

1. User deposits collateral

2. Minting stablecoin

3. Stability mechanism

4. Redemption & liquidation


## Next Steps (Optional Enhancements)

1. Deploy on a testnet (e.g. Sepolia)

2. Frontend UI for interaction


## License
```nginx
MIT License
```

## Contributing

Contributions are welcome! Please follow standard GitHub workflow:

1. Fork the repository

2. Create a feature branch

3. Submit a pull request with clear description


