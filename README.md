# react-native-reader-text

Native-quality selectable text for React Native book readers, study apps, document readers, annotation apps, and multilingual reading experiences.

`react-native-reader-text` provides a small native reader text primitive:

On iOS it uses `UITextView`. On Android it uses `TextView`, not `EditText`.

It is intentionally not a rich text editor, EPUB engine, Markdown parser, HTML renderer, or WebView wrapper.

## Why

React Native's built-in text components are excellent for many app screens, but serious reading experiences need more control. Reader apps often require native text selection, custom selection actions, highlights, notes, sharing, RTL/LTR support, and language-specific typography.

On iOS, developers sometimes use `TextInput` with `editable={false}` because it maps to `UITextView`. This can work well for read-only selectable text. On Android, however, `TextInput` maps to `EditText`, which is designed for editing rather than read-only book rendering. This leads to inconsistent behavior and makes it harder to build polished readers.

`react-native-reader-text` gives apps a native read-only text surface with selectable text, custom menu hooks, logical UTF-16 ranges, highlights, and multilingual segment styling.

## Install

Bare React Native:

```sh
npm install react-native-reader-text
cd ios && pod install
```

Expo:

```sh
npx expo install react-native-reader-text
npx expo prebuild
npx expo run:ios
# or
npx expo run:android
```

Expo users need a development build because this package includes native Android/iOS code. It will not work in Expo Go.

## Mental Model

Use one `ReaderText` per paragraph, verse, list item, quote, or document block. The component reports ranges relative to that one block, using JavaScript-style UTF-16 string offsets.

Your app owns product behavior:

1. Store highlights.
2. Open note editors.
3. Present share sheets.
4. Render footnote sheets.
5. Sync annotations.
6. Decide paragraph or document IDs.

The library owns the native text surface:

1. Render native read-only text.
2. Handle native selection.
3. Add custom native menu hooks.
4. Report selected text and offsets.
5. Draw highlight spans.
6. Expose generic tappable ranges.
7. Apply multilingual typography hints.

## Basic Usage

```tsx
import { ReaderText } from 'react-native-reader-text';

export default function App() {
  return <ReaderText text="Long press to select this text." selectable />;
}
```

## Custom Menu Actions

The library adds app-provided items to the native selection menu and reports what the user selected. The `id` is the stable action identity; `title` is only display text and can be translated.

```tsx
<ReaderText
  text={chapterText}
  selectable
  menuItems={[
    { id: 'highlight', title: 'Highlight' },
    { id: 'note', title: 'Note' },
    { id: 'share', title: 'Share' },
  ]}
  onMenuAction={({ id, selection, anchor }) => {
    if (id === 'highlight') {
      saveHighlight(selection.start, selection.end);
    }

    if (id === 'note') {
      openNotePopover(selection, anchor);
    }

    if (id === 'share') {
      shareText(selection.text);
    }
  }}
/>
```

`anchor` is a best-effort window-coordinate rectangle for the selected text. Use it to position your own popover. If native layout cannot provide a useful rectangle, the values may be zero.

## Selection Text Exclusions

Use `selectionExclusionRanges` when part of the logical text should remain in layout and range offsets, but should not appear in reported selected text. This is useful for inline markers, reference numbers, or other app-owned control text.

`selection.start` and `selection.end` remain the original logical UTF-16 offsets. Only `selection.text` is filtered.

```tsx
<ReaderText
  text="This sentence has a note. 1"
  selectionExclusionRanges={[{ start: 26, end: 27 }]}
  onMenuAction={({ selection }) => {
    // selection.text excludes the marker range when selected across it.
  }}
/>
```

## Clearing Selection

If your app opens its own popover after a menu action, pass a numeric `clearSelectionSignal` and increment it when the popover closes or the action completes. Each `ReaderText` view clears any active native selection when the value changes.

```tsx
const [clearSelectionSignal, setClearSelectionSignal] = React.useState(0);

<ReaderText text={chapterText} clearSelectionSignal={clearSelectionSignal} />;

setClearSelectionSignal((signal) => signal + 1);
```

## Highlights

Highlights are logical UTF-16 ranges into the rendered text.

Highlight colors accept CSS-style hex strings such as `#FFE58A` and `#FFE58ACC`.

```tsx
<ReaderText
  text={paragraph.text}
  highlights={[{ id: 'h1', start: 12, end: 48, color: '#FFE58A' }]}
/>
```

Store highlights in your app with the paragraph or block ID:

```ts
type SavedHighlight = {
  id: string;
  paragraphId: string;
  start: number;
  end: number;
  color: string;
};
```

Then pass only the highlights for the current paragraph into that paragraph's `ReaderText`.

## Footnotes And Ranges

