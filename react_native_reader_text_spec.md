# Specification: `react-native-reader-text`

## Project Summary

`react-native-reader-text` is an open-source React Native library that provides a native-quality, selectable, read-only text component for book readers, study apps, document readers, annotation apps, and multilingual reading experiences.

The primary component is `ReaderText`, backed by native text views:

- iOS: `UITextView`
- Android: `TextView`, not `EditText`

The library should focus on high-quality reading, text selection, custom selection menu actions, highlights, notes, sharing, and multilingual typography. It should not attempt to become a full rich text editor, EPUB engine, markdown parser, or WebView-based reader.

The first version should be intentionally small, stable, and easy to consume.

---

## Why This Library Exists

React Native does not currently provide an ideal native component for serious book-reader text experiences.

React Native's standard components create tradeoffs:

- `<Text>` is good for display but has limited selection and custom menu support.
- `<TextInput editable={false}>` can work on iOS because it maps to `UITextView`, but on Android it maps to `EditText`, which is designed for editing, not high-quality read-only book rendering.
- Existing selectable text libraries are fragmented, often under-maintained, and usually do not deeply address multilingual reading, custom selection menus, annotation ranges, or RTL/LTR complexity.
- WebView-based approaches can work for HTML/EPUB-style content, but they introduce bridge complexity, keyboard issues, inconsistent native feel, and accessibility concerns.

Book readers need a different primitive: a read-only native text surface with selectable text, custom selection actions, stable range reporting, and native typography.

This library exists to fill that gap.

---

## Target Use Cases

The library should support:

- Book readers
- Document readers
- Reference readers
- Study apps
- Annotation apps
- AI response readers
- Long-form article readers
- Multilingual educational apps
- Apps needing copy, highlight, save-to-notes, and custom share flows

The library should be especially useful where content may include:

- English
- Arabic
- Urdu
- Mixed RTL/LTR text
- Multiple fonts in the same paragraph
- Different typography requirements per language/script

---

## Non-Goals for v1

Do not implement these in the first version:

- Rich text editing
- Full EPUB rendering
- Markdown parsing
- HTML parsing
- Embedded React children inside text
- Inline images
- Footnote parsing, storage, or bottom-sheet UI
- Full pagination engine
- WebView renderer
- Complete document layout system
- Full custom text layout engine
- Fabric-only implementation

The first version should focus on native read-only selectable text.

---

## Package Name

NPM package:

```txt
react-native-reader-text
```

GitHub repository:

```txt
react-native-reader-text
```

Main export:

```ts
import { ReaderText } from 'react-native-reader-text';
```

---

## License

Use the MIT License.

Reason:

- Low adoption friction
- Friendly to commercial apps
- Friendly to nonprofit, educational, and personal apps
- Familiar in the React Native ecosystem
- Easy for companies to approve
- Encourages broad use and contribution

Include:

```txt
LICENSE
CONTRIBUTING.md
CODE_OF_CONDUCT.md
README.md
```

---

## Core Design Principle

The default API should be extremely simple.

A developer should be able to install the package and write:

```tsx
import { ReaderText } from 'react-native-reader-text';

export function Example() {
  return (
    <ReaderText
      text="Long press to select this text."
      selectable
    />
  );
}
```

Advanced capabilities should be optional.

---

## Component API

### Basic Usage

```tsx
<ReaderText
  text="Some selectable book text"
  selectable
/>
```

### Custom Menu Actions

```tsx
<ReaderText
  text={content}
  selectable
  menuItems={[
    { id: 'highlight', title: 'Highlight' },
    { id: 'note', title: 'Note' },
    { id: 'share', title: 'Share' },
  ]}
  onMenuAction={({ id, selection, anchor }) => {
    console.log(id);
    console.log(selection.text);
    console.log(selection.start);
    console.log(selection.end);
    console.log(anchor);
  }}
/>
```

### Highlights

