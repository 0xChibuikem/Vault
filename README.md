# InsuranceVault Smart Contract

## Overview

**InsuranceVault** is a decentralized insurance platform built on the Stacks blockchain.  
It allows users to:

- Purchase insurance policies by paying premiums.
- File claims against their active policies.
- Have claims reviewed and approved/rejected by authorized administrators.
- Receive payouts automatically for approved claims.

Admins manage claim processing, and the contract owner controls high-level operations like fund withdrawal.

---

## Key Features

- **Policy Purchase**: Users can buy policies by paying a minimum premium.
- **Claims**: Users can file insurance claims and pay a small filing fee.
- **Claim Processing**: Admins can approve or reject claims.
- **Payouts**: Approved claims are paid out automatically; policies can be deactivated after full payout.
- **Admin Controls**: Admin roles can be assigned and revoked.
- **Owner Controls**: The contract owner can withdraw accumulated funds.

---

## Contract Details

### Constants

- `CONTRACT_OWNER`: Address that deploys the contract.
- `STATUS_PENDING`, `STATUS_APPROVED`, `STATUS_REJECTED`, `STATUS_PAID`: Claim status codes.
- `CLAIM_FEE`: Filing fee for claims (1000 microSTX).
- `MIN_PREMIUM`: Minimum insurance premium (10,000 microSTX).

### Data Structures

- `policies`: Maps policy ID → policy details.
- `claims`: Maps claim ID → claim details.
- `admins`: Maps address → boolean (admin rights).
- `next-policy-id` and `next-claim-id`: Counters for generating unique IDs.

---

## Functions

### Read-Only Functions

- `get-policy(policy-id)`: Retrieve a policy’s details.
- `get-claim(claim-id)`: Retrieve a claim’s details.
- `is-admin(address)`: Check if an address is an admin.
- `is-policy-active(policy-id)`: Check if a policy is currently active.

### Public Functions

#### Admin Management
- `add-admin(new-admin)`: Add a new admin. Only contract owner or existing admins.
- `remove-admin(admin)`: Remove an admin. Only owner or the admin themselves.

#### Policy Management
- `purchase-policy(premium, coverage-amount, duration)`: Buy a new insurance policy.
- `cancel-policy(policy-id)`: Cancel an active policy and receive a prorated refund.

#### Claim Management
- `file-claim(policy-id, amount, description)`: File a new insurance claim.
- `process-claim(claim-id, approve)`: Admins approve or reject a claim.
- `pay-claim(claim-id)`: Admins trigger payout for an approved claim.

#### Fund Management
- `withdraw-funds(amount)`: Owner can withdraw contract funds.

#### Emergency Functions
- `pause-all-policies()`: (Placeholder) Intended to globally pause policies (implementation limited by Clarity language).

---

## Error Codes

| Code | Meaning |
|:----:|:-------|
| `401` | Unauthorized action |
| `402` | Insufficient payment (e.g., low premium) |
| `403` | Invalid policy |
| `404` | Expired policy |
| `405` | Invalid claim |
| `406` | Invalid claim or premium amount |
| `407` | Claim already processed |

---

## Notes

- **Contract Payments**: Premiums and claim fees are paid to the contract’s balance.
- **Simplifications**:  
  - No global iteration over all policies (Clarity doesn't allow iterating over a map).
  - Refunds on policy cancellation use a simple proportional calculation based on remaining block duration.
- **Security**: Only the contract owner can withdraw funds or add/remove admins.
- **Upgradability**: This version does not include built-in upgrade mechanisms (e.g., pausing, migration, or proxy patterns).

## Deployment Instructions

1. Deploy on the Stacks blockchain (e.g., using Clarinet or Hiro Wallet).
2. Set `CONTRACT_OWNER` to your address.
3. Add necessary admins using `add-admin`.
4. Ensure sufficient liquidity if expecting claim payouts.

## Potential Future Enhancements

- Implement a real "pause-all" mechanism using policy flags.
- Add event emissions for better tracking (on-chain notifications).
- Introduce more advanced underwriting features (e.g., risk scoring).
- Add time-based premium adjustments.
- Integration with off-chain oracles for real-world event validation.
