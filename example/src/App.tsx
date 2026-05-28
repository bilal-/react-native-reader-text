import React, { useMemo, useState } from 'react';
import {
  Alert,
  FlatList,
  SafeAreaView,
  Share,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  ReaderText,
  type ReaderTextHighlight,
  type ReaderTextMenuActionEvent,
  type ReaderTextRange,
  type ReaderTextSelectionExclusionRange,
} from 'react-native-reader-text';

type Paragraph = {
  id: string;
  text: string;
  ranges?: ReaderTextRange[];
  selectionExclusionRanges?: ReaderTextSelectionExclusionRange[];
};

type SavedHighlight = ReaderTextHighlight & {
  paragraphId: string;
};

const paragraphs: Paragraph[] = [
  {
    id: 'p1',
    text: 'ReaderText renders native selectable text. Long press this paragraph to try the custom menu.',
  },
  {
    id: 'p2',
    text: 'Highlights are stored by paragraph-local UTF-16 offsets and passed back into the component.',
  },
  {
    id: 'p3',
    text: 'This paragraph has a footnote marker. 1',
    selectionExclusionRanges: [
      {
        start: 'This paragraph has a footnote marker. '.length,
        end: 'This paragraph has a footnote marker. 1'.length,
      },
    ],
    ranges: [
      {
        id: 'fn-1',
        start: 'This paragraph has a footnote marker. '.length,
        end: 'This paragraph has a footnote marker. 1'.length,
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
        metadata: { body: 'Footnote UI is owned by the app, not the library.' },
      },
    ],
  },
  ...Array.from({ length: 18 }, (_, index) => ({
    id: `generated-${index + 1}`,
    text: `Paragraph ${index + 1}: this FlatList item is an independent ReaderText instance with local selection offsets.`,
  })),
];

export default function App() {
  const [highlights, setHighlights] = useState<SavedHighlight[]>([
    {
      id: 'initial-h1',
      paragraphId: 'p2',
      start: 0,
      end: 10,
      color: '#FFE58A',
    },
  ]);
  const [lastAction, setLastAction] = useState(
    'Select text to use the native menu.',
  );
  const [clearSelectionSignal, setClearSelectionSignal] = useState(0);

  const menuItems = useMemo(
    () => [
      { id: 'highlight', title: 'Highlight' },
      { id: 'note', title: 'Note' },
      { id: 'share', title: 'Share' },
    ],
    [],
  );

  function handleMenuAction(
    paragraphId: string,
    event: ReaderTextMenuActionEvent,
  ) {
    setLastAction(`${event.title}: "${event.selection.text}"`);

    if (event.id === 'highlight') {
      setHighlights((current) => [
        ...current,
        {
          id: `${paragraphId}-${Date.now()}`,
          paragraphId,
          start: event.selection.start,
          end: event.selection.end,
          color: '#FFE58A',
        },
      ]);
      setClearSelectionSignal((signal) => signal + 1);
    }

    if (event.id === 'note') {
      Alert.alert(
        'Note action',
        `App note UI would open near x=${Math.round(event.anchor.x)}.`,
      );
      setClearSelectionSignal((signal) => signal + 1);
    }

    if (event.id === 'share') {
      void Share.share({ message: event.selection.text }).finally(() => {
        setClearSelectionSignal((signal) => signal + 1);
      });
    }
  }

  return (
    <SafeAreaView style={styles.screen}>
      <FlatList
        data={paragraphs}
        keyExtractor={(item) => item.id}
        ListHeaderComponent={
          <View style={styles.header}>
            <Text style={styles.title}>ReaderText Example</Text>
            <Text style={styles.status}>{lastAction}</Text>
            <ReaderText
              testID="multilingual-reader-text"
              segments={[
                { text: 'Mixed text example: ', lang: 'en' },
                { text: 'النص العربي ', lang: 'ar' },
                { text: 'اردو متن', lang: 'ur' },
              ]}
              selectable
              baseDirection="auto"
              menuItems={menuItems}
              clearSelectionSignal={clearSelectionSignal}
              typography={[
                { lang: 'en', fontScale: 1, lineHeightMultiplier: 1.4 },
                { lang: 'ar', fontScale: 1.15, lineHeightMultiplier: 1.65 },
                {
                  lang: 'ur',
                  fontScale: 1.25,
                  lineHeightMultiplier: 1.9,
                  baselineOffset: -1,
                },
              ]}
              textStyle={styles.multilingualReader}
              onMenuAction={(event) => handleMenuAction('multilingual', event)}
            />
          </View>
        }
        renderItem={({ item }) => {
          const paragraphHighlights = highlights
            .filter((highlight) => highlight.paragraphId === item.id)
            .map((highlight) => ({
              id: highlight.id,
              start: highlight.start,
              end: highlight.end,
              color: highlight.color,
            }));

          return (
            <View style={styles.paragraph}>
              <ReaderText
                testID={`reader-text-${item.id}`}
                text={item.text}
                selectable
                menuItems={menuItems}
                highlights={paragraphHighlights}
                ranges={item.ranges}
                selectionExclusionRanges={item.selectionExclusionRanges}
                clearSelectionSignal={clearSelectionSignal}
                baseDirection="auto"
                textStyle={styles.reader}
                onMenuAction={(event) => handleMenuAction(item.id, event)}
                onRangePress={(range) => {
                  const body = range.metadata?.body;
                  Alert.alert(
                    range.type === 'footnote' ? 'Footnote' : 'Range',
                    typeof body === 'string' ? body : range.id,
                  );
                }}
              />
            </View>
          );
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#F7F7F2',
  },
  header: {
    padding: 20,
    gap: 12,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#D8D6CC',
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
    color: '#1F2A24',
  },
  status: {
    fontSize: 14,
    color: '#59635D',
  },
  paragraph: {
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  reader: {
    fontSize: 18,
    lineHeight: 30,
    color: '#202420',
  },
  multilingualReader: {
    fontSize: 18,
    lineHeight: 22,
    color: '#202420',
  },
});
