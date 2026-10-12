'use client';

import { keccak256, toBytes } from 'viem';
import { useAccount, useChainId, useReadContracts } from 'wagmi';
import { getContracts, isDeployed } from './contracts';
import {
  RWA_TOKEN_ABI,
  COMPLIANCE_REGISTRY_ABI,
  ASSET_REGISTRY_ABI,
} from './abis';

// Role constants must match the contracts: keccak256("<ROLE_NAME>").
const MINTER_ROLE = keccak256(toBytes('MINTER_ROLE'));
const PAUSER_ROLE = keccak256(toBytes('PAUSER_ROLE'));
const COMPLIANCE_OFFICER_ROLE = keccak256(toBytes('COMPLIANCE_OFFICER_ROLE'));
const ASSET_ADMIN_ROLE = keccak256(toBytes('ASSET_ADMIN_ROLE'));

export function useRoles() {
  const chainId = useChainId();
  const { address } = useAccount();
  const contracts = getContracts(chainId);
  const deployed = isDeployed(chainId);

  const { data, isLoading } = useReadContracts({
    contracts:
      deployed && address && contracts
        ? [
            {
              address: contracts.rwaToken,
              abi: RWA_TOKEN_ABI,
              functionName: 'hasRole',
              args: [MINTER_ROLE, address],
            },
            {
              address: contracts.rwaToken,
              abi: RWA_TOKEN_ABI,
              functionName: 'hasRole',
              args: [PAUSER_ROLE, address],
            },
            {
              address: contracts.complianceRegistry,
              abi: COMPLIANCE_REGISTRY_ABI,
              functionName: 'hasRole',
              args: [COMPLIANCE_OFFICER_ROLE, address],
            },
            {
              address: contracts.assetRegistry,
              abi: ASSET_REGISTRY_ABI,
              functionName: 'hasRole',
              args: [ASSET_ADMIN_ROLE, address],
            },
          ]
        : [],
    query: { enabled: !!deployed && !!address },
  });

  const held = (i: number) => data?.[i]?.status === 'success' && !!data[i].result;

  return {
    isLoading,
    isMinter: held(0),
    isPauser: held(1),
    isOfficer: held(2),
    isAssetAdmin: held(3),
  };
}
