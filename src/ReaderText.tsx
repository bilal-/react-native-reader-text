import React, { useMemo } from 'react';
import { StyleSheet } from 'react-native';
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

export function ReaderText(
  {
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
  }: ReaderTextProps,
) {
  const logicalText = useMemo(() => buildLogicalText(text, segments), [text, segments]);
  const normalizedSegments = useMemo(
    () => normalizeSegments(logicalText, segments, typography),
    [logicalText, segments, typography],
  );
  const normalizedHighlights = useMemo(
    () => normalizeHighlights(highlights, logicalText.length),
    [highlights, logicalText.length],
  );
  const normalizedRanges = useMemo(
    () => normalizeRanges(ranges, logicalText.length),
    [ranges, logicalText.length],
  );
  const nativeTextStyle = useMemo(
    () => ({ ...(StyleSheet.flatten(textStyle) ?? {}) }) as Record<string, unknown>,
    [textStyle],
  );
  const paragraphLineHeightMultiplier = useMemo(
    () => maxLineHeightMultiplier(normalizedSegments),
    [normalizedSegments],
  );

  return (
    <NativeReaderTextView
      testID={testID}
      style={[styles.base, style]}
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
    />
  );
}

const styles = StyleSheet.create({
  base: {
    alignSelf: 'stretch',
  },
});
