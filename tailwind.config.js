/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          'Inter',
          'SF Pro Text',
          'Segoe UI',
          'system-ui',
          'sans-serif',
        ],
      },
      colors: {
        ink: '#111111',
        muted: '#6b7280',
        line: '#e5e7eb',
        surface: '#fafafa',
      },
      borderRadius: {
        lg2: '10px',
      },
    },
  },
  plugins: [],
}
