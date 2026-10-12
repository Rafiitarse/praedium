# Praedium Subgraph

Indexes the Praedium RWA contracts on The Graph:

| Data source | Events indexed |
|-------------|----------------|
| `RWAToken` | `Transfer`, `AssetMinted`, `AssetBurned` |
| `ComplianceRegistry` | `InvestorVerified`, `InvestorRevoked`, `InvestorFrozen` |
| `AssetRegistry` | `AssetRegistered`, `AssetUpdated`, `AssetStatusChanged` |

Entities: `Transfer`, `Investor` (compliance record + balance), `Asset` (provenance + lifecycle), `GlobalStat` (platform counters).

## Setup

```bash
npm install
```

## Deploy

1. **Deploy the contracts first.** Run the CD workflow (`Actions → CD → Run workflow`) or
   `forge script script/DeployAll.s.sol --broadcast` — it prints the three deployed addresses.

2. **Update `subgraph.yaml`:** replace the three placeholder addresses
   (`0x…0001`, `0x…0002`, `0x…0003`) with the real ones and set each `startBlock`
   to its deployment block.

3. **Authenticate with Graph Studio:**

   ```bash
   npx graph auth https://api.thegraph.com/deploy/ <GRAPH_DEPLOY_KEY>
   ```

   The deploy key lives in the root `.env` as `GRAPH_DEPLOY_KEY`.

4. **Build and deploy** (slug `rwa-assets`, see `SUBGRAPH_SLUG` in root `.env`):

   ```bash
   npm run codegen
   npm run build
   npm run deploy
   ```

5. **Wire the frontend:** copy the query URL printed by Studio into
   `frontend/.env.local` as `NEXT_PUBLIC_SUBGRAPH_URL`.
