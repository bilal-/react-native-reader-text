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
  return (
    <ReaderText
      text="Long press to select this text."
      selectable
    />
  );
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

## Highlights

Highlights are logical UTF-16 ranges into the rendered text.

```tsx
<ReaderText
  text={paragraph.text}
  highlights={[
    { id: 'h1', start: 12, end: 48, color: '#FFE58A' },
  ]}
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
  ranges={[
    { id: 'fn-1', start: 30, end: 31, type: 'footnote' },
  ]}
  onRangePress={(range) => {
    openFootnote(range.id);
  }}
/>
```

The same range API can represent glossary terms, references, citations, or links. The library does not parse footnotes or render bottom sheets.

For example, if the visible marker is the final `1`, the range should cover only that marker in the full logical string.

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
  typography={{
    en: { fontScale: 1.0, lineHeightMultiplier: 1.35 },
    ar: { fontScale: 1.15, lineHeightMultiplier: 1.55 },
    ur: { fontScale: 1.25, lineHeightMultiplier: 1.9, baselineOffset: -1 },
  }}
/>
```

If both `text` and `segments` are provided, `segments` take precedence.

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
