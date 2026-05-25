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
  onRangePress?: DirectEventHandler<Readonly<{ id: string; start: Int32; end: Int32; type: string; metadataJSON: string }>>;
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
  - `onRangePress(range)` — **preserve `metadata`** (which the public
    `ReaderTextRange` allows). Primary strategy: resolve the pressed range by
    `id` from the `ranges` prop the consumer passed in and return that full
    object (metadata intact) — no metadata round-trip through native needed.
    Fallback: if no `id` match, reconstruct from the flat payload and parse
    `metadataJSON` (native serializes `range.metadata` so the round-trip path
    still preserves it).
- The `ReaderTextProps` type and all normalization helpers (`buildLogicalText`,
  `normalizeSegments`, etc.) are unchanged.

### 3. iOS

- **Podspec must wire the New Architecture deps.** Globbing the `.mm` is not
  enough — a Fabric component view needs `React-RCTFabric`, `ReactCodegen`,
  `React-Fabric`, the C++/folly flags, and header search paths. Replace the
  bare `s.dependency "React-Core"` with RN's helper so these are added only when
  New Arch is enabled:

  ```ruby
  if respond_to?(:install_modules_dependencies, true)
    install_modules_dependencies(s)   # adds Fabric/codegen deps + C++ flags on New Arch
  else
    s.dependency "React-Core"          # legacy fallback for old RN
  end
  ```

  Keep the `ios/**/*.{h,m,mm,swift}` glob so the new `.mm` compiles.

- Add `ios/ReaderTextComponentView.mm` — an `RCTViewComponentView` subclass
  registered under component name `ReaderTextView`. It implements `updateProps:`
  (read the generated props struct, parse the JSON-string props via
  `NSJSONSerialization` into the `NSArray`/`NSDictionary` shapes the existing
  view consumes).

- **Reuse the existing `ReaderTextView` UIView for rendering / selection / menu
  / tap logic, but change the EVENT payload shape.** The existing Swift
  callbacks emit nested dictionaries (`onMenuAction` with nested
  `selection`/`anchor`; `onRangePress` with the full range map). The generated
  Fabric emitter is **flat**, so we must not pass nested payloads through it.
  Resolve this explicitly: change the Swift view's callback payloads to the flat
  primitive shape (`selectionText`, `selectionStart`, `anchorX`, … ;
  `id`/`start`/`end`/`type`/`metadataJSON` for ranges). Both the Fabric
  component view and the Paper manager then forward the same flat payload to
  their respective emitters. This is the one deliberate change to the Swift
  view; the rendering/selection/hit-test logic is untouched.

- Keep `ReaderTextViewManager.{swift,m}` for the legacy renderer. Update the
  Paper `.m` to export the JSON-string props (so both archs share one contract)
  and the flat events; the Swift view gains JSON-string setters that parse into
  its existing internal arrays.

### 4. Android

- Convert `ReaderTextViewManager` to implement the codegen-generated
  `ReaderTextViewManagerInterface` and route props through the generated
  `ReaderTextViewManagerDelegate`. A single `SimpleViewManager` that implements
  the generated interface serves **both** architectures.
- Prop setters become JSON-string (`@ReactProp(name = "segmentsJSON")` …).
- **This is more than a setter change.** The current renderer is built on bridge
  types (`ReadableArray`/`ReadableMap`, e.g. the segment and highlight builders).
  `org.json` yields `JSONArray`/`JSONObject`, not `ReadableMap`, so we will:
  1. Introduce small Kotlin data classes — `Segment`, `Highlight`, `Range`,
     `MenuItem`, `TypographyProfile` (and a parsed `TextStyle`).
  2. Add a `ReaderTextJson` parser: JSON string → those data classes.
  3. Refactor the span-building helpers to consume the data classes instead of
     `ReadableArray`/`ReadableMap`. The span-construction logic itself stays; its
     input types change. This decouples rendering from the bridge types (a clean
     side effect).
- Events: emit flat payloads via the generated event mechanism (Fabric maps the
  existing `RCTEventEmitter` path through codegen on New Arch). `Range.metadata`
  is serialized to `metadataJSON` in the `onRangePress` payload (see §5).
- `ReaderTextPackage` (createViewManagers) stays.

### 5. Event payload flattening (explicit adapter contract)

Codegen event payloads use **flat primitives only** (no nested objects) for
reliability across both archs. The adapter boundary is explicit so no layer
accidentally emits a nested payload through the flat generated emitter:

- **Native (iOS Swift view + Android view):** event construction emits the flat
  shape directly — `onMenuAction` → `{ id, title, selectionText, selectionStart,
  selectionEnd, anchorX, anchorY, anchorWidth, anchorHeight }`; `onRangePress` →
  `{ id, start, end, type, metadataJSON }` (where `metadataJSON` is
  `JSON.stringify(range.metadata)` or `""`). This replaces today's nested-dict
  emission — the one deliberate change to the native event code.
- **Paper and Fabric** forward this same flat payload through their respective
  emitters (`RCTDirectEventBlock` / generated event emitter).
- **`ReaderText.tsx`** is the only place that re-assembles the public nested
  shapes (see §2), including resolving `onRangePress` back to the full range
  (with `metadata`) by `id`.

This keeps the public API stable without depending on codegen nested-event
support, and keeps `metadata` faithful to the public `ReaderTextRange` type.

## Testing

**Build-integration checks come first (highest risk).** The biggest risk here is
codegen/native integration, not the existing rendering logic — so gate on builds
before behavior:

- **iOS:** `pod install` then build the example with `RCT_NEW_ARCH_ENABLED=1`
  succeeds — codegen runs, the `.mm` Fabric component compiles, the podspec deps
  resolve.
- **Android:** Gradle `assembleDebug` with `newArchEnabled=true` succeeds —
  codegen generates `ReaderTextViewManagerInterface`/`Delegate` and the manager
  compiles against them.
- Both must also still build with New Arch **disabled** (Paper path intact).

Then behavior:

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
- `metadata` survives the `onRangePress` round-trip (public `ReaderTextRange`
  shape preserved).
- No public API change; existing `__tests__` (utils) still pass.
- **Build-only gates:** iOS pods + build with `RCT_NEW_ARCH_ENABLED=1` and
  Android Gradle with `newArchEnabled=true` both succeed (codegen + native
  compile), and both still build with New Arch disabled.
- Example app builds and runs on both `newArchEnabled` true and false.

## Follow-up (separate, in the consuming app)

Adopt `ReaderText` in the `webBooks` reader (replace the `TextInput` +
`highlight-menu` module + overlay/measurement stack). Tracked separately in that
repo's branch `feat/reader-text-migration`.
