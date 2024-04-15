**Decentralized Subscription Manager**

---

**Introduction:**

Decentralized Subscription Manager is a project built on the SUI blockchain platform aiming to provide a decentralized solution for managing subscriptions. This README provides instructions on how to set up the environment, configure connectivity to a local node, create addresses, get SUI tokens, build and publish a smart contract, and explains the functionality of the code.

---

**Setup:**

Before proceeding, ensure you have the following prerequisites installed:

- Ubuntu/Debian/WSL2(Ubuntu):
  ```
  sudo apt update
  sudo apt install curl git-all cmake gcc libssl-dev pkg-config libclang-dev libpq-dev build-essential -y
  ```

- MacOS (using Homebrew):
  ```
  brew install curl cmake git libpq
  ```

Install Rust and Cargo:
```
curl https://sh.rustup.rs -sSf | sh
```

Install SUI:
- Download pre-built binaries (recommended for GitHub Codespaces):
  ```
  ./download-sui-binaries.sh "v1.18.0" "devnet" "ubuntu-x86_64"
  ```

- Or build from source:
  ```
  cargo install --locked --git https://github.com/MystenLabs/sui.git --branch devnet sui
  ```

Install dev tools (optional, not required for GitHub Codespaces):
```
cargo install --git https://github.com/move-language/move move-analyzer --branch sui-move --features "address32"
```

---

**Configure Connectivity:**

1. Run a local network:
   ```
   RUST_LOG="off,sui_node=info" sui-test-validator
   ```

2. Configure connectivity to a local node:
   ```
   sui client active-address
   ```

3. Follow the prompts and provide the full node URL (e.g., http://127.0.0.1:9000) and a name for the configuration (e.g., localnet).

---

**Create Addresses:**

To create addresses, run the following command:
```
sui client new-address ed25519
```

---

**Get Localnet SUI Tokens:**

Run the HTTP request to mint SUI tokens to the active address:
```
curl --location --request POST 'http://127.0.0.1:9123/gas' --header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "<ADDRESS>"
    }
}'
```

Replace `<ADDRESS>` with the active address obtained from `sui client active-address`.

---

**Build and Publish a Smart Contract:**

1. Build the package:
   ```
   sui move build
   ```

2. Publish the package:
   ```
   sui client publish --gas-budget 100000000 --skip validation verification
   ```

---

**Functionality of the Code:**

The code implements a decentralized subscription management system on the SUI blockchain platform. It allows users to subscribe to services, renew subscriptions, and unsubscribe. Here's a brief overview of the functionality:

- **Subscription Management:**
  - Users can subscribe to services by paying the subscription fee.
  - Subscriptions can be renewed before expiration to continue the service.
  - Users can unsubscribe to terminate their subscription.

- **Address Creation:**
  - Users can create addresses to interact with the decentralized subscription manager.

- **Token Minting:**
  - Users can mint SUI tokens to their addresses to pay for subscription fees.

- **Smart Contract Deployment:**
  - Smart contracts implementing the subscription management system can be built and deployed on the SUI blockchain.

---

subscribe<COIN>: This function allows users to subscribe to a service by providing the platform, subscription fee, clock, and transaction context. It checks if the user already has an active subscription and creates a new user account if not. If successful, it adds the user account to the platform's list of accounts.

renew_subscription<COIN>: This function allows users to renew their subscription before it expires. It checks if the user has an active subscription and has sufficient funds to renew. If successful, it renews the subscription by updating the subscription validity period.

unsubscribe<COIN>: This function allows users to unsubscribe from a service, terminating their subscription. It checks if the user has an active subscription and removes the user account from the platform's list of accounts.

user_create_date<COIN>: This function retrieves the creation date of the user's account.

user_subscription_fee<COIN>: This function retrieves the subscription fee associated with the user's account.




**Conclusion:**

The Decentralized Subscription Manager provides a decentralized and transparent solution for managing subscriptions on the blockchain. Users can subscribe to services, renew subscriptions, and unsubscribe autonomously without the need for intermediaries.


