// Minimal human-readable ABIs — kept small on purpose; raw Foundry JSON bloat the bundle.
// Regenerate with `forge inspect RWAToken abi` if the contract surface changes.

export const RWA_TOKEN_ABI = [
  // reads
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function paused() view returns (bool)',
  'function assetId() view returns (uint256)',
  'function assetURI() view returns (string)',
  // writes
  'function transfer(address to, uint256 amount) returns (bool)',
  'function approve(address spender, uint256 amount) returns (bool)',
  'function mint(address to, uint256 amount)',
  'function burn(address from, uint256 amount)',
  // events
  'event Transfer(address indexed from, address indexed to, uint256 value)',
  'event AssetMinted(uint256 indexed assetId, address indexed to, uint256 amount)',
  'event AssetBurned(uint256 indexed assetId, address indexed from, uint256 amount)',
] as const;

export const COMPLIANCE_REGISTRY_ABI = [
  // reads
  'function isVerified(address investor) view returns (bool)',
  'function isTransferAllowed(address from, address to) view returns (bool)',
  'function investorStatus(address investor) view returns ((bool verified, uint64 expiry, uint16 jurisdiction, bool frozen))',
  // events
  'event InvestorVerified(address indexed investor, uint64 expiry, uint16 jurisdiction)',
  'event InvestorRevoked(address indexed investor)',
  'event InvestorFrozen(address indexed investor, bool frozen)',
] as const;
