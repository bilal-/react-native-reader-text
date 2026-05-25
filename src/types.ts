import type { StyleProp, TextStyle, ViewStyle } from 'react-native';

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
  presentation?: 'plain' | 'marker';
  markerStyle?: ReaderTextMarkerStyle;
  metadata?: Record<string, unknown>;
};

export type ReaderTextMarkerStyle = {
  backgroundColor?: string;
  borderColor?: string;
  textColor?: string;
  fontScale?: number;
  baselineOffset?: number;
  horizontalPadding?: number;
  verticalPadding?: number;
  borderRadius?: number;
  minWidth?: number;
  minHeight?: number;
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
  lang: string;
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
  typography?: ReaderTextTypographyProfile[];
  baseDirection?: 'auto' | 'ltr' | 'rtl';
  style?: StyleProp<ViewStyle>;
  textStyle?: StyleProp<TextStyle>;
  allowFontScaling?: boolean;
  testID?: string;
  onSelection?: (selection: ReaderTextSelection) => void;
  onMenuAction?: (event: ReaderTextMenuActionEvent) => void;
  onRangePress?: (range: ReaderTextRange) => void;
  onContentSizeChange?: (size: { width: number; height: number }) => void;
};

export type NativeReaderTextEvent<T> = {
  nativeEvent: T;
};

export type NativeReaderTextMenuActionEvent = {
  id: string;
  title: string;
  selectionText: string;
  selectionStart: number;
  selectionEnd: number;
  anchorX: number;
  anchorY: number;
  anchorWidth: number;
  anchorHeight: number;
};

export type NativeReaderTextRangePressEvent = {
  id: string;
  start: number;
  end: number;
  type?: string;
};