```tsx
<ReaderText
  text={content}
  highlights={[
    {
      id: 'h1',
      start: 10,
      end: 35,
      color: '#FFE58A',
    },
  ]}
/>
```

### Multilingual Segments

```tsx
<ReaderText
  segments={[
    { text: 'Read the next section ', lang: 'en' },
    { text: 'النص العربي ', lang: 'ar' },
    { text: 'اردو متن', lang: 'ur' },
  ]}
  typography={{
    en: { fontScale: 1.0, lineHeightMultiplier: 1.35 },
    ar: { fontScale: 1.15, lineHeightMultiplier: 1.55 },
    ur: { fontScale: 1.25, lineHeightMultiplier: 1.9 },
  }}
/>
```

`text` should be sufficient for simple users. `segments` should be available for advanced multilingual rendering.

---

## TypeScript Types

```ts
export type ReaderTextLanguage = string;

export type ReaderTextSegment = {
  text: string;
  lang?: ReaderTextLanguage;
  fontFamily?: string;
  fontScale?: number;
  baselineOffset?: number;
  lineHeightMultiplier?: number;
};

export type ReaderTextHighlight = {
  id: string;
  start: number;
  end: number;
  color?: string;
  metadata?: Record<string, unknown>;
};

export type ReaderTextRange = {
  id: string;
  start: number;
  end: number;
  type?: string;
  metadata?: Record<string, unknown>;
};

export type ReaderTextSelection = {
  text: string;
  start: number;
  end: number;
};

export type ReaderTextSelectionAnchor = {
  x: number;
  y: number;
  width: number;
  height: number;
};

export type ReaderTextMenuItem = {
  id: string;
  title: string;
};

export type ReaderTextMenuActionEvent = {
  id: string;
  title: string;
  selection: ReaderTextSelection;
  anchor: ReaderTextSelectionAnchor;
};

export type ReaderTextTypographyProfile = {
  fontFamily?: string;
  fontScale?: number;
  fontSize?: number;
  lineHeightMultiplier?: number;
  baselineOffset?: number;
};

export type ReaderTextProps = {
  text?: string;
  segments?: ReaderTextSegment[];
  selectable?: boolean;
  menuItems?: ReaderTextMenuItem[];
  highlights?: ReaderTextHighlight[];
  ranges?: ReaderTextRange[];
  typography?: Record<string, ReaderTextTypographyProfile>;
  baseDirection?: 'auto' | 'ltr' | 'rtl';
  style?: any;
  textStyle?: any;
  onSelection?: (selection: ReaderTextSelection) => void;
  onMenuAction?: (event: ReaderTextMenuActionEvent) => void;
  onRangePress?: (range: ReaderTextRange) => void;
};
```

Validation rules:

- Either `text` or `segments` may be provided.
- If both are provided, `segments` should take precedence.
- Highlight ranges should apply to the full logical text after concatenating all segments.
- Generic ranges should apply to the full logical text after concatenating all segments.
- Ranges should use logical string offsets, not visual positions.

---

## Native Architecture

### Android

Use native `TextView`, not `EditText`.

Why:

- `TextView` is the correct read-only text primitive.
- `EditText` is optimized for editing and input behavior.
- `TextView` supports selection with `setTextIsSelectable(true)`.
- `TextView` supports spans for font, size, color, highlights, and custom behavior.

Android implementation should use:

- `TextView`
- `SpannableString` / `SpannableStringBuilder`
- `BackgroundColorSpan` for highlights
- `AbsoluteSizeSpan` or relative sizing spans for typography
- `TypefaceSpan` or custom spans for fonts
- `BaselineShiftSpan` or custom baseline shift span when needed
- `LineHeightSpan` for line height control when needed
- `customSelectionActionModeCallback` for custom selection menu actions

Important Android properties:

