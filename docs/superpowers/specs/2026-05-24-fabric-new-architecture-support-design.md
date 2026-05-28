# Fabric (New Architecture) support - design

**Date:** 2026-05-24
**Component:** `ReaderTextView` / `ReaderText`
**Status:** Implemented locally on `plan/reader-text-mvp`. Updated with
webBooks reader requirements.

## Problem

The component is currently a legacy (Paper) view manager:

- iOS: `RCTViewManager` (`ReaderTextViewManager.swift`) + `RCT_EXPORT_VIEW_PROPERTY`
  bridging (`ReaderTextViewManager.m`).
- Android: `SimpleViewManager<ReaderTextView>` + `@ReactProp` + `RCTEventEmitter`.
- JS: `requireNativeComponent('ReaderTextView')`.

On the React Native New Architecture (Fabric), a Paper view manager only works
through the legacy interop layer. That path is not a good foundation for this
library because the component depends on custom props, native selection/menu
behavior, and direct events.

The library is not yet consumed externally, so the design should optimize for a
clean v1 API and long-term Fabric consumption rather than preserving the current
Paper-shaped implementation contract.

## Goal

Make `ReaderTextView` a first-class Fabric component with a codegen-friendly
public API that is easy for New Architecture apps to consume.

Paper support is useful only if it remains low-complexity. It must not drive the
public API shape or force JSON/stringly contracts where Fabric can use typed
props directly.

Out of scope: adopting the component in any specific app. However, the webBooks
reader is now the primary design input for v1 because it exposes the hardest
requirements: long selectable book paragraphs, mixed Arabic/Urdu/English text,
custom selection actions, highlights, and inline footnote markers.

Rich text parsing remains out of scope. Apps still own HTML/Markdown/book
parsing and pass normalized text, segments, ranges, and highlights into this
native primitive.

## Decisions

- **Fabric/codegen first.** `codegenNativeComponent` defines the native boundary.
  The public `ReaderText` API should be intentionally shaped around what codegen
  represents well.
- **Typed props, not JSON-string props.** Use codegen-friendly arrays and object
  literals for `segments`, `highlights`, `ranges`, `menuItems`, `typography`,
  and `textStyle`.
- **No dynamic maps across the native boundary.** Replace
  `typography: Record<string, Profile>` with an array of profiles keyed by
  `lang`. This is a v1 API change and is acceptable before external adoption.
- **Metadata remains JS-owned.** Native only needs enough data to identify the
  pressed range. Arbitrary `metadata: Record<string, unknown>` does not belong
  in the Fabric prop schema; preserve it in JS by resolving the native range
  event back to the original JS range.
- **Paper fallback is secondary.** Keep a legacy manager only if it can consume
  the same typed prop contract without meaningful complexity. Otherwise, ship
  Fabric first and document the minimum supported RN/New Architecture path.
- **Footnote markers are native inline drawing, not RN overlays.** webBooks
  currently proves that invisible text plus absolute React Native overlays is
  too fragile for mixed-script paragraphs, blockquotes, selection, scrolling,
  and platform font differences. v1 must support marker-style ranges that are
  drawn inside the native text layout.

### Why typed props

The current implementation was written around Paper bridge types
(`ReadableArray`/`ReadableMap` on Android and exported ObjC properties on iOS).
That should not determine the v1 API. Fabric libraries are easiest to consume
when their public props line up with the codegen spec, because the consuming app
can generate native glue from a clear schema during its normal build.

The only current public prop that does not fit well is `typography` as a dynamic
object map. Since there are no external consumers, convert it to
`TypographyProfile[]` with a `lang` field rather than hiding the mismatch behind
JSON strings.

## Architecture

### 1. Codegen spec (JS)

Replace `src/NativeReaderTextView.ts` with a codegen spec
(`src/ReaderTextViewNativeComponent.ts`):

