import { ConnectButton } from '@/components/ConnectButton';
import { TokenPanel } from '@/components/TokenPanel';

export default function Home() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-100">
      {/* testnet demo banner */}
      <div className="border-b border-amber-800/40 bg-amber-950/30 px-6 py-2 text-center text-sm text-amber-300">
        Testnet demo — not investment advice, not a securities offering, no real asset is tokenized.
      </div>

      <header className="border-b border-slate-800 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="h-8 w-8 rounded-lg bg-gradient-to-br from-emerald-400 to-cyan-500" />
          <span className="font-semibold text-lg">RWA Token Platform</span>
        </div>
        <ConnectButton />
      </header>

      <section className="px-6 py-10 max-w-5xl mx-auto space-y-8">
        <div>
          <p className="text-sm font-medium uppercase tracking-widest text-emerald-400">
            Real World Assets · On-chain
          </p>
          <h1 className="mt-3 text-4xl font-bold leading-tight">
            Tokenize real-world assets with{' '}
            <span className="bg-gradient-to-r from-emerald-400 to-cyan-500 bg-clip-text text-transparent">
              compliant Solidity contracts
            </span>
          </h1>
          <p className="mt-4 max-w-2xl text-slate-400">
            A Foundry smart-contract project paired with a Next.js dApp. Contracts in{' '}
            <code className="rounded bg-slate-800 px-1.5 py-0.5 text-sm">src/</code>, tests in{' '}
            <code className="rounded bg-slate-800 px-1.5 py-0.5 text-sm">test/</code>, this frontend in{' '}
            <code className="rounded bg-slate-800 px-1.5 py-0.5 text-sm">frontend/</code>.
          </p>
        </div>

        <TokenPanel />

        <div className="grid gap-6 sm:grid-cols-3">
          {[
            { title: 'Smart Contracts', desc: 'RWA token + compliance registry + asset registry — 59 tests, invariant-verified.' },
            { title: 'dApp Frontend', desc: 'Next.js 14 + wagmi v2 + viem. Registry pre-flight before every transfer.' },
            { title: 'Security First', desc: 'Freeze-don\'t-clawback design. Invariants verify 128k+ random sequences.' },
          ].map((card) => (
            <div key={card.title} className="rounded-xl border border-slate-800 bg-slate-900/60 p-6">
              <h3 className="font-semibold text-emerald-400">{card.title}</h3>
              <p className="mt-2 text-sm text-slate-400">{card.desc}</p>
            </div>
          ))}
        </div>
      </section>

      <footer className="border-t border-slate-800 px-6 py-6 text-center text-sm text-slate-500">
        RWA Token Platform · Foundry + Next.js
      </footer>
    </main>
  );
}
