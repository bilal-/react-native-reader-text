import React from 'react';
import { Dimensions, StyleSheet } from 'react-native';
import { NativeReaderTextView } from './NativeReaderTextView';
import type { ReaderTextProps } from './types';
import {
  buildLogicalText,
  normalizeHighlights,
  normalizeRanges,
  normalizeSegments,
  maxLineHeightMultiplier,
  rehydrateMenuAction,
  rehydrateRangePress,
} from './utils';

function numericStyleValue(value: unknown): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) && value > 0 ? value : undefined;
}

function estimateContentHeight(
  text: string,
  textStyle: Record<string, unknown>,
  width: number,
  lineHeightMultiplier: number,
): number {
  if (!text) return 0;
  const fontSize = numericStyleValue(textStyle.fontSize) ?? 16;
  const lineHeight = numericStyleValue(textStyle.lineHeight) ?? fontSize * Math.max(lineHeightMultiplier, 1.2);
  const availableWidth = Math.max(width - 48, 120);
  const hasArabicScript = /[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]/.test(text);
  const averageGlyphWidth = fontSize * (hasArabicScript ? 0.5 : 0.42);
  const charsPerLine = Math.max(8, Math.floor(availableWidth / averageGlyphWidth));
  const lines = text
    .split('\n')
    .reduce((total, line) => total + Math.max(1, Math.ceil(line.length / charsPerLine)), 0);
  return Math.ceil(lines * lineHeight + 2);
}

export function ReaderText(
  props: ReaderTextProps,
) {
  return <ReaderTextMeasured {...props} />;
}

type ReaderTextMeasuredState = {
  measuredHeight?: number;
  measuredText?: string;
  measuredWidth?: number;
};

class ReaderTextMeasured extends React.PureComponent<ReaderTextProps, ReaderTextMeasuredState> {
  state: ReaderTextMeasuredState = {};

  render() {
    const {
      text,
      segments,
      selectable = true,
      menuItems = [],
      highlights,
      ranges,
      typography = [],
      baseDirection = 'auto',
      style,
      textStyle,
      allowFontScaling = true,
      testID,
      onSelection,
      onMenuAction,
      onRangePress,
      onContentSizeChange,
    } = this.props;
    const width = Dimensions.get('window').width;
    const logicalText = buildLogicalText(text, segments);
    const normalizedSegments = normalizeSegments(logicalText, segments, typography);
    const normalizedHighlights = normalizeHighlights(highlights, logicalText.length);
    const normalizedRanges = normalizeRanges(ranges, logicalText.length);
    const nativeTextStyle = ({ ...(StyleSheet.flatten(textStyle) ?? {}) }) as Record<string, unknown>;
    const paragraphLineHeightMultiplier = maxLineHeightMultiplier(normalizedSegments);
    const estimatedMinHeight = estimateContentHeight(logicalText, nativeTextStyle, width, paragraphLineHeightMultiplier);
    const measuredHeight =
      this.state.measuredText === logicalText && this.state.measuredWidth === width
        ? this.state.measuredHeight
        : undefined;

    return (
      <NativeReaderTextView
        testID={testID}
        style={[styles.base, { minHeight: measuredHeight ?? estimatedMinHeight }, style]}
        text={logicalText}
        segments={normalizedSegments}
        selectable={selectable}
        menuItems={menuItems}
        highlights={normalizedHighlights}
        ranges={normalizedRanges}
        typography={typography}
        baseDirection={baseDirection}
        textStyle={nativeTextStyle}
        maxLineHeightMultiplier={paragraphLineHeightMultiplier}
        allowFontScaling={allowFontScaling}
        onSelection={onSelection ? (event) => onSelection(event.nativeEvent) : undefined}
        onMenuAction={onMenuAction ? (event) => onMenuAction(rehydrateMenuAction(event.nativeEvent)) : undefined}
        onRangePress={
          onRangePress
            ? (event) => onRangePress(rehydrateRangePress(event.nativeEvent, normalizedRanges))
            : undefined
        }
        onContentSizeChange={(event) => {
          const measuredWidth = event.nativeEvent.width;
          if (measuredWidth < 40 || measuredWidth > width + 8) return;
          const nextHeight = Math.ceil(event.nativeEvent.height);
          const maximumReasonableHeight = Math.max(estimatedMinHeight * 2, estimatedMinHeight + 96);
          if (nextHeight > maximumReasonableHeight) return;
          this.setState((current) => (
            nextHeight > 0 &&
            (current.measuredText !== logicalText ||
              current.measuredWidth !== width ||
              Math.abs((current.measuredHeight ?? 0) - nextHeight) > 1)
              ? { measuredHeight: nextHeight, measuredText: logicalText, measuredWidth: width }
              : null
          ));
          onContentSizeChange?.(event.nativeEvent);
        }}
      />
    );
  }
}

const styles = StyleSheet.create({
  base: {
    alignSelf: 'stretch',
  },
});
