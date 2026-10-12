'use client';

import { useQuery } from '@tanstack/react-query';
import { formatUnits } from 'viem';
import { fetchGlobalStats, subgraphConfigured } from '@/lib/subgraph';
import { StatCard } from '@/components/ui';

export function GlobalStats() {
  const { data } = useQuery({
    queryKey: ['globalStats'],
    queryFn: fetchGlobalStats,
    enabled: subgraphConfigured(),
    refetchInterval: 60_000,
  });

  if (!subgraphConfigured() || !data) return null;

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <StatCard label="Transfers" value={data.totalTransfers} />
      <StatCard label="Total minted" value={formatUnits(BigInt(data.totalMinted), 18)} suffix="RWA" />
      <StatCard label="Total burned" value={formatUnits(BigInt(data.totalBurned), 18)} suffix="RWA" />
      <StatCard label="Holders" value={String(data.holderCount)} />
    </div>
  );
}
