import type {
  ReaderTextHighlight,
  ReaderTextMenuActionEvent,
  ReaderTextRange,
  ReaderTextSegment,
  ReaderTextSelection,
  ReaderTextSelectionExclusionRange,
  ReaderTextTypographyProfile,
  NativeReaderTextMenuActionEvent,
  NativeReaderTextRangePressEvent,
} from './types';

export type NormalizedSegment = ReaderTextSegment & {
  start: number;
  end: number;
  typography?: Partial<ReaderTextTypographyProfile>;
};

export function buildLogicalText(
  text?: string,
  segments?: ReaderTextSegment[],
): string {
  if (segments && segments.length > 0) {
    return segments.map((segment) => segment.text).join('');
  }

  return text ?? '';
}

export function isValidRange(
  range: { start: number; end: number },
  textLength: number,
): boolean {
  return (
    Number.isInteger(range.start) &&
    Number.isInteger(range.end) &&
    range.start >= 0 &&
    range.end > range.start &&
    range.end <= textLength
  );
}

export function normalizeHighlights(
  highlights: ReaderTextHighlight[] | undefined,
  textLength: number,
): ReaderTextHighlight[] {
  if (!highlights?.length) return [];

  return highlights.filter((highlight) => isValidRange(highlight, textLength));
}

export function normalizeRanges(
  ranges: ReaderTextRange[] | undefined,
  textLength: number,
): ReaderTextRange[] {
  if (!ranges?.length) return [];

  return ranges.filter((range) => isValidRange(range, textLength));
}

export function normalizeSelectionExclusionRanges(
  ranges: ReaderTextSelectionExclusionRange[] | undefined,
  textLength: number,
): ReaderTextSelectionExclusionRange[] {
  if (!ranges?.length) return [];

  return ranges
    .filter((range) => isValidRange(range, textLength))
    .sort((a, b) => a.start - b.start);
}

export function typographyProfileMap(
  typography: ReaderTextTypographyProfile[] | undefined,
): Record<string, ReaderTextTypographyProfile> {
  if (!typography?.length) return {};

  return typography.reduce<Record<string, ReaderTextTypographyProfile>>(
    (profiles, profile) => {
      profiles[profile.lang] = profile;
      return profiles;
    },
    {},
  );
}

export function mergeTypographyProfile(
  profile?: Partial<ReaderTextTypographyProfile>,
  segment?: ReaderTextSegment,
): Partial<ReaderTextTypographyProfile> | undefined {
  const merged: Partial<ReaderTextTypographyProfile> = {
    ...profile,
  };

  if (segment?.fontFamily !== undefined) merged.fontFamily = segment.fontFamily;
  if (segment?.color !== undefined) merged.color = segment.color;
  if (segment?.fontScale !== undefined) merged.fontScale = segment.fontScale;
  if (segment?.lineHeightMultiplier !== undefined) {
    merged.lineHeightMultiplier = segment.lineHeightMultiplier;
  }
  if (segment?.baselineOffset !== undefined)
    merged.baselineOffset = segment.baselineOffset;

  return Object.keys(merged).length > 0 ? merged : undefined;
}

export function normalizeSegments(
  text: string,
  segments: ReaderTextSegment[] | undefined,
  typography: ReaderTextTypographyProfile[] | undefined,
): NormalizedSegment[] {
  const profiles = typographyProfileMap(typography);

  if (!segments?.length) {
    return text.length > 0 ? [{ text, start: 0, end: text.length }] : [];
  }

  let cursor = 0;
  return segments.map((segment) => {
    const start = cursor;
    const end = start + segment.text.length;
    cursor = end;

    return {
      ...segment,
      start,
      end,
      typography: mergeTypographyProfile(
        segment.lang ? profiles[segment.lang] : undefined,
        segment,
      ),
    };
  });
}

export function getSelectedText(
  text: string,
  start: number,
  end: number,
): ReaderTextSelection | null {
  if (!isValidRange({ start, end }, text.length)) return null;

  return {
    text: text.slice(start, end),
    start,
    end,
  };
}

export function selectionWithExcludedRanges(
  text: string,
  selection: ReaderTextSelection,
  exclusionRanges: ReaderTextSelectionExclusionRange[],
): ReaderTextSelection {
  if (!exclusionRanges.length) return selection;

  let cursor = selection.start;
  let selectedText = '';

  for (const range of exclusionRanges) {
    const start = Math.max(selection.start, range.start);
    const end = Math.min(selection.end, range.end);
    if (end <= cursor || start >= selection.end) continue;
    if (start > cursor) selectedText += text.slice(cursor, start);
    cursor = Math.max(cursor, end);
  }

  if (cursor < selection.end) {
    selectedText += text.slice(cursor, selection.end);
  }

  return {
    ...selection,
    text: selectedText,
  };
}

export function maxLineHeightMultiplier(
  segments: NormalizedSegment[],
  fallback = 1,
): number {
  return segments.reduce((max, segment) => {
    const multiplier =
      segment.typography?.lineHeightMultiplier ??
      segment.lineHeightMultiplier ??
      fallback;
    return Math.max(max, multiplier);
  }, fallback);
}

export function rehydrateMenuAction(
  event: NativeReaderTextMenuActionEvent,
): ReaderTextMenuActionEvent {
  return {
    id: event.id,
    title: event.title,
    selection: {
      text: event.selectionText,
      start: event.selectionStart,
      end: event.selectionEnd,
    },
    anchor: {
      x: event.anchorX,
      y: event.anchorY,
      width: event.anchorWidth,
      height: event.anchorHeight,
    },
  };
}

export function rehydrateRangePress(
  event: NativeReaderTextRangePressEvent,
  ranges: ReaderTextRange[],
): ReaderTextRange {
  return (
    ranges.find(
      (range) =>
        range.id === event.id &&
        range.start === event.start &&
        range.end === event.end &&
        (range.type ?? '') === (event.type ?? ''),
    ) ?? {
      id: event.id,
      start: event.start,
      end: event.end,
      type: event.type,
    }
  );
}

function numericStyleValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value > 0
    ? value
    : undefined;
}

export function estimateContentHeight(
  text: string,
  textStyle: Record<string, unknown>,
  width: number,
  lineHeightMultiplier: number,
  fontScale: number,
): number {
  if (!text) return 0;
  // The native view scales glyphs and line height with the system text size
  // (Dynamic Type / font scale), so the estimate must too. Real height grows
  // roughly with the square of the scale: wider glyphs mean more lines, and
  // each line is taller.
  const fontSize = (numericStyleValue(textStyle.fontSize) ?? 16) * fontScale;
  const lineHeight =
    (numericStyleValue(textStyle.lineHeight) ?? 0) * fontScale ||
    fontSize * Math.max(lineHeightMultiplier, 1.2);
  const availableWidth = Math.max(width - 48, 120);
  const hasArabicScript = /[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]/.test(
    text,
  );
  const averageGlyphWidth = fontSize * (hasArabicScript ? 0.5 : 0.42);
  const charsPerLine = Math.max(
    8,
    Math.floor(availableWidth / averageGlyphWidth),
  );
  const lines = text
    .split('\n')
    .reduce(
      (total, line) =>
        total + Math.max(1, Math.ceil(line.length / charsPerLine)),
      0,
    );
  return Math.ceil(lines * lineHeight + 2);
}