```kotlin
textView.setTextIsSelectable(true)
textView.textDirection = View.TEXT_DIRECTION_FIRST_STRONG
textView.textAlignment = View.TEXT_ALIGNMENT_GRAVITY
```

For explicit direction:

```kotlin
View.TEXT_DIRECTION_LTR
View.TEXT_DIRECTION_RTL
View.TEXT_DIRECTION_FIRST_STRONG
```

For alignment:

```kotlin
Gravity.START
Gravity.END
```

Avoid manually reversing text.

### iOS

Use native `UITextView`.

Why:

- `UITextView` is the native selectable text component.
- `UILabel` is not sufficient for serious selection/custom menu behavior.
- `UITextView` supports attributed strings, selection, and native text layout.

Configure as read-only:

```swift
textView.isEditable = false
textView.isSelectable = true
textView.isScrollEnabled = false // initial default; allow configuration later if needed
textView.backgroundColor = .clear
textView.textContainerInset = .zero
textView.textContainer.lineFragmentPadding = 0
```

Use:

- `NSAttributedString`
- `NSMutableAttributedString`
- `.font`
- `.backgroundColor`
- `.baselineOffset`
- `NSMutableParagraphStyle`
- `baseWritingDirection = .natural` or explicit direction
- custom menu actions via modern iOS menu APIs where available

For direction:

```swift
paragraphStyle.baseWritingDirection = .natural
```

For alignment:

```swift
textView.textAlignment = .natural
```

---

## Selection Behavior

The component should emit logical offsets:

```ts
{
  text: string,
  start: number,
  end: number
}
```

Offsets should correspond to the concatenated logical text, not visual order.

For mixed RTL/LTR content, do not attempt to manually map visual order. Use native selection offsets and document clearly that offsets are logical string offsets.

### Important Note About Unicode

JavaScript string offsets are UTF-16 code units. Native platforms may also expose UTF-16-compatible ranges, but care should be taken around emoji, combining marks, and complex scripts.

For v1, document that ranges are UTF-16 string offsets.

Future versions may add grapheme-aware helpers.

---

## Custom Selection Menu

The library should allow custom menu actions:

```tsx
menuItems={[
  { id: 'highlight', title: 'Highlight' },
  { id: 'note', title: 'Note' },
  { id: 'share', title: 'Share' },
]}
```

When a custom item is tapped, emit:

```ts
onMenuAction({
  id: 'highlight',
  title: 'Highlight',
  selection: {
    text: 'selected text',
    start: 100,
    end: 125,
  },
  anchor: {
    x: 40,
    y: 280,
    width: 160,
    height: 24,
  },
})
```

The native default copy action should ideally remain available unless explicitly disabled in a future API.

For v1, keep menu behavior simple:

- Preserve default platform copy behavior where possible.
- Add custom actions after/default alongside native actions where possible.
- Do not guarantee identical menu ordering between iOS and Android.
- Document platform differences.
- The library should only report the selected range and tapped menu item.
- App code should own workflows such as opening a color picker, saving notes, presenting a share sheet, analytics, sync, and persistence.
- Include the selection anchor in menu events so apps can position their own popovers near the native selection.

---

## Highlight Rendering

Highlights should be passed as logical ranges:

```ts
[
  { id: 'h1', start: 10, end: 35, color: '#FFE58A' }
]
```

Native behavior:

- Android: apply `BackgroundColorSpan`
- iOS: apply `.backgroundColor` attribute

Rules:

- Invalid ranges should be ignored safely.
- Overlapping highlights should not crash.
- Basic overlapping behavior can be documented as last-applied-wins for v1.
- Highlight IDs should be passed through unchanged.

Future improvements:

- tap on highlight
- highlight metadata
- multiple highlight colors
- conflict resolution
- underline style
- note indicator style

---

## Footnotes and Inline Markers

Footnotes should remain app-owned in v1.

