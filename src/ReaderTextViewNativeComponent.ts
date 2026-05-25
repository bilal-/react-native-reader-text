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

type Range = Readonly<{
  id: string;
  start: Int32;
  end: Int32;
  type?: string;
  presentation?: string;
  markerStyle?: MarkerStyle;
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

export type NativeSelectionEvent = Readonly<{
  text: string;
  start: Int32;
  end: Int32;
}>;

export type NativeMenuActionEvent = Readonly<{
  id: string;
  title: string;
  selectionText: string;
  selectionStart: Int32;
  selectionEnd: Int32;
  anchorX: Double;
  anchorY: Double;
  anchorWidth: Double;
  anchorHeight: Double;
}>;

export type NativeRangePressEvent = Readonly<{
  id: string;
  start: Int32;
  end: Int32;
  type?: string;
}>;

export type NativeContentSizeChangeEvent = Readonly<{
  width: Double;
  height: Double;
}>;

export interface NativeProps extends ViewProps {
  text: string;
  segments?: ReadonlyArray<Segment>;
  selectable?: WithDefault<boolean, true>;
  menuItems?: ReadonlyArray<MenuItem>;
  highlights?: ReadonlyArray<Highlight>;
  ranges?: ReadonlyArray<Range>;
  typography?: ReadonlyArray<TypographyProfile>;
  baseDirection?: WithDefault<string, 'auto'>;
  textStyle?: NativeTextStyle;
  maxLineHeightMultiplier?: WithDefault<Double, 1>;
  allowFontScaling?: WithDefault<boolean, true>;
  onSelection?: DirectEventHandler<NativeSelectionEvent>;
  onMenuAction?: DirectEventHandler<NativeMenuActionEvent>;
  onRangePress?: DirectEventHandler<NativeRangePressEvent>;
  onContentSizeChange?: DirectEventHandler<NativeContentSizeChangeEvent>;
}

export default codegenNativeComponent<NativeProps>(
  'ReaderTextView',
) as HostComponent<NativeProps>;
