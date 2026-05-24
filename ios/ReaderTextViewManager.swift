import Foundation
import React
import UIKit

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
final class ReaderTextView: UIView, UITextViewDelegate, UIGestureRecognizerDelegate {
  @objc var text: String = "" { didSet { rebuildText() } }
  @objc var segments: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc var selectable: Bool = true { didSet { textView.isSelectable = selectable } }
  @objc var menuItems: [[String: Any]] = [] { didSet { textView.menuItemCount = menuItems.count } }
  @objc var highlights: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc var ranges: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc var typography: [String: [String: Any]] = [:] { didSet { rebuildText() } }
  @objc var baseDirection: String = "auto" { didSet { rebuildText() } }
  @objc var textStyle: [String: Any] = [:] { didSet { rebuildText() } }
  @objc var maxLineHeightMultiplier: NSNumber = 1 { didSet { rebuildText() } }
  @objc var allowFontScaling: Bool = true { didSet { rebuildText() } }
  @objc var onSelection: RCTDirectEventBlock?
  @objc var onMenuAction: RCTDirectEventBlock?
  @objc var onRangePress: RCTDirectEventBlock?

  fileprivate let textView = ReaderUITextView()
  private var normalizedRanges: [[String: Any]] = []

  override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    textView.frame = bounds
  }

  fileprivate func emitMenuAction(index: Int) {
    guard index >= 0, index < menuItems.count else { return }
    let range = textView.selectedRange
    guard range.length > 0 else { return }
    let nsText = text as NSString
    guard range.location + range.length <= nsText.length else { return }
    let item = menuItems[index]
    onMenuAction?([
      "id": item["id"] as? String ?? item["title"] as? String ?? "",
      "title": item["title"] as? String ?? item["id"] as? String ?? "",
      "selection": selectionPayload(range: range),
      "anchor": anchorPayload(range: range),
    ])
  }

  fileprivate func menuTitle(at index: Int) -> String {
    guard index >= 0, index < menuItems.count else { return "" }
    let item = menuItems[index]
    return item["title"] as? String ?? item["id"] as? String ?? ""
  }

  func textViewDidChangeSelection(_ textView: UITextView) {
    let range = textView.selectedRange
    guard range.length > 0 else { return }
    let nsText = text as NSString
    guard range.location + range.length <= nsText.length else { return }
    onSelection?(selectionPayload(range: range))
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
    textView.attributedText = attributed
    textView.isSelectable = selectable
    textView.accessibilityLabel = text
    textView.menuItemCount = menuItems.count
  }

  private func baseAttributes() -> [NSAttributedString.Key: Any] {
    let fontSize = number(textStyle["fontSize"]) ?? 17
    let family = textStyle["fontFamily"] as? String
    let font = family.flatMap { UIFont(name: $0, size: fontSize) } ?? UIFont.systemFont(ofSize: fontSize)
    var attributes: [NSAttributedString.Key: Any] = [.font: scaledFont(font)]

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
    if let lineHeight = number(textStyle["lineHeight"]) {
      style.minimumLineHeight = lineHeight
      style.maximumLineHeight = lineHeight
    } else if maxLineHeightMultiplier.doubleValue > 1 {
      let fontSize = (attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize ?? 17
      let lineHeight = fontSize * CGFloat(maxLineHeightMultiplier.doubleValue)
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
      var currentFont = attributed.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
        ?? UIFont.systemFont(ofSize: 17)

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

      if let baselineOffset = number(profile["baselineOffset"]) {
        attributed.addAttribute(.baselineOffset, value: baselineOffset, range: range)
      }
    }
  }

  private func typographyProfile(_ segment: [String: Any]) -> [String: Any] {
    if let profile = segment["typography"] as? [String: Any] {
      return profile
    }
    guard let lang = segment["lang"] as? String else { return [:] }
    return typography[lang] ?? [:]
  }

  private func writingDirection() -> NSWritingDirection {
    switch baseDirection {
    case "ltr": return .leftToRight
    case "rtl": return .rightToLeft
    default: return .natural
    }
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
    onRangePress?(range)
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

  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if Self.index(for: action) != nil {
      return selectedRange.length > 0
    }
    if action == #selector(copy(_:)) {
      return super.canPerformAction(action, withSender: sender)
    }
    return super.canPerformAction(action, withSender: sender)
  }

  @objc func readerTextMenuAction0(_ sender: Any?) { owner?.emitMenuAction(index: 0) }
  @objc func readerTextMenuAction1(_ sender: Any?) { owner?.emitMenuAction(index: 1) }
  @objc func readerTextMenuAction2(_ sender: Any?) { owner?.emitMenuAction(index: 2) }
  @objc func readerTextMenuAction3(_ sender: Any?) { owner?.emitMenuAction(index: 3) }
  @objc func readerTextMenuAction4(_ sender: Any?) { owner?.emitMenuAction(index: 4) }
  @objc func readerTextMenuAction5(_ sender: Any?) { owner?.emitMenuAction(index: 5) }
  @objc func readerTextMenuAction6(_ sender: Any?) { owner?.emitMenuAction(index: 6) }
  @objc func readerTextMenuAction7(_ sender: Any?) { owner?.emitMenuAction(index: 7) }

  static func selector(for index: Int) -> Selector {
    switch index {
    case 0: return #selector(readerTextMenuAction0(_:))
    case 1: return #selector(readerTextMenuAction1(_:))
    case 2: return #selector(readerTextMenuAction2(_:))
    case 3: return #selector(readerTextMenuAction3(_:))
    case 4: return #selector(readerTextMenuAction4(_:))
    case 5: return #selector(readerTextMenuAction5(_:))
    case 6: return #selector(readerTextMenuAction6(_:))
    default: return #selector(readerTextMenuAction7(_:))
    }
  }

  static func index(for selector: Selector) -> Int? {
    switch selector {
    case #selector(readerTextMenuAction0(_:)): return 0
    case #selector(readerTextMenuAction1(_:)): return 1
    case #selector(readerTextMenuAction2(_:)): return 2
    case #selector(readerTextMenuAction3(_:)): return 3
    case #selector(readerTextMenuAction4(_:)): return 4
    case #selector(readerTextMenuAction5(_:)): return 5
    case #selector(readerTextMenuAction6(_:)): return 6
    case #selector(readerTextMenuAction7(_:)): return 7
    default: return nil
    }
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
  let alpha = hasAlpha ? CGFloat((int & 0xFF000000) >> 24) / 255 : 1
  let red = CGFloat((int & 0xFF0000) >> 16) / 255
  let green = CGFloat((int & 0x00FF00) >> 8) / 255
  let blue = CGFloat(int & 0x0000FF) / 255
  return UIColor(red: red, green: green, blue: blue, alpha: alpha)
}