The library should not parse footnotes, render bottom sheets, store note content, or define a document schema. Apps can still build footnote behavior on top of `ReaderText` by including marker text in `text` or `segments` and tracking marker ranges in app data.

Example:

```tsx
<ReaderText
  text="This sentence has a footnote. 1"
  ranges={[
    {
      id: 'fn-1',
      start: 30,
      end: 31,
      type: 'footnote',
      metadata: { marker: '1' },
    },
  ]}
  onRangePress={(range) => {
    if (range.type === 'footnote') {
      openFootnote(range.id);
    }
  }}
/>
```

For v1, `ranges` should be a generic extension point for app-owned inline interactions such as footnote markers, glossary terms, references, or links. The library can use native text range detection where practical, but it should avoid promising complex inline React children or full document interaction behavior.

If range press handling proves too platform-specific for the first release, keep the type shape documented as a planned extension and prioritize stable selection, menu actions, and highlights first.

---

## Multilingual Typography

This is a core differentiator.

Same numeric font size does not look visually equivalent across English, Arabic, and Urdu/Nastaliq fonts. The library should support per-language typography profiles.

Example:

```tsx
typography={{
  en: {
    fontFamily: 'System',
    fontScale: 1.0,
    lineHeightMultiplier: 1.35,
    baselineOffset: 0,
  },
  ar: {
    fontFamily: 'Amiri',
    fontScale: 1.15,
    lineHeightMultiplier: 1.55,
    baselineOffset: 0,
  },
  ur: {
    fontFamily: 'Noto Nastaliq Urdu',
    fontScale: 1.25,
    lineHeightMultiplier: 1.9,
    baselineOffset: -1,
  },
}}
```

### Font Size Strategy

Do not force one global font size to mean the same thing for every script.

Use a reader size or base font size and apply language-specific multipliers.

Example:

```ts
actualFontSize = baseFontSize * languageFontScale
```

### Line Height Strategy

For paragraphs with multiple scripts, line height should be generous enough to avoid clipping.

Suggested v1 strategy:

- Determine all segment line-height requirements.
- Use the maximum required line height for the paragraph.
- Allow language-specific `lineHeightMultiplier`.

### Baseline Alignment

Different fonts sit differently on the baseline. Native engines align text by baseline, but visual tuning may still be needed.

Support optional `baselineOffset` per segment/language.

Native mapping:

- Android: baseline shift span/custom span
- iOS: `.baselineOffset`

---

## RTL/LTR and Bidi Support

The library should rely on native bidi behavior.

Do not manually reverse strings.

Do not manually reorder mixed-language text.

Support:

```ts
baseDirection?: 'auto' | 'ltr' | 'rtl'
```

Default:

```ts
baseDirection="auto"
```

Native mapping:

Android:

```kotlin
View.TEXT_DIRECTION_FIRST_STRONG
View.TEXT_DIRECTION_LTR
View.TEXT_DIRECTION_RTL
```

iOS:

```swift
paragraphStyle.baseWritingDirection = .natural
```

For advanced users, document that Unicode isolation controls may help with complex inline direction cases:

- LRI
- RLI
- FSI
- PDI

But the library should not require users to manually add these for normal usage.

---

## Recommended Usage Pattern for Book Readers

Do not render an entire book in a single component.

Recommended:

```tsx
<FlatList
  data={paragraphs}
  renderItem={({ item }) => (
    <ReaderText
      text={item.text}
      highlights={highlightsForParagraph(item.id)}
      onMenuAction={(event) => handleAction(item.id, event)}
    />
  )}
/>
```

For structured reading apps, chunk by:

- paragraph
- sentence
- section
- article block
- page block

Avoid:

```tsx
<ReaderText text={entireBook} />
```

Reason:

- Better performance
- Easier range tracking
- Easier highlight persistence
- Easier scroll behavior
- Easier typography per paragraph
- Easier RTL/LTR direction per block

---

## Expo Support

The library should support Expo Development Builds.

