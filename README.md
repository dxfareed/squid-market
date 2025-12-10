# Bob Market

**Bob Market** is a reputation-based decentralized marketplace built on the Stacks blockchain. It allows users to list items for sale with an expiry time, facilitates secure escrowed transactions, and tracks seller reputation on-chain.

## Features

- **Listings with Expiry**: Sellers create listings that automatically expire at a specific block height.
- **Secure Escrow**:
  - Buyers deposit funds into the contract.
  - Funds are held until the buyer confirms receipt.
  - Sellers can refund buyers if the item is not delivered.
- **Reputation System**: successful transactions verify seller reliability and increase their on-chain reputation score.
- **Clarity 4 Ready**: Utilizes modern Clarity features.

## Project Structure

- `contracts/`: Clarity smart contracts (`bob-market.clar`).
- `frontend/`: React/Vite frontend application.
- `tests/`: Vitest + Clarinet SDK unit tests.

## Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet)
- [Node.js](https://nodejs.org/) & `npm`

## Setup & Testing

1.  **Install Dependencies**:
    ```bash
    npm install
    ```

2.  **Run Contract Tests**:
    ```bash
    npm test
    ```

3.  **Check Contracts**:
    ```bash
    clarinet check
    ```

## Contract Interface

### `create-listing`
Creates a new listing with a price, expiry block, and optional metadata.

### `buy`
Buyer locks funds in the contract. Listing must be active and not expired.

### `confirm-received`
Buyer confirms receipt of goods. Funds are released to the seller, and seller reputation increases.

### `refund-buyer`
Seller cancels an active transaction and refunds the buyer.

### `cancel-listing`
Seller removes an unsold listing.
