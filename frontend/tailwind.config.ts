import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['var(--font-inter)', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['var(--font-mono)', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      colors: {
        surface: {
          0: '#05070d',
          1: '#0b101c',
          2: '#121a2b',
        },
        accent: {
          DEFAULT: '#34d399',
          soft: '#22d3ee',
        },
      },
      boxShadow: {
        glow: '0 0 24px -4px rgb(52 211 153 / 0.25)',
        'glow-lg': '0 0 40px -6px rgb(52 211 153 / 0.35)',
        panel: '0 8px 32px -8px rgb(0 0 0 / 0.5)',
      },
      keyframes: {
        'fade-up': {
          from: { opacity: '0', transform: 'translateY(8px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
      },
      animation: {
        'fade-up': 'fade-up 0.35s ease-out both',
      },
    },
  },
  plugins: [],
};

export default config;