Do not require users to fully eject from Expo.

Recommended setup:

- Use a standard React Native native module/component structure.
- Provide an Expo config plugin if required.
- Include an Expo example app.
- Document clearly that Expo Go will not support custom native code unless/until the library is included in Expo Go, so users need a development build.

README should clearly say:

```txt
Expo users: this package requires a development build because it includes native Android/iOS code. It will not work in Expo Go.
```

---

## Repository Structure

Recommended structure:

```txt
react-native-reader-text/
  README.md
  LICENSE
  CONTRIBUTING.md
  CODE_OF_CONDUCT.md
  package.json
  tsconfig.json
  src/
    index.ts
    ReaderText.tsx
    types.ts
    NativeReaderTextView.ts
  android/
    src/main/java/.../ReaderTextViewManager.kt
    src/main/java/.../ReaderTextView.kt
  ios/
    ReaderTextViewManager.swift
    ReaderTextView.swift
  example/
    package.json
    app.json
    App.tsx
  docs/
    typography.md
    selection.md
    highlights.md
    expo.md
```

Consider using `create-react-native-library` to scaffold the project.

---

## README Requirements

The README should be welcoming, clear, and contributor-friendly.

It should explain:

1. What the library does
2. Why it exists
3. Why it uses native text components
4. Why `TextInput editable={false}` is not a good cross-platform book-reader solution
5. How to install
6. Basic usage
7. Custom menu usage
8. Highlight usage
9. Multilingual segment usage
10. Expo development build note
11. Platform support status
12. Contribution invitation

### README Positioning Statement

Use wording similar to:

```md
Native-quality selectable text for React Native book readers, study apps, and multilingual reading experiences.
```

### README Explanation

Include something like:

```md
React Native's built-in text components are excellent for many app screens, but serious reading experiences need more control. Book readers often require native text selection, custom selection actions, highlights, notes, sharing, RTL/LTR support, and language-specific typography.

On iOS, developers sometimes use `TextInput` with `editable={false}` because it maps to `UITextView`. This can work well for read-only selectable text. On Android, however, `TextInput` maps to `EditText`, which is designed for editing rather than read-only book rendering. This leads to inconsistent behavior and makes it harder to build polished readers.

`react-native-reader-text` provides a small native reader text primitive: `UITextView` on iOS and `TextView` on Android.
```

### Contributor Invitation

The README should actively invite contributors:

```md
This project exists because high-quality text rendering is hard, especially for multilingual reading. Arabic, Urdu, Hebrew, English, and other mixed-direction content can expose platform differences that are difficult for one person to test completely.

Contributions are welcome, especially around:

- RTL/LTR behavior
- Arabic and Urdu typography
- selection edge cases
- Expo compatibility
- accessibility
- Fabric/New Architecture support
- documentation and examples
- platform-specific bug fixes

If this library helps your reader, study app, document app, or annotation workflow, please consider contributing fixes, test cases, examples, or documentation improvements.
```

---

## README Basic Example

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

---

## README Custom Menu Example

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
      createNote(selection.text, selection.start, selection.end, anchor);
    }

    if (id === 'share') {
      shareText(selection.text);
    }
  }}
/>
```

---

## README Highlight Example

```tsx
<ReaderText
  text={paragraph.text}
  highlights={[
    { id: 'h1', start: 12, end: 48, color: '#FFE58A' },
  ]}
