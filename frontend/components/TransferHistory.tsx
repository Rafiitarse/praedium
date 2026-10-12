'use client';

import { useAccount } from 'wagmi';
import { useQuery } from '@tanstack/react-query';
import { formatUnits } from 'viem';
import { fetchTransfers, subgraphConfigured } from '@/lib/subgraph';
import { Badge, PanelCard, Skeleton } from '@/components/ui';

function shortAddress(addr: string) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

export function TransferHistory() {
  const { address } = useAccount();

  const { data, isLoading, isError } = useQuery({
    queryKey: ['transfers', address],
    queryFn: () => fetchTransfers(address!),
    enabled: !!address && subgraphConfigured(),
  });

  if (!subgraphConfigured()) return null;

  return (
    <PanelCard>
      <div className="flex items-center justify-between">
        <h3 className="font-semibold">Transfer history</h3>
        <span className="text-xs text-slate-500">via subgraph</span>
      </div>

      {isLoading ? (
        <div className="mt-4 space-y-2">
          <Skeleton />
          <Skeleton className="w-3/4" />
          <Skeleton className="w-1/2" />
        </div>
      ) : isError ? (
        <p className="mt-4 text-sm text-rose-400">
          Could not reach the subgraph. Check NEXT_PUBLIC_SUBGRAPH_URL.
        </p>
      ) : !data || data.length === 0 ? (
        <p className="mt-4 text-sm text-slate-400">No transfers yet.</p>
      ) : (
        <ul className="mt-4 divide-y divide-white/[0.06]">
          {data.map((t) => {
            const incoming = t.to.toLowerCase() === address?.toLowerCase();
            return (
              <li key={t.id} className="flex items-center justify-between gap-4 py-2.5 text-sm">
                <div className="flex items-center gap-2">
                  <Badge tone={incoming ? 'success' : 'neutral'}>
                    {incoming ? 'In' : 'Out'}
                  </Badge>
                  <span className="font-mono text-slate-300">
                    {shortAddress(incoming ? t.from : t.to)}
                  </span>
                </div>
                <div className="flex items-center gap-4">
                  <span className="font-mono text-slate-100">
                    {formatUnits(BigInt(t.value), 18)}
                  </span>
                  <a
                    href={`https://sepolia.etherscan.io/tx/${t.txHash}`}
                    target="_blank"
                    rel="noreferrer"
                    className="text-xs text-slate-500 transition-colors hover:text-emerald-400"
                  >
                    {new Date(Number(t.blockTimestamp) * 1000).toLocaleDateString()} ↗
                  </a>
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </PanelCard>
  );
}
