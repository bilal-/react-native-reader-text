import Foundation
import React
import UIKit

@objc(ReaderTextViewEventDelegate)
public protocol ReaderTextViewEventDelegate: AnyObject {
  func readerTextView(_ view: ReaderTextView, didSelect payload: [String: Any])
  func readerTextView(_ view: ReaderTextView, didTriggerMenuAction payload: [String: Any])
  func readerTextView(_ view: ReaderTextView, didPressRange payload: [String: Any])
  func readerTextView(_ view: ReaderTextView, didChangeContentSize payload: [String: Any])
}

@objc(ReaderTextViewManager)
final class ReaderTextViewManager: RCTViewManager {
  override static func requiresMainQueueSetup() -> Bool {
    true
  }

  override func view() -> UIView! {
    ReaderTextView()
  }

}

@objc(ReaderTextView)
public final class ReaderTextView: UIView, UITextViewDelegate, UIGestureRecognizerDelegate {
  @objc public var text: String = "" { didSet { rebuildText() } }
  @objc public var segments: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc public var selectable: Bool = true { didSet { textView.isSelectable = selectable } }
  @objc public var menuItems: [[String: Any]] = [] { didSet { textView.menuItemCount = menuItems.count } }
  @objc public var highlights: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc public var ranges: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc public var typography: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc public var baseDirection: String = "auto" { didSet { rebuildText() } }
  @objc public var textStyle: [String: Any] = [:] { didSet { rebuildText() } }
  @objc public var maxLineHeightMultiplier: NSNumber = 1 { didSet { rebuildText() } }
  @objc public var allowFontScaling: Bool = true { didSet { rebuildText() } }
  @objc public var onSelection: RCTDirectEventBlock?
  @objc public var onMenuAction: RCTDirectEventBlock?
  @objc public var onRangePress: RCTDirectEventBlock?
  @objc public var onContentSizeChange: RCTDirectEventBlock?
  @objc public weak var eventDelegate: ReaderTextViewEventDelegate?

