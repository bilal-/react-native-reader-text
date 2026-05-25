# Fabric (New Architecture) support — design

**Date:** 2026-05-24
**Component:** `ReaderTextView` / `ReaderText`
**Status:** Approved design, ready for implementation plan.

## Problem

The component is currently a legacy (Paper) view manager:

- iOS: `RCTViewManager` (`ReaderTextViewManager.swift`) + `RCT_EXPORT_VIEW_PROPERTY`
  bridging (`ReaderTextViewManager.m`).
- Android: `SimpleViewManager<ReaderTextView>` + `@ReactProp` + `RCTEventEmitter`.
- JS: `requireNativeComponent('ReaderTextView')`.

On the React Native **New Architecture (Fabric)** a Paper view manager only works
through the legacy interop layer, which is not guaranteed to carry this
component's custom props and `RCTDirectEventBlock` events cleanly. New-Arch apps
(the default in recent RN) therefore cannot reliably adopt the component.

## Goal

Make `ReaderTextView` render and function on Fabric **while keeping Paper
working**, with the **public `ReaderText` API unchanged**. Consumers should not
have to change any code.

Out of scope: adopting the component in any specific app; rich text features
already excluded by the library's v1 non-goals.

## Decisions

- **Dual architecture** via `codegenNativeComponent` (one JS spec drives both
  the Fabric component and the Paper fallback).
- **JSON-string props** for the complex props. The simple props and the events
  use codegen-native types.

### Why JSON-string props

`codegenNativeComponent` cannot express a dynamic-key map, which is exactly what
`typography: Record<string, Profile>` is; `textStyle` is an arbitrary object;
and `segments` / `highlights` / `ranges` / `menuItems` are arrays of objects
that are verbose and quirky to type through codegen. Serializing each to a JSON
string keeps codegen trivial, avoids restructuring the public API (e.g. turning
`typography` into an array), and lets both the Paper and Fabric native layers
parse one identical contract. The public `ReaderText` props stay fully typed for
users; serialization happens inside `ReaderText.tsx`.

## Architecture

### 1. Codegen spec (JS)

Replace `src/NativeReaderTextView.ts` with a codegen spec
(`src/ReaderTextViewNativeComponent.ts`):

```ts
// Props
interface NativeProps extends ViewProps {
  text: string;
  selectable?: WithDefault<boolean, true>;
  baseDirection?: WithDefault<string, 'auto'>;
  allowFontScaling?: WithDefault<boolean, true>;
  maxLineHeightMultiplier?: WithDefault<Double, 1>;
  // complex props as JSON strings
  segmentsJSON: string;
  highlightsJSON: string;
  rangesJSON: string;
  menuItemsJSON: string;
  typographyJSON: string;
  textStyleJSON: string;
  // events — flat primitive payloads (codegen-friendly)
  onSelection?: DirectEventHandler<Readonly<{ text: string; start: Int32; end: Int32 }>>;
  onMenuAction?: DirectEventHandler<Readonly<{
    id: string; title: string;
    selectionText: string; selectionStart: Int32; selectionEnd: Int32;
    anchorX: Double; anchorY: Double; anchorWidth: Double; anchorHeight: Double;
  }>>;
  onRangePress?: DirectEventHandler<Readonly<{ id: string; start: Int32; end: Int32; type: string }>>;
}
export default codegenNativeComponent<NativeProps>('ReaderTextView');
```

`package.json` gains:

```json
"codegenConfig": {
  "name": "ReaderTextViewSpec",
  "type": "components",
  "jsSrcsDir": "src",
  "android": { "javaPackageName": "com.readertext" }
}
```

### 2. `ReaderText.tsx` (public API shim — unchanged surface)

- Serialize complex props to JSON strings before passing to the native
  component: `segmentsJSON={JSON.stringify(normalizedSegments)}`, etc.
- Re-nest the flat event payloads into today's public shapes so consumers see no
  change:
  - `onSelection({ text, start, end })`
  - `onMenuAction({ id, title, selection: { text, start, end }, anchor: { x, y, width, height } })`
  - `onRangePress({ id, start, end, type })`
- The `ReaderTextProps` type and all normalization helpers (`buildLogicalText`,
  `normalizeSegments`, etc.) are unchanged.

### 3. iOS

- Add `ios/ReaderTextComponentView.mm` — an `RCTViewComponentView` subclass
  registered under component name `ReaderTextView`. It implements `updateProps:`
  (read the generated props struct, parse the JSON-string props via
  `NSJSONSerialization` into the `NSArray`/`NSDictionary` shapes the existing
  view consumes) and emits events through the generated event emitter.
- It **hosts the existing `ReaderTextView` UIView** (the Swift rendering /
  selection / menu / tap logic) unchanged. The Swift view's existing callbacks
  (`onSelection`/`onMenuAction`/`onRangePress` blocks) are bridged to the Fabric
  event emitter by the component view.
- Keep `ReaderTextViewManager.{swift,m}` for the legacy renderer. Update the
  Paper `.m` to export the JSON-string props (so both archs share one contract);
  the Swift view gains JSON-string setters that parse into its existing internal
  arrays — rendering logic untouched.
- `react-native-reader-text.podspec` already globs `ios/**/*.{h,m,mm,swift}`, so
  the new `.mm` is picked up. Fabric codegen output is wired by RN's pod scripts
  when New Arch is enabled.

### 4. Android

- Convert `ReaderTextViewManager` to implement the codegen-generated
  `ReaderTextViewManagerInterface` and route props through the generated
  `ReaderTextViewManagerDelegate`. A single `SimpleViewManager` that implements
  the generated interface serves **both** architectures.
- Prop setters become JSON-string (`@ReactProp(name = "segmentsJSON")` …),
  parsing JSON (org.json) into the structures the span-rendering already uses.
  Rendering logic untouched.
- Events: emit via the generated event mechanism (Fabric) — the existing
  `RCTEventEmitter` path maps through codegen on New Arch.
- `ReaderTextPackage` (createViewManagers) stays.

### 5. Event payload flattening

Codegen event payloads use flat primitives (no nested objects) for reliability.
Native emits flat fields; `ReaderText.tsx` re-nests into the public object shape.
This keeps the public API stable without depending on codegen nested-event
support.

## Testing

- Flip the library's **example app to the New Architecture**
  (`newArchEnabled=true`, prebuild) and verify on the iOS simulator and Android
  emulator:
  - native selection + custom menu items → `onMenuAction` fires with correct
    selection text/offsets,
  - `highlights` render as colored spans,
  - `ranges` → `onRangePress` fires for a tapped marker (the core reader need),
  - `segments` + `typography` apply per-language,
  - RTL (`baseDirection`) and mixed Arabic/Urdu/English render.
- Re-verify the example still works on **Paper** (`newArchEnabled=false`) — the
  dual-arch contract must hold both ways.
- Driven via Maestro + screenshots.

## Acceptance criteria

- `ReaderText` works unchanged (same props/events) on a New-Arch app and a
  Paper app.
- All five capabilities (selection menu, highlights, range tap, multilingual
  segments/typography, RTL) verified on Fabric on both iOS and Android.
- No public API change; existing `__tests__` (utils) still pass.
- Example app builds and runs on both `newArchEnabled` true and false.

## Follow-up (separate, in the consuming app)

Adopt `ReaderText` in the `webBooks` reader (replace the `TextInput` +
`highlight-menu` module + overlay/measurement stack). Tracked separately in that
repo's branch `feat/reader-text-migration`.
