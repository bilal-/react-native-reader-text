import {
  buildLogicalText,
  getSelectedText,
  isValidRange,
  maxLineHeightMultiplier,
  mergeTypographyProfile,
  normalizeHighlights,
  normalizeRanges,
  normalizeSegments,
  rehydrateMenuAction,
  rehydrateRangePress,
  typographyProfileMap,
} from '../src/utils';

describe('ReaderText utilities', () => {
  it('uses text when segments are absent', () => {
    expect(buildLogicalText('plain text')).toBe('plain text');
    expect(buildLogicalText()).toBe('');
  });

  it('lets segments take precedence over text', () => {
    expect(
      buildLogicalText('ignored', [
        { text: 'Read ', lang: 'en' },
        { text: 'النص', lang: 'ar' },
      ]),
    ).toBe('Read النص');
  });

  it('validates UTF-16 logical ranges', () => {
    expect(isValidRange({ start: 0, end: 2 }, 4)).toBe(true);
    expect(isValidRange({ start: 2, end: 2 }, 4)).toBe(false);
    expect(isValidRange({ start: -1, end: 2 }, 4)).toBe(false);
    expect(isValidRange({ start: 1, end: 5 }, 4)).toBe(false);
    expect(isValidRange({ start: 1.5, end: 2 }, 4)).toBe(false);
  });

  it('filters invalid highlights safely', () => {
    expect(normalizeHighlights(undefined, 5)).toEqual([]);
    expect(normalizeHighlights([], 5)).toEqual([]);
    expect(
      normalizeHighlights(
        [
          { id: 'valid', start: 1, end: 3, color: '#FFE58A' },
          { id: 'empty', start: 1, end: 1 },
          { id: 'long', start: 1, end: 99 },
        ],
        5,
      ),
    ).toEqual([{ id: 'valid', start: 1, end: 3, color: '#FFE58A' }]);
  });

  it('filters invalid generic ranges safely', () => {
    expect(normalizeRanges(undefined, 5)).toEqual([]);
    expect(normalizeRanges([], 5)).toEqual([]);
    expect(
      normalizeRanges(
        [
          {
            id: 'fn-1',
            start: 4,
            end: 5,
            type: 'footnote',
            presentation: 'marker',
            markerStyle: { minWidth: 16 },
          },
          { id: 'bad', start: 6, end: 5 },
        ],
        8,
      ),
    ).toEqual([
      {
        id: 'fn-1',
        start: 4,
        end: 5,
        type: 'footnote',
        presentation: 'marker',
        markerStyle: { minWidth: 16 },
      },
    ]);
  });

  it('merges typography profiles with segment overrides', () => {
    expect(
      mergeTypographyProfile(
        { fontFamily: 'System', fontScale: 1, lineHeightMultiplier: 1.4 },
        { text: 'اردو', lang: 'ur', fontScale: 1.25, baselineOffset: -1 },
      ),
    ).toEqual({
      fontFamily: 'System',
      fontScale: 1.25,
      lineHeightMultiplier: 1.4,
      baselineOffset: -1,
    });
  });

  it('allows all segment typography overrides', () => {
    expect(
      mergeTypographyProfile(
        { fontFamily: 'System', fontScale: 1, lineHeightMultiplier: 1.4, baselineOffset: 0 },
        {
          text: 'text',
          fontFamily: 'Custom',
          fontScale: 1.2,
          lineHeightMultiplier: 1.8,
          baselineOffset: 2,
        },
      ),
    ).toEqual({
      fontFamily: 'Custom',
      fontScale: 1.2,
      lineHeightMultiplier: 1.8,
      baselineOffset: 2,
    });
  });

  it('returns undefined for empty typography profiles', () => {
    expect(mergeTypographyProfile(undefined, { text: 'plain' })).toBeUndefined();
  });

  it('allows segment line height to override profile line height', () => {
    expect(
      mergeTypographyProfile(
        { lineHeightMultiplier: 1.3 },
        { text: 'text', lineHeightMultiplier: 2 },
      ),
    ).toEqual({ lineHeightMultiplier: 2 });
  });

  it('normalizes plain text as a single segment when no segments are provided', () => {
    expect(normalizeSegments('plain', undefined, undefined)).toEqual([
      { text: 'plain', start: 0, end: 5 },
    ]);
    expect(normalizeSegments('', undefined, undefined)).toEqual([]);
  });

  it('normalizes segment offsets against concatenated logical text', () => {
    expect(
      normalizeSegments(
        'Read النص',
        [
          { text: 'Read ', lang: 'en' },
          { text: 'النص', lang: 'ar' },
        ],
        [{ lang: 'ar', fontScale: 1.2 }],
      ),
    ).toEqual([
      { text: 'Read ', lang: 'en', start: 0, end: 5, typography: undefined },
      { text: 'النص', lang: 'ar', start: 5, end: 9, typography: { lang: 'ar', fontScale: 1.2 } },
    ]);
  });

  it('normalizes segments without a language profile', () => {
    expect(normalizeSegments('abc', [{ text: 'abc' }], undefined)).toEqual([
      { text: 'abc', start: 0, end: 3, typography: undefined },
    ]);
  });

  it('returns selected text for valid ranges only', () => {
    expect(getSelectedText('abcdef', 1, 4)).toEqual({ text: 'bcd', start: 1, end: 4 });
    expect(getSelectedText('abcdef', 4, 99)).toBeNull();
  });

  it('computes the maximum line height multiplier', () => {
    expect(
      maxLineHeightMultiplier([
        { text: 'a', start: 0, end: 1, typography: { lineHeightMultiplier: 1.3 } },
        { text: 'b', start: 1, end: 2, typography: { lineHeightMultiplier: 1.8 } },
      ]),
    ).toBe(1.8);
    expect(maxLineHeightMultiplier([{ text: 'a', start: 0, end: 1, lineHeightMultiplier: 1.6 }])).toBe(1.6);
    expect(maxLineHeightMultiplier([{ text: 'a', start: 0, end: 1 }], 1.2)).toBe(1.2);
  });

  it('builds a language-keyed typography profile map', () => {
    expect(
      typographyProfileMap([
        { lang: 'en', fontScale: 1 },
        { lang: 'ur', fontScale: 1.25 },
      ]),
    ).toEqual({
      en: { lang: 'en', fontScale: 1 },
      ur: { lang: 'ur', fontScale: 1.25 },
    });
  });

  it('rehydrates flat native menu events into public nested events', () => {
    expect(
      rehydrateMenuAction({
        id: 'highlight',
        title: 'Highlight',
        selectionText: 'selected',
        selectionStart: 2,
        selectionEnd: 10,
        anchorX: 1,
        anchorY: 2,
        anchorWidth: 3,
        anchorHeight: 4,
      }),
    ).toEqual({
      id: 'highlight',
      title: 'Highlight',
      selection: { text: 'selected', start: 2, end: 10 },
      anchor: { x: 1, y: 2, width: 3, height: 4 },
    });
  });

  it('rehydrates range presses back to the original range metadata', () => {
    const original = {
      id: 'fn-1',
      start: 4,
      end: 5,
      type: 'footnote',
      metadata: { body: 'Footnote body' },
    };

    expect(
      rehydrateRangePress(
        { id: 'fn-1', start: 4, end: 5, type: 'footnote' },
        [original],
      ),
    ).toBe(original);
    expect(rehydrateRangePress({ id: 'missing', start: 1, end: 2 }, [])).toEqual({
      id: 'missing',
      start: 1,
      end: 2,
      type: undefined,
    });
    expect(
      rehydrateRangePress(
        { id: 'link-1', start: 1, end: 2 },
        [{ id: 'link-1', start: 1, end: 2, metadata: { href: '#' } }],
      ),
    ).toEqual({ id: 'link-1', start: 1, end: 2, metadata: { href: '#' } });
  });
});