```ts
import type { HostComponent, ViewProps } from 'react-native';
import type {
  DirectEventHandler,
  Double,
  Int32,
  WithDefault,
} from 'react-native/Libraries/Types/CodegenTypes';
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

type Segment = Readonly<{
  start: Int32;
  end: Int32;
  text: string;
  lang?: string;
  fontFamily?: string;
  fontScale?: Double;
  baselineOffset?: Double;
  lineHeightMultiplier?: Double;
}>;

type Highlight = Readonly<{
  id: string;
  start: Int32;
  end: Int32;
  color?: string;
}>;

type Range = Readonly<{
  id: string;
  start: Int32;
  end: Int32;
  type?: string;
  presentation?: 'plain' | 'marker';
  markerStyle?: MarkerStyle;
}>;

type MarkerStyle = Readonly<{
  backgroundColor?: string;
  borderColor?: string;
  textColor?: string;
  fontScale?: Double;
  baselineOffset?: Double;
  horizontalPadding?: Double;
  verticalPadding?: Double;
  borderRadius?: Double;
  minWidth?: Double;
  minHeight?: Double;
}>;

type MenuItem = Readonly<{
  id: string;
  title: string;
}>;

type TypographyProfile = Readonly<{
  lang: string;
  fontFamily?: string;
  fontScale?: Double;
  fontSize?: Double;
  lineHeightMultiplier?: Double;
  baselineOffset?: Double;
}>;

type NativeTextStyle = Readonly<{
  color?: string;
  fontFamily?: string;
  fontSize?: Double;
  lineHeight?: Double;
  textAlign?: string;
}>;

interface NativeProps extends ViewProps {
  text: string;
  segments?: ReadonlyArray<Segment>;
  selectable?: WithDefault<boolean, true>;
  menuItems?: ReadonlyArray<MenuItem>;
  highlights?: ReadonlyArray<Highlight>;
  ranges?: ReadonlyArray<Range>;
  typography?: ReadonlyArray<TypographyProfile>;
  baseDirection?: WithDefault<string, 'auto'>;
  textStyle?: NativeTextStyle;
  allowFontScaling?: WithDefault<boolean, true>;
  maxLineHeightMultiplier?: WithDefault<Double, 1>;
  onSelection?: DirectEventHandler<
    Readonly<{
      text: string;
      start: Int32;
      end: Int32;
    }>
  >;
  onMenuAction?: DirectEventHandler<
    Readonly<{
      id: string;
      title: string;
      selectionText: string;
      selectionStart: Int32;
      selectionEnd: Int32;
      anchorX: Double;
      anchorY: Double;
      anchorWidth: Double;
      anchorHeight: Double;
    }>
  >;
  onRangePress?: DirectEventHandler<
    Readonly<{
      id: string;
      start: Int32;
      end: Int32;
      type?: string;
    }>
  >;
}

export default codegenNativeComponent<NativeProps>(
  'ReaderTextView',
) as HostComponent<NativeProps>;
```

Implementation note: enum-like strings such as `baseDirection` and
`presentation` are validated by the public TypeScript API, but cross the native
codegen boundary as strings. This keeps the generated iOS and Android schemas
simple while preserving the public v1 shape.

`package.json` gains:

```json
"codegenConfig": {
  "name": "ReaderTextViewSpec",
  "type": "components",
  "jsSrcsDir": "src",
  "android": { "javaPackageName": "dev.bilalahmad.readertext" },
  "ios": {
    "componentProvider": {
      "ReaderTextView": "ReaderTextComponentView"
    }
  }
}
```

### 2. `ReaderText.tsx` (public API)

- Public `ReaderTextProps` should mirror the codegen-friendly native contract.
  Keep the ergonomic `text` or `segments` input model, but change `typography`
  to an array:

  ```ts
  typography?: ReaderTextTypographyProfile[];

  type ReaderTextTypographyProfile = {
    lang: string;
    fontFamily?: string;
    fontScale?: number;
    fontSize?: number;
    lineHeightMultiplier?: number;
    baselineOffset?: number;
  };
  ```

- Normalize all native-bound arrays in JS before rendering:
  - `segments` always include `start`, `end`, and `text`,
  - invalid `highlights` / `ranges` are dropped,
  - default arrays are `[]`, not `undefined`, when that makes native code
    simpler.
- Ranges may request native inline marker presentation:

  ```ts
  ranges={[
    {
      id: 'fn-4',
      start: 142,
      end: 143,
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
  ```

  The marker text remains part of the logical string and the range covers that
  marker text. Native draws the covered text as a compact inline marker and
  keeps `onRangePress` tied to the same UTF-16 offsets.

- Keep public events ergonomic while native events stay flat:
  - `onSelection({ text, start, end })`
  - `onMenuAction({ id, title, selection: { text, start, end }, anchor: { x, y, width, height } })`
  - `onRangePress(range)` resolves back to the original JS `ranges` entry using
    `id + start + end + type`, preserving `metadata` without sending arbitrary
    metadata through native. If no original range matches, return the flat
    native payload.
