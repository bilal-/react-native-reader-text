# Typography

`segments` allow one `ReaderText` instance to render a single logical paragraph with per-language typography.

```tsx
<ReaderText
  segments={[
    { text: 'English ', lang: 'en' },
    { text: 'النص العربي ', lang: 'ar' },
    { text: 'اردو متن', lang: 'ur' },
  ]}
  typography={[
    { lang: 'en', fontScale: 1.0, lineHeightMultiplier: 1.35 },
    { lang: 'ar', fontScale: 1.15, lineHeightMultiplier: 1.55 },
    { lang: 'ur', fontScale: 1.25, lineHeightMultiplier: 1.9, baselineOffset: -1 },
  ]}
/>
```

The library relies on native bidi behavior. Do not reverse strings manually. Use `baseDirection="auto"` unless a paragraph has a known explicit direction.

Different scripts and fonts can need different scale, line height, and baseline tuning. The defaults should be treated as a starting point, not a guarantee of pixel parity.

`lineHeightMultiplier` is applied at paragraph level using the largest multiplier from the rendered segments. If `textStyle.lineHeight` is set, that value is treated as the base line height and multiplied. Without an explicit `lineHeight`, the native font size is used as the base.