/>
```

---

## README Multilingual Example

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

---

## Platform Behavior Notes

Document clearly:

- Menu appearance differs between iOS and Android.
- Selection handles differ between iOS and Android.
- Default copy behavior may differ by platform.
- Highlight rendering may not be pixel-identical between platforms.
- Offsets are logical UTF-16 offsets.
- Complex scripts may require font and line-height tuning.

Do not promise pixel-perfect parity.

Promise a clean native foundation.

---

## Accessibility

Initial accessibility support:

- Component should expose readable text to screen readers.
- Avoid breaking native accessibility behavior.
- Respect platform font scaling where possible.
- Provide prop to disable system font scaling later if needed.

Potential prop:

```ts
allowFontScaling?: boolean;
```

v1 can include or defer this, but accessibility should be considered from the start.

---

## Testing Requirements

Include an example screen with:

1. Simple English paragraph
2. Arabic paragraph
3. Urdu paragraph
4. Mixed English + Arabic paragraph
5. Mixed English + Urdu paragraph
6. Highlighted text
7. Custom selection menu actions
8. Long paragraph
9. Multiple `ReaderText` components in a `FlatList`

Manual testing matrix:

- iOS simulator
- iOS physical device if possible
- Android emulator
- Android physical device if possible
- RTL device setting
- Larger accessibility font size
- Dark mode

Automated tests can initially focus on JS utilities:

- segment concatenation
- highlight range validation
- invalid range filtering
- typography profile merging

---

## Implementation Phases

### Phase 1: Scaffold

- Create repo `react-native-reader-text`
- MIT license
- TypeScript setup
- Native module/component scaffold
- Basic example app
- Export `ReaderText`

### Phase 2: Basic Native Text

- Render plain `text`
- Support `style` and `textStyle`
- Support `selectable`
- iOS uses `UITextView`
- Android uses `TextView`

### Phase 3: Selection Events

- Detect selected text
- Emit `onSelection`
- Emit logical `start` and `end` offsets

### Phase 4: Custom Menu Actions

- Support `menuItems`
- Emit `onMenuAction`
- Preserve default copy action where possible

### Phase 5: Highlights

- Accept `highlights`
- Render background highlights
- Safely ignore invalid ranges

### Phase 6: Multilingual Segments

- Accept `segments`
- Concatenate logical text
- Apply per-segment language styles
- Apply typography profiles

### Phase 7: Typography Tuning

- Add font scale support
- Add line height multiplier support
- Add baseline offset support
- Document recommended profiles for English, Arabic, and Urdu

### Phase 8: Expo Docs and Example

- Add Expo development build instructions
- Add config plugin if needed
- Add example app screenshots/GIFs

---

## Suggested Initial API Scope

For first public release, implement only:

```ts
text
segments
selectable
menuItems
highlights
ranges
typography
baseDirection
style
textStyle
onSelection
onMenuAction
onRangePress
```

Avoid adding too many props before real users provide feedback.

---

## Future Roadmap Ideas

Potential future features:

- `onHighlightPress`
- richer `onRangePress` support for footnotes, references, glossary terms, and links
- note indicators
- underline highlights
- multiple highlight styles
- grapheme-aware range utilities
- selection color customization
- scroll-to-range
- find-in-text support
- accessibility improvements
- Fabric/New Architecture optimization
- paragraph measurement callbacks
- better Expo config plugin support
- web fallback using plain text/HTML
- built-in helpers for structured document ranges

Keep these out of v1 unless easy.

---

## Success Criteria for MVP

The MVP is successful if a developer can:

1. Install the package.
2. Render selectable read-only text.
3. Select text on iOS and Android.
4. See custom menu actions.
5. Receive selected text and logical offsets.
6. Save a highlight range.
7. Pass highlight ranges back into the component.
8. Render English, Arabic, and Urdu content with reasonable typography.
9. Use it inside a scrolling list of paragraphs.

---

## Implementation Guidance

Build this project incrementally. Do not over-engineer the first version.

Prioritize:

1. A clean TypeScript API
2. A working native Android `TextView`
3. A working native iOS `UITextView`
4. Selection callbacks
5. Custom menu actions
6. Highlight spans
7. Clear README examples

Avoid:

- WebView
- Rich text editing
- Markdown parsing
- EPUB parsing
- Large architecture abstractions
- Complex custom layout engines

The goal is a small, native, reliable reader text primitive for React Native.
