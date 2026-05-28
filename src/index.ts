export { ReaderText } from './ReaderText';
export {
  buildLogicalText,
  getSelectedText,
  isValidRange,
  maxLineHeightMultiplier,
  mergeTypographyProfile,
  normalizeHighlights,
  normalizeRanges,
  normalizeSelectionExclusionRanges,
  normalizeSegments,
  selectionWithExcludedRanges,
} from './utils';
export type {
  NativeReaderTextEvent,
  ReaderTextHighlight,
  ReaderTextLanguage,
  ReaderTextMenuActionEvent,
  ReaderTextMenuItem,
  ReaderTextProps,
  ReaderTextRange,
  ReaderTextSegment,
  ReaderTextSelection,
  ReaderTextSelectionExclusionRange,
  ReaderTextSelectionAnchor,
  ReaderTextTypographyProfile,
} from './types';
