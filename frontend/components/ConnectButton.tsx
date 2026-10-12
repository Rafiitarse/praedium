'use client';

import { useAccount, useConnect, useDisconnect, useChainId, useSwitchChain } from 'wagmi';
import { sepolia } from 'wagmi/chains';
import { SEPOLIA_CHAIN_ID, isDeployed } from '@/lib/contracts';

function shortAddress(addr: string) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

export function ConnectButton() {
  const { address, isConnected } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();

  if (!isConnected) {
    const injected = connectors[0];
    return (
      <button
        onClick={() => connect({ connector: injected })}
        disabled={isPending}
        className="rounded-lg bg-emerald-500 px-5 py-2.5 font-semibold text-slate-950 transition hover:bg-emerald-400 disabled:opacity-50"
      >
        {isPending ? 'Connecting…' : 'Connect Wallet'}
      </button>
    );
  }

  const wrongNetwork = chainId !== SEPOLIA_CHAIN_ID;

  return (
    <div className="flex items-center gap-3">
      {wrongNetwork ? (
        <button
          onClick={() => switchChain({ chainId: sepolia.id })}
          className="rounded-lg bg-amber-500 px-4 py-2 text-sm font-semibold text-slate-950"
        >
          Switch to Sepolia
        </button>
      ) : null}
      <div className="flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-900 px-4 py-2 text-sm">
        <span className={`h-2 w-2 rounded-full ${wrongNetwork ? 'bg-amber-400' : 'bg-emerald-400'}`} />
        <span className="font-mono">{shortAddress(address!)}</span>
      </div>
      <button
        onClick={() => disconnect()}
        className="rounded-lg border border-slate-700 px-3 py-2 text-sm text-slate-400 transition hover:text-slate-200"
      >
        Disconnect
      </button>
    </div>
  );
}
