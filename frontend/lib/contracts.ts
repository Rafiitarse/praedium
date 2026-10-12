// Per-chain contract addresses — the single source of truth for the dApp.
// Nothing else hardcodes an address. Populate Sepolia after deployment
// (DeployAll.s.sol prints all three); mainnet stays stubbed until audit sign-off.
//
// Set via .env.local (gitignored):
//   NEXT_PUBLIC_RWA_TOKEN_ADDRESS_SEPOLIA=0x...
//   NEXT_PUBLIC_COMPLIANCE_REGISTRY_ADDRESS_SEPOLIA=0x...
//   NEXT_PUBLIC_ASSET_REGISTRY_ADDRESS_SEPOLIA=0x...

export interface ContractAddresses {
  rwaToken: `0x${string}`;
  complianceRegistry: `0x${string}`;
  assetRegistry: `0x${string}`;
}

export const SEPOLIA_CHAIN_ID = 11155111;
export const MAINNET_CHAIN_ID = 1;

const ZERO = '0x0000000000000000000000000000000000000000' as const;

export const CONTRACTS: Record<number, ContractAddresses> = {
  [SEPOLIA_CHAIN_ID]: {
    rwaToken: (process.env.NEXT_PUBLIC_RWA_TOKEN_ADDRESS_SEPOLIA ?? ZERO) as `0x${string}`,
    complianceRegistry: (process.env.NEXT_PUBLIC_COMPLIANCE_REGISTRY_ADDRESS_SEPOLIA ?? ZERO) as `0x${string}`,
    assetRegistry: (process.env.NEXT_PUBLIC_ASSET_REGISTRY_ADDRESS_SEPOLIA ?? ZERO) as `0x${string}`,
  },
  [MAINNET_CHAIN_ID]: {
    rwaToken: ZERO,
    complianceRegistry: ZERO,
    assetRegistry: ZERO,
  },
};

export function getContracts(chainId: number): ContractAddresses | undefined {
  return CONTRACTS[chainId];
}

export function isDeployed(chainId: number): boolean {
  const c = getContracts(chainId);
  return !!c && c.rwaToken !== ZERO;
}
