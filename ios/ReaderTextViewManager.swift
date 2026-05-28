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
  @objc public var menuItems: [[String: Any]] = [] {
    didSet {
      textView.menuItemCount = menuItems.count
      textView.installLegacyMenuItems()
    }
  }
  @objc public var highlights: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc public var ranges: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc public var typography: [[String: Any]] = [] { didSet { rebuildText() } }
  @objc public var baseDirection: String = "auto" { didSet { rebuildText() } }
  @objc public var textStyle: [String: Any] = [:] { didSet { rebuildText() } }
  @objc public var maxLineHeightMultiplier: NSNumber = 1 { didSet { rebuildText() } }
  @objc public var allowFontScaling: Bool = true { didSet { rebuildText() } }
  @objc public var clearSelectionSignal: NSNumber = 0 {
    didSet {
      if clearSelectionSignal.intValue != oldValue.intValue {
        clearSelection()
      }
    }
  }
  @objc public var onSelection: RCTDirectEventBlock?
  @objc public var onMenuAction: RCTDirectEventBlock?
  @objc public var onRangePress: RCTDirectEventBlock?
  @objc public var onContentSizeChange: RCTDirectEventBlock?
  @objc public weak var eventDelegate: ReaderTextViewEventDelegate?

  fileprivate let textView = ReaderUITextView()
  private static weak var activeSelectionOwner: ReaderTextView?
  private static let clearSelectionNotification = Notification.Name("dev.bilalahmad.readertext.clearSelection")
  private var normalizedRanges: [[String: Any]] = []
  private var lastReportedContentSize: CGSize = .zero
  private var lastNonEmptySelectedRange: NSRange?

  public override init(frame: CGRect) {
    super.init(frame: frame)
    setup()
  }

  public required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    textView.frame = bounds
    reportContentSizeIfNeeded()
  }

  fileprivate func emitMenuAction(index: Int) {
    guard index >= 0, index < menuItems.count else { return }
    let range = activeSelectedRange()
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
    clearSelection()
  }

  fileprivate func menuTitle(at index: Int) -> String {
    guard index >= 0, index < menuItems.count else { return "" }
    let item = menuItems[index]
    return item["title"] as? String ?? item["id"] as? String ?? ""
  }

  fileprivate func menuIdentifier(at index: Int) -> String {
    guard index >= 0, index < menuItems.count else { return "" }
    let item = menuItems[index]
    return item["id"] as? String ?? item["title"] as? String ?? ""
  }

  public func textViewDidChangeSelection(_ textView: UITextView) {
    let range = textView.selectedRange
    guard range.length > 0 else {
      if ReaderTextView.activeSelectionOwner === self {
        ReaderTextView.activeSelectionOwner = nil
      }
      lastNonEmptySelectedRange = nil
      return
    }
    let nsText = text as NSString
    guard range.location + range.length <= nsText.length else { return }
    ReaderTextView.activeSelectionOwner = self
    lastNonEmptySelectedRange = range
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

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleClearSelectionNotification),
      name: ReaderTextView.clearSelectionNotification,
      object: nil
    )
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
    textView.installLegacyMenuItems()
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
         let familyFont = font(named: family, size: currentFont.pointSize) {
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
      let markerText = (attributed.string as NSString).substring(with: markerRange)
      let attachment = markerAttachment(text: markerText, font: markerFont, style: style)
      attributed.replaceCharacters(
        in: NSRange(location: markerRange.location, length: 1),
        with: NSAttributedString(attachment: attachment)
      )

      if markerRange.length > 1 {
        attributed.addAttributes(
          [
            .font: markerFont.withSize(0.1),
            .foregroundColor: UIColor.clear,
            .kern: -markerFont.pointSize * 0.5,
          ],
          range: NSRange(location: markerRange.location + 1, length: markerRange.length - 1)
        )
      }
    }
  }

  private func typographyProfile(_ segment: [String: Any]) -> [String: Any] {
    var profile: [String: Any] = [:]
    if let lang = segment["lang"] as? String,
       let langProfile = typography.first(where: { $0["lang"] as? String == lang }) {
      profile.merge(langProfile) { _, segmentValue in segmentValue }
    }
    if let inlineProfile = segment["typography"] as? [String: Any] {
      profile.merge(inlineProfile) { _, segmentValue in segmentValue }
    }
    for key in ["fontFamily", "color", "fontScale", "baselineOffset", "lineHeightMultiplier"] {
      if let value = segment[key] {
        profile[key] = value
      }
    }
    return profile
  }

  private func baseFont() -> UIFont {
    let fontSize = number(textStyle["fontSize"]) ?? 17
    let family = textStyle["fontFamily"] as? String
    return family.flatMap { font(named: $0, size: fontSize) } ?? UIFont.systemFont(ofSize: fontSize)
  }

  private func font(named requestedName: String, size: CGFloat) -> UIFont? {
    if let font = UIFont(name: requestedName, size: size) {
      return font
    }

    let aliases = [
      "Roboto_300Light": ["Roboto-Light"],
      "Roboto_400Regular": ["Roboto-Regular"],
      "Roboto_400Regular_Italic": ["Roboto-Italic"],
      "Roboto_500Medium": ["Roboto-Medium"],
      "Roboto_700Bold": ["Roboto-Bold"],
      "Roboto_700Bold_Italic": ["Roboto-BoldItalic"],
      "Lateef_400Regular": ["Lateef-Regular", "Lateef"],
      "Lateef_500Medium": ["Lateef-Medium"],
      "Lateef_700Bold": ["Lateef-Bold"],
      "JameelNooriNastaleeq": ["JameelNooriNastaleeq", "Jameel Noori Nastaleeq"],
      "NooreHuda": ["noorehuda", "noorehuda Regular"],
      "EBGaramond_400Regular": ["EBGaramond-Regular"],
      "EBGaramond_400Regular_Italic": ["EBGaramond-Italic"],
      "EBGaramond_500Medium": ["EBGaramond-Medium"],
      "EBGaramond_600SemiBold": ["EBGaramond-SemiBold"],
      "EBGaramond_700Bold": ["EBGaramond-Bold"],
    ]

    if let resolvedNames = aliases[requestedName] {
      for resolvedName in resolvedNames {
        if let font = UIFont(name: resolvedName, size: size) {
          return font
        }
      }
    }

    return nil
  }

  private func markerVisualRange(_ markerRange: NSRange, in string: NSString) -> NSRange {
    var location = markerRange.location
    var length = markerRange.length

    if location > 0, isMarkerPaddingCharacter(string.character(at: location - 1)) {
      location -= 1
      length += 1
    }

    let upperBound = location + length
    if upperBound < string.length, isMarkerPaddingCharacter(string.character(at: upperBound)) {
      length += 1
    }

    return NSRange(location: location, length: length)
  }

  private func isMarkerPaddingCharacter(_ character: unichar) -> Bool {
    switch character {
    case 0x0020, 0x00A0, 0x2000, 0x2001, 0x2002, 0x2003, 0x2004, 0x2005,
         0x2006, 0x2007, 0x2008, 0x2009, 0x200A, 0x202F, 0x205F, 0x3000:
      return true
    default:
      return false
    }
  }

  private func rangeDictionary(_ dictionary: [String: Any], contains offset: Int) -> Bool {
    guard let start = dictionary["start"] as? Int, let end = dictionary["end"] as? Int else { return false }
    if offset >= start && offset < end {
      return true
    }
    guard dictionary["presentation"] as? String == "marker" else { return false }
    let visualRange = markerVisualRange(NSRange(location: start, length: end - start), in: text as NSString)
    return offset >= visualRange.location && offset < visualRange.location + visualRange.length
  }

  private func markerAttachment(text: String, font: UIFont, style: [String: Any]) -> NSTextAttachment {
    let horizontalPadding = number(style["horizontalPadding"]) ?? 4
    let verticalPadding = number(style["verticalPadding"]) ?? 1
    let borderRadius = number(style["borderRadius"]) ?? 3
    let textColor = color(style["textColor"]) ?? UIColor(red: 0.302, green: 0.22, blue: 0.153, alpha: 1)
    let backgroundColor = color(style["backgroundColor"]) ?? UIColor(red: 0.957, green: 0.937, blue: 0.906, alpha: 1)
    let textSize = (text as NSString).size(withAttributes: [.font: font])
    let width = max(number(style["minWidth"]) ?? 0, ceil(textSize.width + horizontalPadding * 2))
    let height = max(number(style["minHeight"]) ?? 0, ceil(textSize.height + verticalPadding * 2))
    let size = CGSize(width: width, height: height)

    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { _ in
      let rect = CGRect(origin: .zero, size: size)
      backgroundColor.setFill()
      UIBezierPath(roundedRect: rect, cornerRadius: borderRadius).fill()

      let textRect = CGRect(
        x: floor((width - textSize.width) / 2),
        y: floor((height - textSize.height) / 2),
        width: ceil(textSize.width),
        height: ceil(textSize.height)
      )
      (text as NSString).draw(in: textRect, withAttributes: [
        .font: font,
        .foregroundColor: textColor,
      ])
    }

    let attachment = NSTextAttachment()
    attachment.image = image.withRenderingMode(.alwaysOriginal)
    attachment.bounds = CGRect(
      x: 0,
      y: (font.capHeight - height) / 2,
      width: width,
      height: height
    )
    return attachment
  }

  private func scaledFont(_ font: UIFont) -> UIFont {
    guard allowFontScaling else { return font }
    return UIFontMetrics.default.scaledFont(for: font)
  }

  @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
    guard gesture.state == .ended else { return }
    if let owner = ReaderTextView.activeSelectionOwner, owner !== self {
      owner.clearSelection()
    }
    if textView.selectedRange.length > 0 {
      clearSelection()
      return
    }
    guard !normalizedRanges.isEmpty else { return }
    let point = gesture.location(in: textView)
    guard let offset = characterOffset(at: point) else { return }
    guard let range = normalizedRanges.first(where: {
      rangeDictionary($0, contains: offset)
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

  @objc private func handleClearSelectionNotification() {
    clearSelection()
  }

  private func activeSelectedRange() -> NSRange {
    let current = textView.selectedRange
    if current.length > 0 {
      return current
    }
    return lastNonEmptySelectedRange ?? current
  }

  private func clearSelection() {
    let selectedRange = textView.selectedRange
    let collapseLocation: Int
    if selectedRange.location != NSNotFound {
      collapseLocation = selectedRange.location
    } else if let cached = lastNonEmptySelectedRange {
      collapseLocation = cached.location
    } else {
      collapseLocation = 0
    }
    let textLength = (text as NSString).length
    let boundedLocation = max(0, min(collapseLocation, textLength))
    textView.selectedRange = NSRange(location: boundedLocation, length: 0)
    textView.resignFirstResponder()
    lastNonEmptySelectedRange = nil
    if ReaderTextView.activeSelectionOwner === self {
      ReaderTextView.activeSelectionOwner = nil
    }
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
  private static var didInstallEditMenuSwizzle = false

  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)
    Self.installEditMenuSwizzleOnce()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    Self.installEditMenuSwizzleOnce()
  }

  override func buildMenu(with builder: any UIMenuBuilder) {
    super.buildMenu(with: builder)
    guard menuItemCount > 0 else { return }

    if #available(iOS 17.0, *) {
      builder.remove(menu: .autoFill)
      builder.remove(menu: .format)
      builder.remove(menu: .lookup)
      builder.remove(menu: .replace)
      builder.remove(menu: .share)
      builder.remove(menu: .spelling)
      builder.remove(menu: .substitutions)
      builder.remove(menu: .transformations)
      builder.remove(menu: .speech)
      builder.remove(menu: .learn)
    }
  }

  override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
    if let index = Self.legacyMenuIndex(for: action) {
      return index < menuItemCount && selectedRange.length > 0
    }

    if action == #selector(copy(_:)) {
      return super.canPerformAction(action, withSender: sender)
    }

    return super.canPerformAction(action, withSender: sender)
  }

  fileprivate func installLegacyMenuItems() {
    guard menuItemCount > 0 else { return }
    UIMenuController.shared.menuItems = (0..<min(menuItemCount, 8)).map { index in
      UIMenuItem(title: owner?.menuTitle(at: index) ?? "", action: Self.legacyMenuSelector(for: index))
    }
  }

  @objc func readerTextMenuAction0(_ sender: Any?) { owner?.emitMenuAction(index: 0) }
  @objc func readerTextMenuAction1(_ sender: Any?) { owner?.emitMenuAction(index: 1) }
  @objc func readerTextMenuAction2(_ sender: Any?) { owner?.emitMenuAction(index: 2) }
  @objc func readerTextMenuAction3(_ sender: Any?) { owner?.emitMenuAction(index: 3) }
  @objc func readerTextMenuAction4(_ sender: Any?) { owner?.emitMenuAction(index: 4) }
  @objc func readerTextMenuAction5(_ sender: Any?) { owner?.emitMenuAction(index: 5) }
  @objc func readerTextMenuAction6(_ sender: Any?) { owner?.emitMenuAction(index: 6) }
  @objc func readerTextMenuAction7(_ sender: Any?) { owner?.emitMenuAction(index: 7) }

  private static func installEditMenuSwizzleOnce() {
    guard !didInstallEditMenuSwizzle else { return }
    didInstallEditMenuSwizzle = true
    guard #available(iOS 16.0, *) else { return }

    let cls: AnyClass = UITextView.self
    let originalSel = NSSelectorFromString("editMenuInteraction:menuFor:suggestedActions:")
    let swizzledSel = #selector(UITextView.readerText_editMenuInteraction(_:menuFor:suggestedActions:))

    guard
      let originalMethod = class_getInstanceMethod(cls, originalSel),
      let swizzledMethod = class_getInstanceMethod(cls, swizzledSel)
    else { return }

    let didAdd = class_addMethod(
      cls,
      originalSel,
      method_getImplementation(swizzledMethod),
      method_getTypeEncoding(swizzledMethod)
    )

    if didAdd {
      class_replaceMethod(
        cls,
        swizzledSel,
        method_getImplementation(originalMethod),
        method_getTypeEncoding(originalMethod)
      )
    } else {
      method_exchangeImplementations(originalMethod, swizzledMethod)
    }
  }

  @available(iOS 16.0, *)
  fileprivate func readerTextMenu(suggestedActions: [UIMenuElement]) -> UIMenu {
    let actions = (0..<min(menuItemCount, 8)).map { index in
      UIAction(
        title: owner?.menuTitle(at: index) ?? "",
        image: Self.menuImage(for: owner?.menuIdentifier(at: index))
      ) { [weak self] _ in
        self?.owner?.emitMenuAction(index: index)
      }
    }

    return UIMenu(children: actions + Self.filteredSystemActions(suggestedActions))
  }

  @available(iOS 16.0, *)
  fileprivate static func filteredSystemActions(_ elements: [UIMenuElement]) -> [UIMenuElement] {
    elements.compactMap { element -> UIMenuElement? in
      if let menu = element as? UIMenu {
        let identifier = menu.identifier.rawValue.lowercased()
        let title = menu.title.lowercased()
        let blockedMenus = [
          "autofill", "fill",
          "format", "formatting",
          "lookup", "look up",
          "translate",
          "share",
          "replace",
        ]
        if blockedMenus.contains(where: { identifier.contains($0) || title == $0 }) {
          return nil
        }
        let children = filteredSystemActions(menu.children)
        return children.isEmpty ? nil : menu.replacingChildren(children)
      }

      if let action = element as? UIAction {
        return action.title.lowercased() == "copy" ? element : nil
      }

      if element is UIDeferredMenuElement {
        return nil
      }

      return nil
    }
  }

  fileprivate static func menuImage(for identifier: String?) -> UIImage? {
    switch identifier {
    case "highlight":
      return UIImage(systemName: "highlighter")
    case "note":
      return UIImage(systemName: "square.and.pencil")
    case "share":
      return UIImage(systemName: "square.and.arrow.up")
    default:
      return nil
    }
  }

  private static func legacyMenuSelector(for index: Int) -> Selector {
    switch index {
    case 0: return #selector(ReaderUITextView.readerTextMenuAction0(_:))
    case 1: return #selector(ReaderUITextView.readerTextMenuAction1(_:))
    case 2: return #selector(ReaderUITextView.readerTextMenuAction2(_:))
    case 3: return #selector(ReaderUITextView.readerTextMenuAction3(_:))
    case 4: return #selector(ReaderUITextView.readerTextMenuAction4(_:))
    case 5: return #selector(ReaderUITextView.readerTextMenuAction5(_:))
    case 6: return #selector(ReaderUITextView.readerTextMenuAction6(_:))
    default: return #selector(ReaderUITextView.readerTextMenuAction7(_:))
    }
  }

  private static func legacyMenuIndex(for selector: Selector) -> Int? {
    switch selector {
    case #selector(ReaderUITextView.readerTextMenuAction0(_:)): return 0
    case #selector(ReaderUITextView.readerTextMenuAction1(_:)): return 1
    case #selector(ReaderUITextView.readerTextMenuAction2(_:)): return 2
    case #selector(ReaderUITextView.readerTextMenuAction3(_:)): return 3
    case #selector(ReaderUITextView.readerTextMenuAction4(_:)): return 4
    case #selector(ReaderUITextView.readerTextMenuAction5(_:)): return 5
    case #selector(ReaderUITextView.readerTextMenuAction6(_:)): return 6
    case #selector(ReaderUITextView.readerTextMenuAction7(_:)): return 7
    default: return nil
    }
  }

}

extension UITextView {
  @available(iOS 16.0, *)
  @objc func readerText_editMenuInteraction(
    _ interaction: UIEditMenuInteraction,
    menuFor configuration: UIEditMenuConfiguration,
    suggestedActions: [UIMenuElement]
  ) -> UIMenu? {
    if let readerTextView = self as? ReaderUITextView, readerTextView.menuItemCount > 0 {
      return readerTextView.readerTextMenu(suggestedActions: suggestedActions)
    }

    return readerText_editMenuInteraction(
      interaction,
      menuFor: configuration,
      suggestedActions: suggestedActions
    )
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
