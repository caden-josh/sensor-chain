# 📡 SensorChain — Decentralized IoT Data Marketplace on Bitcoin L2

**SensorChain** is a trustless, decentralized marketplace that enables IoT device owners to monetize real-time sensor data on Bitcoin's Layer 2 via the Stacks blockchain. This protocol provides a stake-backed, reputation-driven system for publishing, verifying, and consuming sensor data with built-in cryptographic accountability and economic incentives.

---

## 🧭 System Overview

SensorChain empowers **device operators** to convert their IoT infrastructure into revenue-generating assets. Using Clarity smart contracts, SensorChain enforces transparent interactions among stakeholders:

* **Sensor Owners** stake STX to register IoT devices.
* **Data Consumers** subscribe to real-time data streams.
* **Validators** verify sensor data to uphold quality and earn reputation influence.
* **Smart Contracts** manage access control, payments, subscriptions, and dispute resolution — without intermediaries.

This infrastructure is ideal for **smart cities**, **supply chain tracking**, **environmental monitoring**, and any domain where **verified sensor data** is critical.

---

## 🧱 Contract Architecture

### Key Smart Contract Features

| Module                  | Description                                                       |
| ----------------------- | ----------------------------------------------------------------- |
| **Sensor Registry**     | Stake-based registration system for IoT sensors                   |
| **Data Submission**     | Allows real-time data uploads tied to sensor ID                   |
| **Validation Layer**    | Validators verify data to adjust sensor reputation                |
| **Subscription Engine** | Enables time-bound, query-limited subscriptions for consumers     |
| **Access Control**      | Ensures only authorized users access sensor data                  |
| **Payment & Fees**      | Handles payments, platform fees, and balances in STX              |
| **Admin Controls**      | Owner can adjust platform parameters like fees and data retention |

---

## 📐 Data Structures

### Maps

* `sensors`: Maps sensor IDs to sensor metadata
* `sensor-data`: Stores timestamped sensor data entries
* `user-balances`: Tracks STX balances inside the contract
* `subscriptions`: Manages active subscriptions between consumers and sensors
* `owner-sensor-count`: Limits number of sensors per owner

### Variables

* `sensor-counter`: Unique ID generator for sensors
* `data-entry-counter`: ID generator for sensor data
* `platform-fee`: Fee (in basis points) on subscriptions (default: 2%)
* `data-retention-period`: Default retention (~1 year in blocks)
* `contract-owner`: Admin authority for platform parameters

---

## 🔁 Data Flow Overview

### Sensor Registration

1. Device owner stakes `MIN-STAKE` STX to register a new sensor.
2. Metadata (type, location, price) is validated and stored.
3. Owner’s STX balance is reduced by stake amount.

### Data Submission

1. Owner uploads `data-value` and `data-hash` for a sensor.
2. The contract stores the data, timestamp, and marks it as unverified.

### Data Verification

1. Validators (not the owner) verify entries.
2. Validated data adjusts the sensor’s `reputation-score` (+1 or -5).
3. One-time verification enforced per entry.

### Consumer Subscription

1. Consumer selects duration + query limit.
2. Payment is split: sensor owner receives most, platform receives a fee.
3. Subscription is stored with expiry and remaining queries.

### Data Access

1. Consumer queries sensor.
2. Contract checks:

   * Subscription validity
   * Sensor freshness
   * Query allowance
3. If valid, access is granted, and query counter is decremented.

---

## 🧾 Error Codes

| Code   | Meaning              |
| ------ | -------------------- |
| `u100` | Unauthorized         |
| `u101` | Not Found            |
| `u102` | Already Exists       |
| `u103` | Invalid Input        |
| `u104` | Insufficient Funds   |
| `u105` | Sensor Offline       |
| `u106` | Data Expired         |
| `u107` | Subscription Expired |

---

## ⚙️ Constants & Constraints

| Constant                | Value               | Description                               |
| ----------------------- | ------------------- | ----------------------------------------- |
| `MIN-STAKE`             | `10000`             | Minimum STX required to register a sensor |
| `DATA-FRESHNESS-WINDOW` | `144` blocks        | (~1 day)                                  |
| `MAX-SENSORS-PER-OWNER` | `100`               | Limits spam sensors                       |
| `BASIS-POINTS`          | `10000`             | Used for % calculations                   |
| `platform-fee`          | Default: `200` (2%) | Contract fee cut from subscriptions       |

---

## 🔒 Security & Trust Assumptions

* **Reputation system** deters fraudulent data publishing via validator input.
* **Staked funds** serve as collateral; slashing is a potential future extension.
* **Cryptographic data hashes** allow off-chain data validation by consumers.
* **Subscription model** ensures pay-per-access without centralized billing.

---

## 📌 Admin Controls

Only the `contract-owner` may:

* Adjust platform fee via `set-platform-fee`
* Modify data retention policy with `set-data-retention`

---

## ✅ Future Improvements

* Slashing mechanisms for low-reputation sensors
* Multi-validator consensus on data validity
* IPFS or Gaia integration for full off-chain data referencing
* Event emission for indexing & analytics
* Cross-contract messaging for DAO governance

---

## 📄 License

**MIT License** — Open for modification and use with attribution.

---

## 👨‍💻 Author

**SensorChain** was developed by a senior Stacks Clarity developer with expertise in decentralized IoT applications and Bitcoin Layer 2 smart contracts.

For collaboration or contributions, please open a pull request or issue.