Footnotes are app-owned. Include marker text in your content and pass a generic range for the marker.

```tsx
<ReaderText
  text="This sentence has a footnote. 1"
  ranges={[{ id: 'fn-1', start: 30, end: 31, type: 'footnote' }]}
  onRangePress={(range) => {
    openFootnote(range.id);
  }}
/>
```

The same range API can represent glossary terms, references, citations, or links. The library does not parse footnotes or render bottom sheets.

For example, if the visible marker is the final `1`, the range should cover only that marker in the full logical string.

Ranges can also ask native text layout to draw the covered text as an inline marker. This avoids React Native overlay measurement and keeps marker spacing, selection, and taps inside the native text view.

```tsx
<ReaderText
  text="This sentence has a footnote. 1"
  ranges={[
    {
      id: 'fn-1',
      start: 30,
      end: 31,
      type: 'footnote',
      presentation: 'marker',
      markerStyle: {
        backgroundColor: '#F4EFE7',
        borderColor: '#D7C8B6',
        textColor: '#4D3827',
        fontScale: 0.72,
        baselineOffset: 4,
        horizontalPadding: 4,
        verticalPadding: 1,
        borderRadius: 4,
        minWidth: 16,
        minHeight: 16,
      },
    },
  ]}
  onRangePress={(range) => {
    openFootnote(range.id);
  }}
/>
```

On Android, marker presentation is drawn with a native `ReplacementSpan`. On iOS, marker presentation is applied inside `UITextView` attributed text so the marker remains part of native text layout. The marker text remains in the logical string on both platforms, and offsets stay JavaScript-style UTF-16 offsets.

## Multilingual Segments

Use `segments` when one paragraph needs per-language typography. Ranges and highlights apply to the concatenated logical text.

```tsx
<ReaderText
  segments={[
    { text: 'Read the next section ', lang: 'en' },
    { text: 'النص العربي ', lang: 'ar' },
    { text: 'اردو متن', lang: 'ur' },
  ]}
  baseDirection="auto"
  typography={[
    { lang: 'en', fontScale: 1.0, lineHeightMultiplier: 1.35 },
    { lang: 'ar', fontScale: 1.15, lineHeightMultiplier: 1.55 },
    {
      lang: 'ur',
      fontScale: 1.25,
      lineHeightMultiplier: 1.9,
      baselineOffset: -1,
    },
  ]}
/>
```

If both `text` and `segments` are provided, `segments` take precedence.

`lineHeightMultiplier` is applied at paragraph level using the largest multiplier from the rendered segments. If `textStyle.lineHeight` is set, that line height is treated as the base and multiplied.

## Many Paragraphs

Render documents as paragraphs or blocks, not as one giant text view.

```tsx
<FlatList
  data={paragraphs}
  keyExtractor={(item) => item.id}
  renderItem={({ item }) => (
    <ReaderText
      text={item.text}
      selectable
      highlights={highlightsForParagraph(item.id)}
      onMenuAction={(event) => handleMenuAction(item.id, event)}
    />
  )}
/>
```

This keeps offsets local to each paragraph and makes highlights, notes, scrolling, and persistence easier.

Avoid this for long documents:

```tsx
<ReaderText text={entireBook} />
```

## Platform Notes

Menu appearance, selection handles, default copy behavior, and custom menu ordering differ between iOS and Android.

Custom selection menu items are available on Android and on iOS 16 and later. On iOS 13-15, the default selection menu may appear without app-provided actions.

`onSelection` can fire repeatedly while a user drags selection handles. Debounce expensive app work if needed.

Highlight rendering may not be pixel-identical across platforms.

Offsets are logical UTF-16 offsets, matching JavaScript string indexing. Emoji, combining marks, and complex scripts may need extra care because offsets are not grapheme clusters.

Complex scripts may require font, baseline, and line-height tuning.

Expo requires a development build.

## Example

The repo includes an Expo development-build example:

```sh
cd example
npm install
npm run ios
# or
npm run android
```

The example demonstrates selectable text, custom menu actions, highlights, generic ranges for footnotes, multilingual segments, and a `FlatList` of paragraphs.

## Contributing

This project exists because high-quality text rendering is hard, especially for multilingual reading. Arabic, Urdu, Hebrew, English, and other mixed-direction content can expose platform differences that are difficult for one person to test completely.

Contributions are welcome, especially around RTL/LTR behavior, Arabic and Urdu typography, selection edge cases, Expo compatibility, accessibility, Fabric/New Architecture support, documentation, examples, and platform-specific bug fixes.

## Support

If this library helps your reader app, you can support development at [buymeacoffee.com/bilaldev](https://buymeacoffee.com/bilaldev).
