import { requireNativeComponent } from 'react-native';
import type { HostComponent, ViewProps } from 'react-native';
import type {
  NativeReaderTextEvent,
  ReaderTextHighlight,
  ReaderTextMenuActionEvent,
  ReaderTextMenuItem,
  ReaderTextRange,
  ReaderTextSelection,
  ReaderTextSegment,
  ReaderTextTypographyProfile,
} from './types';

export type NativeReaderTextViewProps = ViewProps & {
  text: string;
  segments: ReaderTextSegment[];
  selectable: boolean;
  menuItems: ReaderTextMenuItem[];
  highlights: ReaderTextHighlight[];
  ranges: ReaderTextRange[];
  typography: Record<string, ReaderTextTypographyProfile>;
  baseDirection: 'auto' | 'ltr' | 'rtl';
  textStyle?: Record<string, unknown>;
  maxLineHeightMultiplier: number;
  allowFontScaling: boolean;
  onSelection?: (event: NativeReaderTextEvent<ReaderTextSelection>) => void;
  onMenuAction?: (event: NativeReaderTextEvent<ReaderTextMenuActionEvent>) => void;
  onRangePress?: (event: NativeReaderTextEvent<ReaderTextRange>) => void;
};

const COMPONENT_NAME = 'ReaderTextView';

export const NativeReaderTextView =
  requireNativeComponent<NativeReaderTextViewProps>(COMPONENT_NAME) as HostComponent<NativeReaderTextViewProps>;