- Add focused JS tests for normalization, event rehydration, and metadata
  preservation.

Implemented:

- `src/ReaderTextViewNativeComponent.ts` is the codegen source of truth.
- `src/NativeReaderTextView.ts` re-exports the generated native component.
- `ReaderText.tsx` normalizes typed props before rendering and rehydrates flat
  native events back into the ergonomic public event shapes.
- `typography` is now `ReaderTextTypographyProfile[]` with required `lang`.

### 3. iOS

- **Podspec must wire the New Architecture deps.** Globbing the `.mm` is not
  enough; a Fabric component view needs `React-RCTFabric`, `ReactCodegen`,
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

- Add `ios/ReaderTextComponentView.mm`, an `RCTViewComponentView` subclass
  registered under component name `ReaderTextView`. It implements `updateProps:`
  by reading the generated props struct and applying typed values to the hosted
  Swift view.
- Make the Swift/ObjC boundary explicit:
  - keep `ReaderTextView` `@objc` visible,
  - import the generated Swift header from the ObjC++ component view,
  - map codegen arrays/object literals to Swift arrays/dictionaries or typed
    Swift structs at the component boundary.
- Reuse the existing `ReaderTextView` UIView for rendering, selection, menu, and
  tap logic, but change the event payload shape. The Swift view should emit flat
  primitive payloads for generated Fabric events:
  - `onMenuAction`: `id`, `title`, `selectionText`, `selectionStart`,
    `selectionEnd`, `anchorX`, `anchorY`, `anchorWidth`, `anchorHeight`
  - `onRangePress`: `id`, `start`, `end`, `type`
- Keep `ReaderTextViewManager.{swift,m}` for the legacy renderer only if it can
  forward the same typed prop shapes without material complexity. If Paper
  support becomes a significant implementation tax, defer it and document Fabric
  as the supported architecture for v1.

### 4. Android

- Convert `ReaderTextViewManager` to implement the codegen-generated
  `ReaderTextViewManagerInterface` and route props through the generated
  `ReaderTextViewManagerDelegate`.
- Wire Android codegen into the library build. The implementation plan must
  verify that generated `ReaderTextViewManagerInterface` / `Delegate` sources
  are produced by the consuming app's Gradle build and are visible to this
  library module.
- Introduce small Kotlin data classes: `Segment`, `Highlight`, `Range`,
  `MenuItem`, `TypographyProfile`, and `TextStyle`.
- Refactor span-building helpers to consume those data classes instead of
  `ReadableArray`/`ReadableMap`. This is the right internal boundary even though
  the generated manager may still hand setters bridge-compatible array/map
  wrappers on Android.
- Events emit flat payloads via the generated event mechanism.
- `ReaderTextPackage` (`createViewManagers`) stays only for legacy/Paper
  fallback. Fabric should be validated without relying on legacy interop.
- Marker ranges with `presentation: "marker"` use a custom `ReplacementSpan`.
  This is required, not a nice-to-have, because Android must reserve stable
  inline width/height for the marker and draw the rounded marker background,
  border, text, and baseline in one native text-layout pass. React Native
  overlays are not acceptable for v1 reader footnotes.

Implemented: Android codegen is wired through the React Gradle plugin, and
`ReaderTextViewManager` implements the generated
`ReaderTextViewManagerInterface` through `ReaderTextViewManagerDelegate`.

### 4a. iOS marker rendering

iOS must also render marker ranges natively inside `UITextView` attributed text.
The first implementation may use attributed text attributes for compact marker
styling (`font`, `baselineOffset`, `foregroundColor`, `backgroundColor`) so the
marker participates in TextKit layout and selection. If product requirements
need pixel-identical rounded chips on iOS, promote this to a TextKit-backed
attachment/custom drawing implementation rather than reintroducing React Native
overlays.

The iOS implementation must preserve the same logical range contract: the
visible marker text remains in the string, range offsets stay UTF-16 offsets,
and `onRangePress` reports the original range identity.

Implemented: iOS hosts the existing Swift `ReaderTextView` inside
`ReaderTextComponentView`, an `RCTViewComponentView` registered as
`ReaderTextView`. The Swift view remains the rendering/selection implementation
for both Paper and Fabric, with an explicit ObjC delegate used by Fabric events.

### 5. Event payload flattening

Codegen event payloads use flat primitives only. The adapter boundary is
explicit so no layer accidentally emits nested public payloads through the
generated emitter:

