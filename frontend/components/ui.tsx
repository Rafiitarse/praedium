import {
  ButtonHTMLAttributes,
  InputHTMLAttributes,
  ReactNode,
  SelectHTMLAttributes,
} from 'react';

/* ── Panel ── */

export function PanelCard({
  children,
  className = '',
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`glass-panel gradient-ring p-6 ${className}`}>{children}</section>
  );
}

/* ── Buttons ── */

type ButtonVariant = 'primary' | 'secondary' | 'danger';

const buttonStyles: Record<ButtonVariant, string> = {
  primary:
    'bg-gradient-to-r from-emerald-400 to-cyan-400 font-semibold text-slate-950 hover:shadow-glow hover:-translate-y-0.5 active:translate-y-0',
  secondary:
    'border border-white/10 bg-white/[0.04] text-slate-200 hover:bg-white/[0.08] hover:-translate-y-0.5 active:translate-y-0',
  danger:
    'border border-rose-500/30 bg-rose-500/10 text-rose-300 hover:bg-rose-500/20 hover:-translate-y-0.5 active:translate-y-0',
};

export function Button({
  variant = 'primary',
  className = '',
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: ButtonVariant }) {
  return (
    <button
      className={`inline-flex items-center justify-center gap-2 rounded-xl px-4 py-2.5 text-sm transition-all duration-200 disabled:pointer-events-none disabled:opacity-40 ${buttonStyles[variant]} ${className}`}
      {...props}
    />
  );
}

/* ── Inputs ── */

const inputBase =
  'w-full rounded-xl border border-white/10 bg-surface-2/80 px-4 py-2.5 text-sm text-slate-100 placeholder:text-slate-500 transition-colors focus:border-emerald-400/50 focus:outline-none';

export function TextInput({ className = '', ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return <input className={`${inputBase} font-mono ${className}`} {...props} />;
}

export function Select({ className = '', ...props }: SelectHTMLAttributes<HTMLSelectElement>) {
  return <select className={`${inputBase} ${className}`} {...props} />;
}

export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <label className="block space-y-1.5">
      <span className="text-xs font-medium uppercase tracking-wider text-slate-400">
        {label}
      </span>
      {children}
      {hint ? <span className="block text-xs text-slate-500">{hint}</span> : null}
    </label>
  );
}

/* ── Badges ── */

type BadgeTone = 'success' | 'warning' | 'error' | 'info' | 'neutral';

const badgeStyles: Record<BadgeTone, string> = {
  success: 'border-emerald-500/30 bg-emerald-500/15 text-emerald-300',
  warning: 'border-amber-500/30 bg-amber-500/15 text-amber-300',
  error: 'border-rose-500/30 bg-rose-500/15 text-rose-300',
  info: 'border-sky-500/30 bg-sky-500/15 text-sky-300',
  neutral: 'border-white/10 bg-white/[0.06] text-slate-300',
};

export function Badge({
  tone = 'neutral',
  children,
}: {
  tone?: BadgeTone;
  children: ReactNode;
}) {
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold ${badgeStyles[tone]}`}
    >
      {children}
    </span>
  );
}

/* ── Stats & skeletons ── */

export function StatCard({
  label,
  value,
  suffix,
}: {
  label: string;
  value: string;
  suffix?: string;
}) {
  return (
    <div className="glass-panel p-4">
      <p className="text-xs font-medium uppercase tracking-wider text-slate-400">{label}</p>
      <p className="mt-1 font-mono text-2xl font-bold text-slate-100">
        {value}
        {suffix ? (
          <span className="ml-1 text-sm font-normal text-slate-400">{suffix}</span>
        ) : null}
      </p>
    </div>
  );
}

export function Skeleton({ className = '' }: { className?: string }) {
  return <div className={`skeleton h-4 ${className}`} />;
}

export function Spinner({ className = '' }: { className?: string }) {
  return (
    <svg className={`h-4 w-4 animate-spin ${className}`} viewBox="0 0 24 24" fill="none">
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path
        className="opacity-75"
        fill="currentColor"
        d="M4 12a8 8 0 0 1 8-8V0C5.373 0 0 5.373 0 12h4z"
      />
    </svg>
  );
}

/* ── Transaction status ── */

export type TxState = 'idle' | 'pending' | 'success' | 'error';

export function TxStatus({
  state,
  hash,
  error,
}: {
  state: TxState;
  hash?: string;
  error?: string;
}) {
  if (state === 'idle') return null;
  if (state === 'pending') {
    return (
      <p className="flex items-center gap-2 text-sm text-amber-300">
        <Spinner /> Waiting for confirmation…
      </p>
    );
  }
  if (state === 'success') {
    return hash ? (
      <a
        href={`https://sepolia.etherscan.io/tx/${hash}`}
        target="_blank"
        rel="noreferrer"
        className="text-sm text-emerald-400 transition-colors hover:text-emerald-300"
      >
        Transaction confirmed ↗
      </a>
    ) : (
      <p className="text-sm text-emerald-400">Transaction confirmed</p>
    );
  }
  return <p className="text-sm text-rose-400">{error ?? 'Transaction failed'}</p>;
}