  fileprivate let textView = ReaderUITextView()
  private var normalizedRanges: [[String: Any]] = []
  private var lastReportedContentSize: CGSize = .zero

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    textView.frame = bounds
    reportContentSizeIfNeeded()
  }

  fileprivate func emitMenuAction(index: Int) {
    guard index >= 0, index < menuItems.count else { return }
    let range = textView.selectedRange
    guard range.length > 0 else { return }
    let nsText = text as NSString
    guard range.location + range.length <= nsText.length else { return }
    let item = menuItems[index]
    let selection = selectionPayload(range: range)
    let anchor = anchorPayload(range: range)
    let payload: [String: Any] = [
      "id": item["id"] as? String ?? item["title"] as? String ?? "",
      "title": item["title"] as? String ?? item["id"] as? String ?? "",
      "selectionText": selection["text"] ?? "",
      "selectionStart": selection["start"] ?? 0,
      "selectionEnd": selection["end"] ?? 0,
      "anchorX": anchor["x"] ?? 0,
      "anchorY": anchor["y"] ?? 0,
      "anchorWidth": anchor["width"] ?? 0,
      "anchorHeight": anchor["height"] ?? 0,
    ]
    onMenuAction?(payload)
    eventDelegate?.readerTextView(self, didTriggerMenuAction: payload)
  }

  fileprivate func menuTitle(at index: Int) -> String {
    guard index >= 0, index < menuItems.count else { return "" }
    let item = menuItems[index]
    return item["title"] as? String ?? item["id"] as? String ?? ""
  }

  public func textViewDidChangeSelection(_ textView: UITextView) {
    let range = textView.selectedRange
    guard range.length > 0 else { return }
    let nsText = text as NSString
    guard range.location + range.length <= nsText.length else { return }
    let payload = selectionPayload(range: range)
    onSelection?(payload)
    eventDelegate?.readerTextView(self, didSelect: payload)
  }

  private func setup() {
    textView.owner = self
    textView.delegate = self
    textView.backgroundColor = .clear
    textView.isEditable = false
    textView.isSelectable = true
    textView.isScrollEnabled = false
    textView.textContainerInset = .zero
    textView.textContainer.lineFragmentPadding = 0
    textView.adjustsFontForContentSizeCategory = true
    addSubview(textView)

    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    tap.cancelsTouchesInView = false
    tap.delegate = self
    textView.addGestureRecognizer(tap)
  }

  private func rebuildText() {
    normalizedRanges = ranges.filter { validRange($0, length: (text as NSString).length) }

    let attributed = NSMutableAttributedString(string: text)
    let fullRange = NSRange(location: 0, length: attributed.length)
    attributed.addAttributes(baseAttributes(), range: fullRange)

    applyParagraphStyle(attributed)
    applyHighlights(attributed)
    applySegments(attributed)
    applyMarkerRanges(attributed)
    textView.attributedText = attributed
    textView.isSelectable = selectable
    textView.accessibilityLabel = text
    textView.menuItemCount = menuItems.count
    setNeedsLayout()
    DispatchQueue.main.async { [weak self] in
      self?.reportContentSizeIfNeeded()
    }
  }

  private func reportContentSizeIfNeeded() {
    let targetWidth = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
    guard targetWidth > 0 else { return }
    let fittingSize = textView.sizeThatFits(CGSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude))
    let width = ceil(targetWidth)
    let height = ceil(fittingSize.height)
    guard height > 0 else { return }
    let nextSize = CGSize(width: width, height: height)
    guard abs(nextSize.width - lastReportedContentSize.width) > 0.5 ||
          abs(nextSize.height - lastReportedContentSize.height) > 0.5 else {
      return
    }
    lastReportedContentSize = nextSize
    let payload: [String: Any] = [
      "width": width,
      "height": height,
    ]
    onContentSizeChange?(payload)
    eventDelegate?.readerTextView(self, didChangeContentSize: payload)
  }

  private func baseAttributes() -> [NSAttributedString.Key: Any] {
    var attributes: [NSAttributedString.Key: Any] = [.font: scaledFont(baseFont())]

    if let color = color(textStyle["color"]) {
      attributes[.foregroundColor] = color
    }

    return attributes
  }

  private func applyParagraphStyle(_ attributed: NSMutableAttributedString) {
    let style = NSMutableParagraphStyle()
    switch baseDirection {
    case "ltr":
      style.baseWritingDirection = .leftToRight
      textView.textAlignment = .left
    case "rtl":
      style.baseWritingDirection = .rightToLeft
      textView.textAlignment = .right
    default:
      style.baseWritingDirection = .natural
      textView.textAlignment = .natural
    }
    let lineHeightMultiplier = max(CGFloat(maxLineHeightMultiplier.doubleValue), 1)
    if let lineHeight = number(textStyle["lineHeight"]) {
      style.minimumLineHeight = lineHeight
      style.maximumLineHeight = lineHeight
    } else if lineHeightMultiplier > 1 {
      let fontSize = (attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize ?? 17
      let lineHeight = fontSize * lineHeightMultiplier
      style.minimumLineHeight = lineHeight
      style.maximumLineHeight = lineHeight
    }
    attributed.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: attributed.length))
  }

  private func applyHighlights(_ attributed: NSMutableAttributedString) {
    for highlight in highlights where validRange(highlight, length: attributed.length) {
      let range = nsRange(highlight)
      attributed.addAttribute(
        .backgroundColor,
        value: color(highlight["color"]) ?? UIColor(red: 1, green: 0.898, blue: 0.541, alpha: 1),
        range: range
      )
    }
  }

  private func applySegments(_ attributed: NSMutableAttributedString) {
    for segment in segments where validRange(segment, length: attributed.length) {
      let range = nsRange(segment)
      let profile = typographyProfile(segment)
      var currentFont = baseFont()

      if let fontSize = number(profile["fontSize"]) {
        currentFont = currentFont.withSize(fontSize)
      }
      if let fontScale = number(profile["fontScale"]) {
        currentFont = currentFont.withSize(currentFont.pointSize * fontScale)
      }
      if let family = profile["fontFamily"] as? String,
         let familyFont = UIFont(name: family, size: currentFont.pointSize) {
        currentFont = familyFont
      }
      attributed.addAttribute(.font, value: scaledFont(currentFont), range: range)

      if let segmentColor = color(profile["color"]) {
        attributed.addAttribute(.foregroundColor, value: segmentColor, range: range)
      }
      if let baselineOffset = number(profile["baselineOffset"]) {
        attributed.addAttribute(.baselineOffset, value: baselineOffset, range: range)
      }
    }
  }

  private func applyMarkerRanges(_ attributed: NSMutableAttributedString) {
    for range in normalizedRanges where range["presentation"] as? String == "marker" {
      let markerRange = nsRange(range)
      let style = range["markerStyle"] as? [String: Any] ?? [:]
      let currentFont = attributed.attribute(.font, at: markerRange.location, effectiveRange: nil) as? UIFont ?? baseFont()
      let markerFont = scaledFont(currentFont.withSize(currentFont.pointSize * (number(style["fontScale"]) ?? 0.72)))

      attributed.addAttributes(
        [
          .font: markerFont,
          .foregroundColor: color(style["textColor"]) ?? UIColor(red: 0.302, green: 0.22, blue: 0.153, alpha: 1),
          .backgroundColor: color(style["backgroundColor"]) ?? UIColor(red: 0.957, green: 0.937, blue: 0.906, alpha: 1),
          .baselineOffset: number(style["baselineOffset"]) ?? 4,
        ],
        range: markerRange
      )
    }
  }

  private func typographyProfile(_ segment: [String: Any]) -> [String: Any] {
    if let profile = segment["typography"] as? [String: Any] {
      return profile
    }
    guard let lang = segment["lang"] as? String else { return [:] }
    return typography.first { $0["lang"] as? String == lang } ?? [:]
  }

  private func baseFont() -> UIFont {
    let fontSize = number(textStyle["fontSize"]) ?? 17
    let family = textStyle["fontFamily"] as? String
    return family.flatMap { UIFont(name: $0, size: fontSize) } ?? UIFont.systemFont(ofSize: fontSize)
  }

  private func scaledFont(_ font: UIFont) -> UIFont {
    guard allowFontScaling else { return font }
    return UIFontMetrics.default.scaledFont(for: font)
  }

  @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    guard gesture.state == .ended, !normalizedRanges.isEmpty else { return }
    let point = gesture.location(in: textView)
    guard let offset = characterOffset(at: point) else { return }
    guard textView.selectedRange.length == 0 else { return }
    guard let range = normalizedRanges.first(where: {
      guard let start = $0["start"] as? Int, let end = $0["end"] as? Int else { return false }
      return offset >= start && offset < end
    }) else { return }
    let payload: [String: Any] = [
      "id": range["id"] as? String ?? "",
      "start": range["start"] as? Int ?? 0,
      "end": range["end"] as? Int ?? 0,
      "type": range["type"] as? String ?? "",
    ]
    onRangePress?(payload)
    eventDelegate?.readerTextView(self, didPressRange: payload)
  }

  private func characterOffset(at point: CGPoint) -> Int? {
    var location = point
    location.x -= textView.textContainerInset.left
    location.y -= textView.textContainerInset.top
    let glyphIndex = textView.layoutManager.glyphIndex(
      for: location,
      in: textView.textContainer
    )
    return textView.layoutManager.characterIndexForGlyph(at: glyphIndex)
  }

  private func selectionPayload(range: NSRange) -> [String: Any] {
    [
      "text": (text as NSString).substring(with: range),
      "start": range.location,
      "end": range.location + range.length,
    ]
  }

  private func anchorPayload(range: NSRange) -> [String: Any] {
    guard
      let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
      let end = textView.position(from: start, offset: range.length),
      let textRange = textView.textRange(from: start, to: end)
    else {
      return ["x": 0, "y": 0, "width": 0, "height": 0]
    }

    let rect = textView.convert(textView.firstRect(for: textRange), to: nil)
    return [
      "x": rect.origin.x,
      "y": rect.origin.y,
      "width": rect.width,
      "height": rect.height,
    ]
  }
}

