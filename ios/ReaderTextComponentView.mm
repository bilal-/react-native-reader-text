#ifdef RCT_NEW_ARCH_ENABLED

#import <React/RCTConversions.h>
#import <React/RCTComponent.h>
#import <React/RCTViewComponentView.h>
#import <react/renderer/components/ReaderTextViewSpec/ComponentDescriptors.h>
#import <react/renderer/components/ReaderTextViewSpec/EventEmitters.h>
#import <react/renderer/components/ReaderTextViewSpec/Props.h>
#import <react/renderer/components/ReaderTextViewSpec/RCTComponentViewHelpers.h>

#import "react_native_reader_text-Swift.h"

using namespace facebook::react;

static NSDictionary *RCTReaderTextMarkerStyleDictionary(const ReaderTextViewRangesMarkerStyleStruct &style)
{
  NSMutableDictionary *dict = [NSMutableDictionary new];
  if (!style.backgroundColor.empty()) {
    dict[@"backgroundColor"] = @(style.backgroundColor.c_str());
  }
  if (!style.borderColor.empty()) {
    dict[@"borderColor"] = @(style.borderColor.c_str());
  }
  if (!style.textColor.empty()) {
    dict[@"textColor"] = @(style.textColor.c_str());
  }
  if (style.fontScale != 0) {
    dict[@"fontScale"] = @(style.fontScale);
  }
  if (style.baselineOffset != 0) {
    dict[@"baselineOffset"] = @(style.baselineOffset);
  }
  if (style.horizontalPadding != 0) {
    dict[@"horizontalPadding"] = @(style.horizontalPadding);
  }
  if (style.verticalPadding != 0) {
    dict[@"verticalPadding"] = @(style.verticalPadding);
  }
  if (style.borderRadius != 0) {
    dict[@"borderRadius"] = @(style.borderRadius);
  }
  if (style.minWidth != 0) {
    dict[@"minWidth"] = @(style.minWidth);
  }
  if (style.minHeight != 0) {
    dict[@"minHeight"] = @(style.minHeight);
  }
  return dict;
}

static NSArray *RCTReaderTextSegmentsArray(const std::vector<ReaderTextViewSegmentsStruct> &segments)
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:segments.size()];
  for (const auto &segment : segments) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"start"] = @(segment.start);
    dict[@"end"] = @(segment.end);
    dict[@"text"] = @(segment.text.c_str());
    if (!segment.lang.empty()) {
      dict[@"lang"] = @(segment.lang.c_str());
    }
    if (!segment.fontFamily.empty()) {
      dict[@"fontFamily"] = @(segment.fontFamily.c_str());
    }
    if (!segment.color.empty()) {
      dict[@"color"] = @(segment.color.c_str());
    }
    if (segment.fontScale != 0) {
      dict[@"fontScale"] = @(segment.fontScale);
    }
    if (segment.baselineOffset != 0) {
      dict[@"baselineOffset"] = @(segment.baselineOffset);
    }
    if (segment.lineHeightMultiplier != 0) {
      dict[@"lineHeightMultiplier"] = @(segment.lineHeightMultiplier);
    }
    [array addObject:dict];
  }
  return array;
}

static NSArray *RCTReaderTextMenuItemsArray(const std::vector<ReaderTextViewMenuItemsStruct> &items)
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:items.size()];
  for (const auto &item : items) {
    [array addObject:@{
      @"id" : @(item.id.c_str()),
      @"title" : @(item.title.c_str()),
    }];
  }
  return array;
}

static NSArray *RCTReaderTextHighlightsArray(const std::vector<ReaderTextViewHighlightsStruct> &highlights)
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:highlights.size()];
  for (const auto &highlight : highlights) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"id"] = @(highlight.id.c_str());
    dict[@"start"] = @(highlight.start);
    dict[@"end"] = @(highlight.end);
    if (!highlight.color.empty()) {
      dict[@"color"] = @(highlight.color.c_str());
    }
    [array addObject:dict];
  }
  return array;
}

static NSArray *RCTReaderTextRangesArray(const std::vector<ReaderTextViewRangesStruct> &ranges)
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:ranges.size()];
  for (const auto &range : ranges) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"id"] = @(range.id.c_str());
    dict[@"start"] = @(range.start);
    dict[@"end"] = @(range.end);
    if (!range.type.empty()) {
      dict[@"type"] = @(range.type.c_str());
    }
    if (!range.presentation.empty()) {
      dict[@"presentation"] = @(range.presentation.c_str());
    }
    NSDictionary *markerStyle = RCTReaderTextMarkerStyleDictionary(range.markerStyle);
    if (markerStyle.count > 0) {
      dict[@"markerStyle"] = markerStyle;
    }
    [array addObject:dict];
  }
  return array;
}

static NSArray *RCTReaderTextTypographyArray(const std::vector<ReaderTextViewTypographyStruct> &typography)
{
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:typography.size()];
  for (const auto &profile : typography) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"lang"] = @(profile.lang.c_str());
    if (!profile.fontFamily.empty()) {
      dict[@"fontFamily"] = @(profile.fontFamily.c_str());
    }
    if (!profile.color.empty()) {
      dict[@"color"] = @(profile.color.c_str());
    }
    if (profile.fontScale != 0) {
      dict[@"fontScale"] = @(profile.fontScale);
    }
    if (profile.fontSize != 0) {
      dict[@"fontSize"] = @(profile.fontSize);
    }
    if (profile.lineHeightMultiplier != 0) {
      dict[@"lineHeightMultiplier"] = @(profile.lineHeightMultiplier);
    }
    if (profile.baselineOffset != 0) {
      dict[@"baselineOffset"] = @(profile.baselineOffset);
    }
    [array addObject:dict];
  }
  return array;
}

