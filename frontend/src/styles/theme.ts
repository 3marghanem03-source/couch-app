export const theme = {
  colors: {
    background: '#000000',
    surface: '#0f0f0f',
    surface2: '#151515',
    text: '#FFFFFF',
    mutedText: '#B8B8B8',
    border: '#262626',
    primary: '#E10600', // red accent
    primaryPressed: '#B80400',
    danger: '#FF3B30',
  },
  spacing: {
    xs: 8,
    sm: 12,
    md: 16,
    lg: 24,
    xl: 32,
  },
  radius: {
    sm: 10,
    md: 14,
    lg: 18,
  },
  typography: {
    h1: 28,
    h2: 22,
    body: 16,
    button: 16,
    small: 13,
  },
} as const;

export type Theme = typeof theme;

