#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE(ReaderTextViewManager, RCTViewManager)

RCT_EXPORT_VIEW_PROPERTY(text, NSString)
RCT_EXPORT_VIEW_PROPERTY(segments, NSArray)
RCT_EXPORT_VIEW_PROPERTY(selectable, BOOL)
RCT_EXPORT_VIEW_PROPERTY(menuItems, NSArray)
RCT_EXPORT_VIEW_PROPERTY(highlights, NSArray)
RCT_EXPORT_VIEW_PROPERTY(ranges, NSArray)
RCT_EXPORT_VIEW_PROPERTY(typography, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(baseDirection, NSString)
RCT_EXPORT_VIEW_PROPERTY(textStyle, NSDictionary)
RCT_EXPORT_VIEW_PROPERTY(maxLineHeightMultiplier, NSNumber)
RCT_EXPORT_VIEW_PROPERTY(allowFontScaling, BOOL)
RCT_EXPORT_VIEW_PROPERTY(onSelection, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onMenuAction, RCTDirectEventBlock)
RCT_EXPORT_VIEW_PROPERTY(onRangePress, RCTDirectEventBlock)

@end