static NSDictionary *RCTReaderTextStyleDictionary(const ReaderTextViewTextStyleStruct &style)
{
  NSMutableDictionary *dict = [NSMutableDictionary new];
  if (!style.color.empty()) {
    dict[@"color"] = @(style.color.c_str());
  }
  if (!style.fontFamily.empty()) {
    dict[@"fontFamily"] = @(style.fontFamily.c_str());
  }
  if (style.fontSize != 0) {
    dict[@"fontSize"] = @(style.fontSize);
  }
  if (style.lineHeight != 0) {
    dict[@"lineHeight"] = @(style.lineHeight);
  }
  if (!style.textAlign.empty()) {
    dict[@"textAlign"] = @(style.textAlign.c_str());
  }
  return dict;
}

@interface ReaderTextComponentView : RCTViewComponentView <RCTReaderTextViewViewProtocol, ReaderTextViewEventDelegate>
@end

@implementation ReaderTextComponentView {
  ReaderTextView *_readerTextView;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider
{
  return concreteComponentDescriptorProvider<ReaderTextViewComponentDescriptor>();
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const ReaderTextViewProps>();
    _props = defaultProps;

    _readerTextView = [ReaderTextView new];
    _readerTextView.eventDelegate = self;
    self.contentView = _readerTextView;
  }
  return self;
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
  const auto &newProps = *std::static_pointer_cast<const ReaderTextViewProps>(props);

  _readerTextView.text = @(newProps.text.c_str());
  _readerTextView.segments = RCTReaderTextSegmentsArray(newProps.segments);
  _readerTextView.selectable = newProps.selectable;
  _readerTextView.menuItems = RCTReaderTextMenuItemsArray(newProps.menuItems);
  _readerTextView.highlights = RCTReaderTextHighlightsArray(newProps.highlights);
  _readerTextView.ranges = RCTReaderTextRangesArray(newProps.ranges);
  _readerTextView.typography = RCTReaderTextTypographyArray(newProps.typography);
  _readerTextView.baseDirection = @(newProps.baseDirection.c_str());
  _readerTextView.textStyle = RCTReaderTextStyleDictionary(newProps.textStyle);
  _readerTextView.maxLineHeightMultiplier = @(newProps.maxLineHeightMultiplier);
  _readerTextView.allowFontScaling = newProps.allowFontScaling;
  _readerTextView.clearSelectionSignal = @(newProps.clearSelectionSignal);

  [super updateProps:props oldProps:oldProps];
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  _readerTextView.eventDelegate = self;
}

- (void)readerTextView:(ReaderTextView *)view didSelect:(NSDictionary<NSString *,id> *)payload
{
  if (!_eventEmitter) {
    return;
  }
  auto eventEmitter = std::static_pointer_cast<const ReaderTextViewEventEmitter>(_eventEmitter);
  ReaderTextViewEventEmitter::OnSelection event = {
    .text = [[payload[@"text"] description] UTF8String],
    .start = [payload[@"start"] intValue],
    .end = [payload[@"end"] intValue],
  };
  eventEmitter->onSelection(event);
}

- (void)readerTextView:(ReaderTextView *)view didTriggerMenuAction:(NSDictionary<NSString *,id> *)payload
{
  if (!_eventEmitter) {
    return;
  }
  auto eventEmitter = std::static_pointer_cast<const ReaderTextViewEventEmitter>(_eventEmitter);
  ReaderTextViewEventEmitter::OnMenuAction event = {
    .id = [[payload[@"id"] description] UTF8String],
    .title = [[payload[@"title"] description] UTF8String],
    .selectionText = [[payload[@"selectionText"] description] UTF8String],
    .selectionStart = [payload[@"selectionStart"] intValue],
    .selectionEnd = [payload[@"selectionEnd"] intValue],
    .anchorX = [payload[@"anchorX"] doubleValue],
    .anchorY = [payload[@"anchorY"] doubleValue],
    .anchorWidth = [payload[@"anchorWidth"] doubleValue],
    .anchorHeight = [payload[@"anchorHeight"] doubleValue],
  };
  eventEmitter->onMenuAction(event);
}

- (void)readerTextView:(ReaderTextView *)view didPressRange:(NSDictionary<NSString *,id> *)payload
{
  if (!_eventEmitter) {
    return;
  }
  auto eventEmitter = std::static_pointer_cast<const ReaderTextViewEventEmitter>(_eventEmitter);
  ReaderTextViewEventEmitter::OnRangePress event = {
    .id = [[payload[@"id"] description] UTF8String],
    .start = [payload[@"start"] intValue],
    .end = [payload[@"end"] intValue],
    .type = [[payload[@"type"] description] UTF8String],
  };
  eventEmitter->onRangePress(event);
}

- (void)readerTextView:(ReaderTextView *)view didChangeContentSize:(NSDictionary<NSString *,id> *)payload
{
  if (!_eventEmitter) {
    return;
  }
  auto eventEmitter = std::static_pointer_cast<const ReaderTextViewEventEmitter>(_eventEmitter);
  ReaderTextViewEventEmitter::OnContentSizeChange event = {
    .width = [payload[@"width"] doubleValue],
    .height = [payload[@"height"] doubleValue],
  };
  eventEmitter->onContentSizeChange(event);
}

@end

Class<RCTComponentViewProtocol> ReaderTextComponentViewCls(void)
{
  return ReaderTextComponentView.class;
}

#endif
