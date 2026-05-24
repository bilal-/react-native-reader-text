# Highlights

Highlights are native background spans over logical UTF-16 ranges.

```tsx
<ReaderText
  text={text}
  highlights={[
    { id: 'h1', start: 10, end: 30, color: '#FFE58A' },
  ]}
/>
```

Rules for v1:

1. Invalid ranges are ignored.
2. Ranges are local to the rendered `ReaderText` instance.
3. Overlapping highlights are allowed. Native last-applied behavior may vary slightly by platform.
4. The library renders highlights but does not store them.

Consumer apps should persist highlight IDs, paragraph/block IDs, ranges, colors, and optional note metadata.