final class ReaderUITextView: UITextView {
  weak var owner: ReaderTextView?
  var menuItemCount = 0

  override func buildMenu(with builder: any UIMenuBuilder) {
    super.buildMenu(with: builder)
    guard menuItemCount > 0 else { return }

    let actions = (0..<min(menuItemCount, 8)).map { index in
      UIAction(title: owner?.menuTitle(at: index) ?? "") { [weak self] _ in
        self?.owner?.emitMenuAction(index: index)
      }
    }

    builder.insertChild(UIMenu(title: "", options: .displayInline, children: actions), atStartOfMenu: .edit)
  }

}

private func validRange(_ dictionary: [String: Any], length: Int) -> Bool {
  guard let start = dictionary["start"] as? Int, let end = dictionary["end"] as? Int else { return false }
  return start >= 0 && end > start && end <= length
}

private func nsRange(_ dictionary: [String: Any]) -> NSRange {
  let start = dictionary["start"] as? Int ?? 0
  let end = dictionary["end"] as? Int ?? start
  return NSRange(location: start, length: end - start)
}

private func number(_ value: Any?) -> CGFloat? {
  if let value = value as? CGFloat { return value }
  if let value = value as? Double { return CGFloat(value) }
  if let value = value as? Float { return CGFloat(value) }
  if let value = value as? Int { return CGFloat(value) }
  return nil
}

private func color(_ value: Any?) -> UIColor? {
  guard let string = value as? String else { return nil }
  var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
  if hex.hasPrefix("#") { hex.removeFirst() }
  guard hex.count == 6 || hex.count == 8, let int = UInt64(hex, radix: 16) else { return nil }
  let hasAlpha = hex.count == 8
  let redShift = hasAlpha ? 24 : 16
  let greenShift = hasAlpha ? 16 : 8
  let blueShift = hasAlpha ? 8 : 0
  let red = CGFloat((int >> redShift) & 0xFF) / 255
  let green = CGFloat((int >> greenShift) & 0xFF) / 255
  let blue = CGFloat((int >> blueShift) & 0xFF) / 255
  let alpha = hasAlpha ? CGFloat(int & 0xFF) / 255 : 1
  return UIColor(red: red, green: green, blue: blue, alpha: alpha)
}
