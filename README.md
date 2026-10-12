# Praedium — Real World Asset Tokenization Platform

Tokenize real-world assets on-chain **without losing compliance control**.

> Live on Sepolia testnet — [contracts](#live-deployment-sepolia) · [subgraph](#live-deployment-sepolia) · [frontend docs](frontend/README.md) · [subgraph docs](subgraph/README.md)

## The Problem

Tokenizing real-world assets — real estate, private credit, invoices — promises 24/7 liquidity and programmable ownership. But the moment a token represents a regulated security, every transfer must satisfy KYC, sanctions screening, and jurisdictional rules. Today those rules live in off-chain compliance systems.

The gap: **an ERC-20 token has no idea who is allowed to hold it.** A transfer between two sanctioned wallets succeeds on-chain while failing off-chain, and there is no way to enforce the rule at the protocol level. Wrapping checks in a centralized gateway just recreates the custodian you were trying to disintermediate.

## The Solution

Praedium is a compliance-gated token: **every balance change — transfer, mint, burn — passes a single on-chain check against an investor registry before it executes.** There is no transfer path that bypasses the gate. Compliance stops being a promise in a PDF and becomes a property of the protocol.

## Architecture

```
                    ┌─────────────┐     ┌──────────────────┐
                    │  Investor   │     │   Next.js dApp   │
                    │  (wallet)   │◄───►│  wagmi + Reown   │
                    └─────────────┘     └────────┬─────────┘
                                                 │
                            reads / writes       │ indexes events
                                                 ▼
                    ┌────────────────────────────────────────┐
                    │            Sepolia (EVM)               │
                    │                                        │
                    │   ┌────────────┐      ┌──────────────┐ │
                    │   │  RWAToken  │─────►│  Compliance  │ │
                    │   │  (ERC-20)  │ gate │   Registry   │ │
                    │   └─────┬──────┘      └──────────────┘ │
                    │         │                              │
                    │         ▼            ┌──────────────┐  │
                    │   ┌────────────┐     │    Asset     │  │
                    │   │  _update() │────►│   Registry   │  │
                    │   └────────────┘     └──────────────┘  │
                    └────────────────────────────────────────┘
                                                 │
                                                 ▼
                                        ┌──────────────┐
                                        │ The Graph    │
                                        │  subgraph    │
                                        └──────────────┘
```

Three contracts, one gate:

- **`RWAToken`** — ERC-20 with a single `_update` override. Every transfer, mint, and burn consults the compliance registry first. Custom errors, role-gated mint/burn, pausable.
- **`ComplianceRegistry`** — investor eligibility: verify / revoke / freeze with KYC expiry, jurisdiction codes, and packed storage (one slot per investor). Policy is read-only from the token's perspective.
- **`AssetRegistry`** — asset provenance: document hash, metadata URI, valuation, lifecycle status. The token constructor validates the backing asset exists.

## Features

- **Compliance-gated transfers** — one `_update` override is the single choke point; no entry point can bypass it
- **Investor lifecycle** — verify, revoke, freeze, batch-verify with expiry and jurisdiction
- **Asset provenance** — on-chain registry of the real-world backing, validated at token construction
- **Role-based administration** — `MINTER_ROLE`, `PAUSER_ROLE`, `COMPLIANCE_OFFICER_ROLE`, `ASSET_ADMIN_ROLE`
- **Freeze-don't-clawback** — frozen holders keep their balance frozen until legal resolution; there is deliberately **no forced-transfer function** (a legal process, not a contract call)
- **Subgraph indexing** — transfers, investor status, asset lifecycle, and platform counters
- **Role-aware dApp** — the interface shows only what the connected wallet can do, and pre-flights every transfer against the registry so a doomed transaction never gets signed
- **59 tests** — unit, fuzz, and invariant suites (128k+ randomized call sequences)

## Live Deployment (Sepolia)

| Contract | Address | Verified |
|----------|---------|----------|
| RWAToken | [`0x53FfF7C20B6DBD66234D769d41EC4C1fA698e109`](https://sepolia.etherscan.io/address/0x53FfF7C20B6DBD66234D769d41EC4C1fA698e109) | ✅ Etherscan |
| ComplianceRegistry | [`0xC59Ae783679AD55b0d85b2a3F51aC3a652212dF5`](https://sepolia.etherscan.io/address/0xC59Ae783679AD55b0d85b2a3F51aC3a652212dF5) | ✅ Etherscan |
| AssetRegistry | [`0xDbbB1D614C642707e92019828b884520357c772c`](https://sepolia.etherscan.io/address/0xDbbB1D614C642707e92019828b884520357c772c) | ✅ Etherscan |

**Subgraph:** [`rwa-assets` on Graph Studio](https://thegraph.com/studio/subgraph/rwa-assets)
**Query endpoint:** `https://api.studio.thegraph.com/query/1760076/rwa-assets/v0.0.1`

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast)
- [Node.js](https://nodejs.org) 20+
- A wallet with Sepolia ETH ([faucet](https://sepoliafaucet.com)) for deploying

### Clone and build

```bash
git clone <your-fork-url>
cd praedium

# Contracts
forge install          # fetch submodules (forge-std, OpenZeppelin)
forge build            # compile
forge test             # run the 59-test suite
forge coverage         # coverage report (CI uploads to Codecov)

# Frontend
cd frontend
npm install
cp .env.example .env.local   # fill in your Reown project ID + RPC
npm run dev                  # http://localhost:3000

# Subgraph
cd ../subgraph
npm install
npx graph codegen && npx graph build
```

### Running against the live deployment

The frontend `.env.local` accepts these values to talk to the deployed Sepolia contracts and subgraph:

```bash
NEXT_PUBLIC_REOWN_PROJECT_ID=<from cloud.reown.com>
NEXT_PUBLIC_SEPOLIA_RPC_URL=<your RPC endpoint>
NEXT_PUBLIC_RWA_TOKEN_ADDRESS_SEPOLIA=0x53FfF7C20B6DBD66234D769d41EC4C1fA698e109
NEXT_PUBLIC_COMPLIANCE_REGISTRY_ADDRESS_SEPOLIA=0xC59Ae783679AD55b0d85b2a3F51aC3a652212dF5
NEXT_PUBLIC_ASSET_REGISTRY_ADDRESS_SEPOLIA=0xDbbB1D614C642707e92019828b884520357c772c
NEXT_PUBLIC_SUBGRAPH_URL=https://api.studio.thegraph.com/query/1760076/rwa-assets/v0.0.1
```

### Deploying your own instance

```bash
# Fill .env (root) with your deployer key, RPC, and Etherscan API key
forge script script/DeployAll.s.sol --broadcast --verify \
  --rpc-url $SEPOLIA_RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY
```

The script deploys all three contracts in dependency order, registers the backing asset, and grants roles. Then update `subgraph/subgraph.yaml` with the new addresses and deploy the subgraph (see [subgraph/README.md](subgraph/README.md)).

## Testing

```bash
forge test                    # 59 tests: unit + fuzz + invariant
forge test --match-test test_transfer   # filter
forge coverage --report lcov  # coverage
```

CI (`.github/workflows/ci.yml`) runs format check, build, tests, and coverage upload on every push. Deployment runs manually from the Actions tab (`.github/workflows/cd.yml`).

## Security Notes

- The compliance gate lives in a single `_update` override — audited by construction, no modifier sprawl
- Custom errors over revert strings; every privileged function has negative authorization tests
- Frozen balances never grow and are never clawed back — legal processes handle disposition off-chain
- The `AssetStatus` enum is informational; the token's pause mechanism is the only transfer halt
- Testnet-grade: internal security review, not an external audit

## Project Layout

```
praedium/
├── src/            # Solidity contracts (RWAToken, ComplianceRegistry, AssetRegistry)
├── test/           # Foundry test suite (unit, fuzz, invariant)
├── script/         # Deploy scripts
├── frontend/       # Next.js dApp — see frontend/README.md
└── subgraph/       # The Graph subgraph — see subgraph/README.md
```

## License

MIT
