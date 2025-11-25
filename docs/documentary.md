# Allowlist / Whitelist Manager – 5 Minute Demo Script

## 0:00–0:45 – Problem & Motivation

NFT mints live or die based on access control. Projects need to:
- Run multiple phases like friends-and-family, presale, and public
- Cap how many NFTs each wallet can mint
- Charge different prices per phase
- Change rules quickly without redeploying the NFT contract

Most teams hard-code this logic into the mint contract or into an off-chain script. That makes it brittle and hard to reuse across collections.

This project extracts that logic into a reusable Clarity contract: an **Allowlist / Whitelist Manager**.

## 0:45–2:15 – Contract Design (Clarity)

Open `contracts/allowlist-whitelist-manager.clar`.

Core ideas:
- The contract manages **phases** of a mint. Each phase has:
  - `id` and human readable `name`
  - `start-height` and `end-height` for when it is active
  - `max-per-address` – per wallet mint cap
  - `price` in micro-STX
- An `allowlist` map records which wallets are allowed in which phase and how many they have already minted.

Key public functions to highlight:

- `create-phase` / `update-phase` – admin-only functions to configure or change phases on-chain.
- `add-to-allowlist` / `remove-from-allowlist` – admin-only tools for managing who is allowed to mint in each phase.
- `can-mint?` – read-only function NFT contracts can call to ask:
  > For this `user`, in this `phase-id`, can they mint `quantity` more?

  It returns either an error (e.g. phase inactive, user not allowed, or mint limit exceeded) or a success struct with:
  - `allowed` (bool)
  - `remaining` mints after this call
  - `price` for the mint

- `check-and-consume` – convenience function that does a full check **and** increments the minted count in a single call. An NFT contract can use this at the start of its mint function.

Together these functions form a flexible, reusable access control layer for many different NFT projects.

## 2:15–3:10 – Tests with Clarinet

Open `tests/allowlist-whitelist-manager_test.ts`.

There are three main tests:

1. **Owner can create and update phases** – deployer calls `create-phase` then `update-phase` and we assert both transactions succeed.
2. **Owner can manage allowlist entries** – deployer creates a phase, adds a wallet to the allowlist, then removes it again.
3. **`can-mint?` enforces limits** – we:
   - Create a phase that is active from block 1–100 with `max-per-address = 2`
   - Add a wallet to the allowlist
   - Call `check-and-consume` for quantity `1` (should succeed)
   - Call again for quantity `2` and expect an error with code `u105` (mint limit exceeded)

These tests show the contract’s behavior from an NFT project’s perspective and document how to integrate it.

## 3:10–4:20 – UI v1 and v2 (Redesign)

We built two small front-ends to explore the UX side.

### v1 – Minimal functional UI (`ui/index.html`)

- Straightforward form fields to:
  - “Connect” a wallet (simulated)
  - Create a phase
  - Add or remove wallets from the allowlist
  - Call `check-and-consume` and log the result
- Internally it mirrors the data structures from the contract so it’s easy to follow what’s happening.

### v2 – UX-focused redesign (`ui-v2/index.html`)

- Same core workflow, but redesigned for clarity:
  - A **Phase & Access Control Composer** panel for configuring phases and allowlists
  - A **Live Console** that logs the exact contract-call payloads the app would send via `@stacks/transactions`
- Uses a more polished layout, clear step indicator pills, and semantic grouping:
  1. Configure mint phase parameters
  2. Manage allowlist entries (a CSV upload step could be added here)
  3. Run `check-and-consume` to validate a mint

The redesign illustrates how you might productize this idea in a dashboard used by NFT project operators.

## 4:20–5:00 – How an NFT Contract Integrates

To integrate this manager, an NFT mint contract would:

1. Store the address of the deployed allowlist manager contract.
2. At the beginning of its `mint` function, call `check-and-consume` with:
   - the active `phase-id`
   - the caller’s principal
   - the requested mint `quantity`
3. If the call returns `ok`, continue to mint and charge `price * quantity`.
4. If it returns an error, bubble that error up to the user.

This pattern separates **who is allowed to mint** from **what gets minted**, making NFT drops easier to operate, reuse, and audit on-chain.

That’s the Allowlist / Whitelist Manager: a reusable smart contract, covered by Clarinet tests, plus a simple UI and a UX-focused redesign – all designed to fit into a concise 5-minute demo.
