# Praedium Subgraph

The Graph indexer for Praedium — indexing the compliance-gated RWA contracts.

> Part of [Praedium](../README.md) · contract architecture in the root README · dApp docs in [frontend/README.md](../frontend/README.md)

## What This Indexes

The subgraph turns contract events into queryable entities, so the frontend can show transfer history and platform aggregates without scanning the chain:

| Data source | Events indexed |
|-------------|----------------|
| `RWAToken` | `Transfer`, `AssetMinted`, `AssetBurned` |
| `ComplianceRegistry` | `InvestorVerified`, `InvestorRevoked`, `InvestorFrozen` |
| `AssetRegistry` | `AssetRegistered`, `AssetUpdated`, `AssetStatusChanged` |

## Schema

Four entities:

- **`Transfer`** (immutable) — every balance change, including the mint (`from = 0x0`) and burn (`to = 0x0`) legs emitted by ERC-20 `_mint` / `_burn`
- **`Investor`** — compliance record (verified, expiry, jurisdiction, frozen) plus the balance tracked from the RWAToken events
- **`Asset`** — provenance record: document hash, metadata URI, issuer, lifecycle status
- **`GlobalStat`** — platform-wide counters: total transfers, minted, burned, holder count, investor count

## Architecture

```
subgraph.yaml ─────► data sources (3 contracts, all events, start blocks)
schema.graphql ────► entities (Transfer, Investor, Asset, GlobalStat)
abis/*.json ───────► contract ABIs (forge inspect --json output)
src/mappings.ts ───► event handlers (AssemblyScript)
        │
        ▼
graph codegen ─────► generated/ (typed event + entity classes)
graph build ───────► build/ (WASM mappings)
graph deploy ──────► Graph Studio (IPFS + hosted node)
```

Handler highlights:

- `handleTransfer` updates sender / receiver balances, skipping the zero side on mint and burn legs, and maintains `holderCount` by tracking zero↔nonzero balance transitions
- `handleInvestorVerified` mirrors the contract's semantics exactly — re-verification resets `frozen` to false
- `handleAssetRegistered` creates the asset with an empty `uri`; the first `AssetUpdated` event is the only one that carries it
- Balance math is defensively clamped (never negative) so incomplete indexing history can't produce negative balances

## Deploy

### 1. Install

```bash
npm install
```

### 2. Deploy

1. **Deploy the contracts first.** Run the CD workflow (`Actions → CD → Run workflow`) or
   `forge script script/DeployAll.s.sol --broadcast` — it prints the three deployed addresses.

2. **Update `subgraph.yaml`:** replace the placeholder addresses and set each `startBlock`
   to its deployment block.

3. **Authenticate with Graph Studio** (deploy key from the root `.env` as `GRAPH_DEPLOY_KEY`):

   ```bash
   npx graph auth <GRAPH_DEPLOY_KEY>
   ```

4. **Build and deploy** (slug from the root `.env` as `SUBGRAPH_SLUG`):

   ```bash
   npx graph codegen
   npx graph build
   npx graph deploy rwa-assets --deploy-key <GRAPH_DEPLOY_KEY> --version-label v0.0.1
   ```

5. **Wire the frontend:** copy the query URL printed by Studio into
   `frontend/.env.local` as `NEXT_PUBLIC_SUBGRAPH_URL`.

## Live Deployment (Sepolia)

- **Subgraph:** [`rwa-assets` on Graph Studio](https://thegraph.com/studio/subgraph/rwa-assets)
- **Query endpoint:** `https://api.studio.thegraph.com/query/1760076/rwa-assets/v0.0.1`

Example query:

```bash
curl https://api.studio.thegraph.com/query/1760076/rwa-assets/v0.0.1 \
  -H "Content-Type: application/json" \
  -d '{"query": "{ globalStats(first: 1) { totalTransfers totalMinted holderCount investorCount } }"}'
```

## Verify

```bash
npx graph codegen   # catches schema / ABI mismatches
npx graph build     # compiles mappings to WASM
```

Both must pass before a deploy. `graph codegen` regenerates the typed classes in `generated/`; `graph build` is the deployment artifact.
