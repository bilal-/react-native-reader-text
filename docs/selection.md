# Selection

`ReaderText` emits logical UTF-16 offsets:

```ts
{
  text: string;
  start: number;
  end: number;
}
```

Offsets are based on the concatenated logical text. For `segments`, concatenate every segment's `text` in order before applying offsets.

The native selection menu can include custom app-provided items:

```tsx
menuItems={[
  { id: 'highlight', title: 'Highlight' },
  { id: 'note', title: 'Note' },
]}
```

When a menu item is tapped, `onMenuAction` receives the item identity, selection, and a best-effort window-coordinate anchor rectangle. Use the anchor for app-owned popovers such as color pickers or note editors.

Platform menu ordering and default actions are not guaranteed to match exactly.

Custom selection menu items are available on Android and on iOS 16 and later. On iOS 13-15, the default selection menu may appear without app-provided actions.

`onSelection` can fire repeatedly while the user adjusts selection handles. Debounce it in app code if selection updates trigger expensive work.
