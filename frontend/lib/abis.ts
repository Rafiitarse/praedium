// Minimal human-readable ABIs — kept small on purpose; raw Foundry JSON bloat the bundle.
// Regenerate with `forge inspect <Contract> abi --json` if the contract surface changes.

export const RWA_TOKEN_ABI = [
  // ERC-20 reads
  'function name() view returns (string)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address account) view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function paused() view returns (bool)',
  'function assetId() view returns (uint256)',
  'function assetURI() view returns (string)',
  // ERC-20 writes
  'function transfer(address to, uint256 amount) returns (bool)',
  'function approve(address spender, uint256 amount) returns (bool)',
  // RWA writes
  'function mint(address to, uint256 amount)',
  'function burn(address from, uint256 amount)',
  'function pause()',
  'function unpause()',
  // access control (OpenZeppelin AccessControl)
  'function hasRole(bytes32 role, address account) view returns (bool)',
  'function MINTER_ROLE() view returns (bytes32)',
  'function PAUSER_ROLE() view returns (bytes32)',
  // events
  'event Transfer(address indexed from, address indexed to, uint256 value)',
  'event AssetMinted(uint256 indexed assetId, address indexed to, uint256 amount)',
  'event AssetBurned(uint256 indexed assetId, address indexed from, uint256 amount)',
] as const;

export const COMPLIANCE_REGISTRY_ABI = [
  // reads
  'function isVerified(address investor) view returns (bool)',
  'function isTransferAllowed(address from, address to) view returns (bool)',
  'function investorStatus(address investor) view returns ((bool, uint64, uint16, bool))',
  // writes
  'function verify(address investor, uint64 expiry, uint16 jurisdiction)',
  'function revoke(address investor)',
  'function setFrozen(address investor, bool frozen)',
  'function batchVerify(address[] investors, uint64[] expiries, uint16[] jurisdictions)',
  // access control
  'function hasRole(bytes32 role, address account) view returns (bool)',
  'function COMPLIANCE_OFFICER_ROLE() view returns (bytes32)',
  // events
  'event InvestorVerified(address indexed investor, uint64 expiry, uint16 jurisdiction)',
  'event InvestorRevoked(address indexed investor)',
  'event InvestorFrozen(address indexed investor, bool frozen)',
] as const;

export const ASSET_REGISTRY_ABI = [
  // reads
  'function getAsset(uint256 assetId) view returns ((bytes32, string, address, uint256, uint64, uint8))',
  // writes
  'function registerAsset(bytes32 docHash, string uri, address issuer, uint256 valuation, uint64 valuationAt) returns (uint256 assetId)',
  'function updateAsset(uint256 assetId, bytes32 docHash, string uri, uint256 valuation, uint64 valuationAt)',
  'function setStatus(uint256 assetId, uint8 status)',
  'function batchSetStatus(uint256[] ids, uint8[] statuses)',
  // access control
  'function hasRole(bytes32 role, address account) view returns (bool)',
  'function ASSET_ADMIN_ROLE() view returns (bytes32)',
  // events
  'event AssetRegistered(uint256 indexed assetId, bytes32 docHash, address indexed issuer)',
  'event AssetUpdated(uint256 indexed assetId, bytes32 docHash, string uri, uint256 valuation, uint64 valuationAt)',
  'event AssetStatusChanged(uint256 indexed assetId, uint8 status)',
] as const;