- Native event construction emits the flat shape directly.
- Fabric forwards the flat payload through the generated event emitter. Paper
  may forward the same payload if the fallback is retained.
- `ReaderText.tsx` is the only place that re-assembles the public nested shapes,
  including resolving `onRangePress` back to the full range with `metadata` by
  `id + start + end + type`.

This keeps public events ergonomic without depending on nested-event support in
codegen, and keeps arbitrary metadata out of native code.

## Testing

**Build-integration checks come first.** The biggest risk is codegen/native
integration, not the existing rendering logic.

- **iOS:** `pod install` then build the example with `RCT_NEW_ARCH_ENABLED=1`
  succeeds. Codegen runs, the `.mm` Fabric component compiles, the Swift bridge
  is visible, and the podspec deps resolve.
- **Android:** Gradle `assembleDebug` with `newArchEnabled=true` succeeds.
  Codegen generates `ReaderTextViewManagerInterface` / `Delegate`, and the
  manager compiles against them.
- If Paper fallback is retained, both platforms must also build with New Arch
  disabled. If Paper fallback is deferred, document that v1 requires New
  Architecture.

Then behavior:

- Flip the library's example app to the New Architecture (`newArchEnabled=true`,
  prebuild) and verify on the iOS simulator and Android emulator:
  - native selection + custom menu items -> `onMenuAction` fires with correct
    selection text/offsets,
  - `highlights` render as colored spans,
  - `ranges` -> `onRangePress` fires for a tapped marker,
  - marker ranges render inline at stable size and spacing, without RN overlay
    measurement,
  - `segments` + array-based `typography` apply per-language,
  - RTL (`baseDirection`) and mixed Arabic/Urdu/English render.
- If Paper fallback is retained, re-verify the example still works on Paper
  (`newArchEnabled=false`).
- Add JS unit tests for event rehydration and metadata preservation.
- Driven via Maestro + screenshots for end-to-end behavior.

Current build verification:

- `npm run typecheck` succeeds.
- `npm test -- --runInBand` succeeds.
- `npm run build` succeeds.
- `RCT_NEW_ARCH_ENABLED=1 pod install` succeeds in the example app.
- iOS example build succeeds with New Architecture enabled:
  `xcodebuild -workspace ReaderTextExample.xcworkspace -scheme ReaderTextExample
-configuration Debug -sdk iphonesimulator -destination 'platform=iOS
Simulator,name=iPhone 17 Pro' build`.
- Android example build succeeds with New Architecture enabled:
  `./gradlew :react-native-reader-text:generateCodegenArtifactsFromSchema` and
  `./gradlew assembleDebug`.

## Acceptance criteria

- `ReaderText` works on a New-Arch app using the typed v1 public API.
- All five capabilities (selection menu, highlights, range tap, multilingual
  segments/typography, RTL) are verified on Fabric on both iOS and Android.
- `metadata` survives the `onRangePress` round-trip by resolving back to the
  original JS range.
- Footnote/range markers can be rendered as native inline markers. Android uses
  `ReplacementSpan`; iOS renders markers inside `UITextView` attributed text and
  has a documented path to custom TextKit drawing if rounded chips need exact
  parity.
- Public API intentionally changes `typography` from a dynamic map to a typed
  array. README and docs are updated accordingly.
- Existing `__tests__` still pass, and new adapter tests cover event
  rehydration.
- **Build gates:** iOS pods + build with `RCT_NEW_ARCH_ENABLED=1` and Android
  Gradle with `newArchEnabled=true` both succeed (codegen + native compile).
- Example app builds and runs with `newArchEnabled=true`. If Paper fallback is
  retained, it also builds and runs with `newArchEnabled=false`.

## webBooks adoption requirements

webBooks should be able to replace its current paragraph `TextInput` plus marker
overlay stack with `ReaderText` instances. The library must support:

- Mixed Arabic, Urdu, English, and Quranic spans in one paragraph without line
  height collapse or uneven baselines.
- Native selection and custom Highlight / Note / Share menu actions.
- App-owned highlights keyed by paragraph/block IDs.
- Footnote markers inside normal paragraphs, blockquotes, and mixed-script runs.
- Marker taps that work without measuring React Native overlay positions.
- Stable marker size and surrounding spacing on Android and iOS.
- UTF-16 offsets that match JavaScript string indexing so parser output can
  generate ranges deterministically.

## Follow-up (separate, in the consuming app)

Adopt `ReaderText` in the `webBooks` reader after the library has a working
Fabric release. This remains separate from the library design.
