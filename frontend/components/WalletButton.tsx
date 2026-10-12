'use client';

import { useAccount, useDisconnect, useChainId, useSwitchChain } from 'wagmi';
import { useAppKit } from '@reown/appkit/react';
import { sepolia } from 'wagmi/chains';
import { Button } from './ui';

function shortAddress(addr: string) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

export function WalletButton() {
  const { address, isConnected } = useAccount();
  const { open } = useAppKit();
  const { disconnect } = useDisconnect();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();

  if (!isConnected) {
    return (
      <Button onClick={() => open()} className="animate-pulse-glow">
        Connect Wallet
      </Button>
    );
  }

  const wrongNetwork = chainId !== sepolia.id;

  return (
    <div className="flex items-center gap-2">
      {wrongNetwork ? (
        <Button variant="secondary" onClick={() => switchChain({ chainId: sepolia.id })}>
          Switch to Sepolia
        </Button>
      ) : null}
      <button
        onClick={() => open()}
        className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/[0.04] px-3.5 py-2 font-mono text-sm text-slate-200 transition-colors hover:bg-white/[0.08]"
      >
        <span
          className={`h-2 w-2 rounded-full ${wrongNetwork ? 'bg-amber-400' : 'bg-emerald-400'}`}
        />
        {shortAddress(address!)}
      </button>
      <Button
        variant="secondary"
        onClick={() => disconnect()}
        className="px-3 py-2 text-xs"
      >
        Disconnect
      </Button>
    </div>
  );
}
