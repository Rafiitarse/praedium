# Praedium Frontend

The dApp interface for Praedium — a compliance-gated RWA token platform.

> Part of [Praedium](../README.md) · contracts, architecture, and deployment overview live in the root README · indexer docs in [subgraph/README.md](../subgraph/README.md)

## What This Is

A role-aware transaction interface for the three Praedium contracts. No marketing pages, no dashboards-for-dashboards — just the actions the connected wallet is authorized to perform, with the compliance registry consulted **before** a transaction is signed so a doomed transfer never costs gas.

The interface adapts to the wallet:

- **Investor** — balance, compliance status (whitelist / expiry / frozen), transfer with registry pre-flight, transfer history
- **Issuer** (holds `MINTER_ROLE`) — mint, burn, pause / unpause
- **Compliance Officer** (holds `COMPLIANCE_OFFICER_ROLE`) — verify, revoke, freeze / unfreeze investors
- **Asset Admin** (holds `ASSET_ADMIN_ROLE`) — register, update, and set status on backing assets

Role detection happens through `hasRole` multicall at connect time; panels appear only for roles the wallet actually holds.

## Stack

| Layer | Choice |
|-------|--------|
| Framework | Next.js 14 (App Router), TypeScript |
| Styling | Tailwind CSS, custom glass design system |
| Wallet | wagmi v2 + viem, Reown AppKit |
| Data | wagmi contract reads (live state) + The Graph subgraph (history) |
| Chain | Sepolia |

## Architecture

```
lib/
├── wagmi.ts          # Reown AppKit adapter — wallet config, Sepolia network + RPC
├── abis.ts           # Minimal human-readable ABIs for all three contracts
├── contracts.ts      # Chain-keyed address map (env-driven)
├── useRoles.ts       # hasRole multicall → role detection hook
└── subgraph.ts       # GraphQL client: transfers, global stats

components/
├── WalletButton.tsx        # Connect / switch network / disconnect
├── ContactFooter.tsx       # Email, GitHub, X, LinkedIn
├── GlobalStats.tsx         # Platform counters (from subgraph)
├── TransferHistory.tsx     # Per-address transfer list (from subgraph)
├── ui.tsx                  # Design system: PanelCard, Button, Badge, StatCard…
└── panels/
    ├── InvestorPanel.tsx   # balance, status, transfer + pre-flight
    ├── IssuerPanel.tsx     # mint, burn, pause
    ├── CompliancePanel.tsx # verify, revoke, freeze
    └── AssetPanel.tsx      # register, update, set status
```

### Data flow

1. **Live state** (balances, roles, pause status) comes from `useReadContract` — wagmi's typed contract reads against the configured RPC. Multicall is used for role checks.
2. **History and aggregates** (transfers, global stats) come from the subgraph via `lib/subgraph.ts`. Both components degrade gracefully when `NEXT_PUBLIC_SUBGRAPH_URL` is unset.
3. **Writes** go through `useWriteContract` with a shared `TxStatus` component showing pending / confirmed (with an Etherscan link) / failed states.

### The registry pre-flight

The Investor panel reads `isTransferAllowed(from, to)` on every keystroke of a valid recipient. If the registry would reject the transfer, the button is disabled and the reason shown — the UI never lets the user sign a transaction the contract would revert.

### Design system

Dark, non-flat: glassmorphism surfaces (`backdrop-blur`, translucent panels), gradient borders and accents, ambient glow background, hover lifts, skeleton loading for on-chain reads, animated fade-ins. Tokens live in `app/globals.css` and the extended Tailwind theme. WCAG AA contrast floor; `prefers-reduced-motion` respected.

## Getting Started

```bash
cd frontend
npm install
cp .env.example .env.local   # fill in values (see below)
npm run dev                  # http://localhost:3000
```

### Environment

Copy `.env.example` to `.env.local` and fill in:

```bash
# Wallet (get one at cloud.reown.com)
NEXT_PUBLIC_REOWN_PROJECT_ID=...

# RPC — a public endpoint keeps keys out of the client bundle
NEXT_PUBLIC_SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com

# Deployed contracts (values from the root README's Live Deployment section)
NEXT_PUBLIC_RWA_TOKEN_ADDRESS_SEPOLIA=0x...
NEXT_PUBLIC_COMPLIANCE_REGISTRY_ADDRESS_SEPOLIA=0x...
NEXT_PUBLIC_ASSET_REGISTRY_ADDRESS_SEPOLIA=0x...

# Subgraph (from subgraph/README.md deploy step)
NEXT_PUBLIC_SUBGRAPH_URL=https://api.studio.thegraph.com/query/...
```

> **Note:** every `NEXT_PUBLIC_*` value is compiled into the public client bundle. Only non-secret identifiers belong there. If you swap the public RPC for a keyed one, the key becomes public.

### Scripts

```bash
npm run dev         # dev server
npm run build       # production build
npm run typecheck   # tsc --noEmit
```

## Notes

- The app is Sepolia-only; the network selector offers a one-click switch when connected elsewhere.
- Addresses are read from the env-driven chain map in `lib/contracts.ts` — nothing is hardcoded in components.
- Contract surfaces live in `lib/abis.ts` as minimal human-readable ABIs (raw Foundry JSON bloats the bundle).
