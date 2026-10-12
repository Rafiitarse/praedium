import { gql, request } from 'graphql-request';

const SUBGRAPH_URL = process.env.NEXT_PUBLIC_SUBGRAPH_URL ?? '';

export function subgraphConfigured(): boolean {
  return SUBGRAPH_URL.length > 0;
}

export interface Transfer {
  id: string;
  from: string;
  to: string;
  value: string;
  blockTimestamp: string;
  txHash: string;
}

export interface GlobalStats {
  totalTransfers: string;
  totalMinted: string;
  totalBurned: string;
  holderCount: number;
  investorCount: number;
}

const TRANSFERS_QUERY = gql`
  query Transfers($address: Bytes!, $first: Int!) {
    transfers(
      where: { or: [{ from: $address }, { to: $address }] }
      orderBy: blockTimestamp
      orderDirection: desc
      first: $first
    ) {
      id
      from
      to
      value
      blockTimestamp
      txHash
    }
  }
`;

export async function fetchTransfers(address: string, first = 20): Promise<Transfer[]> {
  if (!subgraphConfigured()) return [];
  const data = await request<{ transfers: Transfer[] }>(SUBGRAPH_URL, TRANSFERS_QUERY, {
    address: address.toLowerCase(),
    first,
  });
  return data.transfers;
}

const GLOBAL_STATS_QUERY = gql`
  query GlobalStats {
    globalStats(first: 1) {
      totalTransfers
      totalMinted
      totalBurned
      holderCount
      investorCount
    }
  }
`;

export async function fetchGlobalStats(): Promise<GlobalStats | null> {
  if (!subgraphConfigured()) return null;
  const data = await request<{ globalStats: GlobalStats[] }>(SUBGRAPH_URL, GLOBAL_STATS_QUERY);
  return data.globalStats[0] ?? null;
}
