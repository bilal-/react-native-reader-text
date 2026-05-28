package dev.bilalahmad.readertext

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Selection
import android.text.Spannable
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import android.text.style.BackgroundColorSpan
import android.text.style.ForegroundColorSpan
import android.text.style.MetricAffectingSpan
import android.text.style.RelativeSizeSpan
import android.text.style.ReplacementSpan
import android.util.TypedValue
import android.view.ActionMode
import android.view.Gravity
import android.view.Menu
import android.view.MenuItem
import android.view.MotionEvent
import android.view.View
import android.widget.TextView
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.ReadableType
import com.facebook.react.bridge.WritableMap
import com.facebook.react.common.ReactConstants
import com.facebook.react.common.assets.ReactFontManager
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.ViewManagerDelegate
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.events.RCTEventEmitter
import com.facebook.react.viewmanagers.ReaderTextViewManagerDelegate
import com.facebook.react.viewmanagers.ReaderTextViewManagerInterface
import kotlin.math.max
import kotlin.math.roundToInt

private const val MENU_BASE_ID = 7300

class ReaderTextViewManager : SimpleViewManager<ReaderTextView>(),
  ReaderTextViewManagerInterface<ReaderTextView> {
  private val delegate: ViewManagerDelegate<ReaderTextView> = ReaderTextViewManagerDelegate(this)

  override fun getName(): String = "ReaderTextView"

  override fun getDelegate(): ViewManagerDelegate<ReaderTextView> = delegate

  override fun createViewInstance(reactContext: ThemedReactContext): ReaderTextView =
    ReaderTextView(reactContext)

  @ReactProp(name = "text")
  override fun setText(view: ReaderTextView, text: String?) {
    view.readerText = text.orEmpty()
  }

  @ReactProp(name = "segments")
  override fun setSegments(view: ReaderTextView, segments: ReadableArray?) {
    view.segments = segments
  }

  @ReactProp(name = "selectable", defaultBoolean = true)
  override fun setSelectable(view: ReaderTextView, selectable: Boolean) {
    view.readerSelectable = selectable
  }

  @ReactProp(name = "menuItems")
  override fun setMenuItems(view: ReaderTextView, menuItems: ReadableArray?) {
    view.menuItems = menuItems
  }

  @ReactProp(name = "highlights")
  override fun setHighlights(view: ReaderTextView, highlights: ReadableArray?) {
    view.highlights = highlights
  }

  @ReactProp(name = "ranges")
  override fun setRanges(view: ReaderTextView, ranges: ReadableArray?) {
    view.ranges = ranges
  }

  @ReactProp(name = "typography")
  override fun setTypography(view: ReaderTextView, typography: ReadableArray?) {
    view.typography = typography
  }

  @ReactProp(name = "baseDirection")
  override fun setBaseDirection(view: ReaderTextView, baseDirection: String?) {
    view.baseDirection = baseDirection ?: "auto"
  }

  @ReactProp(name = "textStyle")
  override fun setTextStyle(view: ReaderTextView, textStyle: ReadableMap?) {
    view.textStyle = textStyle
  }

  @ReactProp(name = "maxLineHeightMultiplier", defaultDouble = 1.0)
  override fun setMaxLineHeightMultiplier(view: ReaderTextView, multiplier: Double) {
    view.maxLineHeightMultiplier = multiplier.toFloat()
  }

  @ReactProp(name = "allowFontScaling", defaultBoolean = true)
  override fun setAllowFontScaling(view: ReaderTextView, allowFontScaling: Boolean) {
    view.allowReaderFontScaling = allowFontScaling
  }

  @ReactProp(name = "clearSelectionSignal", defaultInt = 0)
  override fun setClearSelectionSignal(view: ReaderTextView, signal: Int) {
    view.clearSelectionSignal = signal
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    MapBuilder.builder<String, Any>()
      .put("onSelection", MapBuilder.of("registrationName", "onSelection"))
      .put("onMenuAction", MapBuilder.of("registrationName", "onMenuAction"))
      .put("onRangePress", MapBuilder.of("registrationName", "onRangePress"))
      .put("onContentSizeChange", MapBuilder.of("registrationName", "onContentSizeChange"))
      .build()
      .toMutableMap()
}

class ReaderTextView(context: ThemedReactContext) : TextView(context) {
  var readerText: String = ""
    set(value) {
      field = value
      rebuildText()
    }

  var segments: ReadableArray? = null
    set(value) {
      field = value
      rebuildText()
    }

  var highlights: ReadableArray? = null
    set(value) {
      field = value
      rebuildText()
    }

  var ranges: ReadableArray? = null
    set(value) {
      field = value
      rebuildText()
    }

  var typography: ReadableArray? = null
    set(value) {
      field = value
      rebuildText()
    }

  var menuItems: ReadableArray? = null
    set(value) {
      field = value
      installSelectionMenu()
    }

  var readerSelectable: Boolean = true
    set(value) {
      field = value
      setTextIsSelectable(value)
      installSelectionMenu()
    }

  var baseDirection: String = "auto"
    set(value) {
      field = value
      applyDirection()
    }

  var textStyle: ReadableMap? = null
    set(value) {
      field = value
      applyTextStyle()
      rebuildText()
    }

  var maxLineHeightMultiplier: Float = 1f
    set(value) {
      field = value
      applyTextStyle()
    }

  var allowReaderFontScaling: Boolean = true
    set(value) {
      field = value
      applyTextStyle()
      rebuildText()
    }

  var clearSelectionSignal: Int = 0
    set(value) {
      if (field != value) {
        field = value
        clearSelection()
      }
    }

  private var normalizedRanges: List<ReadableMap> = emptyList()
  private var lastContentWidth = -1
  private var lastContentHeight = -1

  init {
    includeFontPadding = false
    isClickable = true
    setTextIsSelectable(true)
    gravity = Gravity.START
    applyDirection()
    installSelectionMenu()
  }

  override fun onSelectionChanged(selStart: Int, selEnd: Int) {
    super.onSelectionChanged(selStart, selEnd)
    if (selStart >= 0 && selEnd > selStart && selEnd <= readerText.length) {
      emitSelection(selStart, selEnd)
    }
  }

  override fun onTouchEvent(event: MotionEvent): Boolean {
    val handled = super.onTouchEvent(event)
    if (event.action == MotionEvent.ACTION_UP && normalizedRanges.isNotEmpty()) {
      val range = markerRangeForTouch(event) ?: normalizedRanges.firstOrNull {
        val start = it.getInt("start")
        val end = it.getInt("end")
        val offset = offsetForTouch(event)
        offset >= start && offset < end
      }
      if (range != null) {
        emitRangePress(range)
      }
    }
    return handled
  }

  override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
    super.onLayout(changed, left, top, right, bottom)
    reportContentSizeIfNeeded()
  }

  private fun rebuildText() {
    normalizedRanges = ranges?.toMapList()?.filter { it.validRange(readerText.length) }.orEmpty()
    val builder = SpannableStringBuilder(readerText)

    applyHighlightSpans(builder)
    applySegmentSpans(builder)
    applyMarkerSpans(builder)
    text = builder
    highlightColor = Color.argb(96, 154, 132, 85)
    post { reportContentSizeIfNeeded() }
  }

  private fun applyTextStyle() {
    val style = textStyle ?: return
    if (style.hasKey("fontSize") && !style.isNull("fontSize")) {
      val size = style.getDouble("fontSize").toFloat()
      setTextSize(
        if (allowReaderFontScaling) TypedValue.COMPLEX_UNIT_SP else TypedValue.COMPLEX_UNIT_DIP,
        size,
      )
    }
    if (style.hasKey("color") && !style.isNull("color")) {
      parseColor(style.getDynamic("color").asString())?.let { setTextColor(it) }
    }
    if (style.hasKey("lineHeight") && !style.isNull("lineHeight")) {
      val lineHeight = TypedValue.applyDimension(
        if (allowReaderFontScaling) TypedValue.COMPLEX_UNIT_SP else TypedValue.COMPLEX_UNIT_DIP,
        style.getDouble("lineHeight").toFloat(),
        resources.displayMetrics,
      )
      setLineSpacing(0f, lineHeight / max(textSize, 1f))
    } else {
      setLineSpacing(0f, max(maxLineHeightMultiplier, 1f))
    }
    if (style.hasKey("fontFamily") && !style.isNull("fontFamily")) {
      typeface = resolveTypeface(style.getString("fontFamily"), Typeface.NORMAL, ReactConstants.UNSET)
    }
    if (style.hasKey("textAlign") && !style.isNull("textAlign")) {
      gravity = when (style.getString("textAlign")) {
        "right" -> Gravity.RIGHT
        "center" -> Gravity.CENTER_HORIZONTAL
        else -> Gravity.LEFT
      }
    }
    post { reportContentSizeIfNeeded() }
  }

  private fun reportContentSizeIfNeeded() {
    val textLayout = layout ?: return
    if (textLayout.lineCount <= 0) return
    val contentWidth = max(width - compoundPaddingLeft - compoundPaddingRight, 0)
    if (contentWidth < 40) return
    val contentHeight = textLayout.getLineBottom(textLayout.lineCount - 1) + compoundPaddingTop + compoundPaddingBottom
    if (contentWidth == lastContentWidth && contentHeight == lastContentHeight) return
    lastContentWidth = contentWidth
    lastContentHeight = contentHeight

    val density = resources.displayMetrics.density.toDouble()
    val event = Arguments.createMap().apply {
      putDouble("width", contentWidth.toDouble() / density)
      putDouble("height", contentHeight.toDouble() / density)
    }
    (context as? ReactContext)
      ?.getJSModule(RCTEventEmitter::class.java)
      ?.receiveEvent(id, "onContentSizeChange", event)
  }

  private fun applyDirection() {
    textDirection = when (baseDirection) {
      "ltr" -> View.TEXT_DIRECTION_LTR
      "rtl" -> View.TEXT_DIRECTION_RTL
      else -> View.TEXT_DIRECTION_FIRST_STRONG
    }
    layoutDirection = when (baseDirection) {
      "rtl" -> View.LAYOUT_DIRECTION_RTL
      "ltr" -> View.LAYOUT_DIRECTION_LTR
      else -> View.LAYOUT_DIRECTION_LOCALE
    }
    textAlignment = View.TEXT_ALIGNMENT_GRAVITY
  }

  private fun applyHighlightSpans(builder: SpannableStringBuilder) {
    highlights?.toMapList()
      ?.filter { it.validRange(readerText.length) }
      ?.forEach { highlight ->
        val color = parseColor(highlight.optString("color") ?: "#FFE58A") ?: Color.parseColor("#FFE58A")
        builder.setSpan(
          BackgroundColorSpan(color),
          highlight.getInt("start"),
          highlight.getInt("end"),
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
  }

  private fun applySegmentSpans(builder: SpannableStringBuilder) {
    segments?.toMapList()?.forEach { segment ->
      if (!segment.validRange(readerText.length)) return@forEach
      val start = segment.getInt("start")
      val end = segment.getInt("end")
      val profile = segmentTypography(segment)

      profile.optDouble("fontScale")?.let {
        builder.setSpan(RelativeSizeSpan(it.toFloat()), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
      profile.optString("fontFamily")?.let {
        builder.setSpan(
          ReaderTypefaceSpan(resolveTypeface(it, Typeface.NORMAL, ReactConstants.UNSET)),
          start,
          end,
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
      profile.optString("color")?.let {
        parseColor(it)?.let { color ->
          builder.setSpan(ForegroundColorSpan(color), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
      }
      profile.optDouble("baselineOffset")?.let {
        builder.setSpan(DipBaselineShiftSpan(it.toFloat()), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    }
  }

  private fun applyMarkerSpans(builder: SpannableStringBuilder) {
    normalizedRanges
      .filter { it.optString("presentation") == "marker" }
      .forEach { range ->
        val start = range.getInt("start")
        val end = range.getInt("end")
        builder.setSpan(
          FootnoteMarkerSpan(
            style = range.optMap("markerStyle"),
            density = resources.displayMetrics.density,
          ),
          start,
          end,
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
  }

  private fun segmentTypography(segment: ReadableMap): ReadableMap {
    val profile = Arguments.createMap()
    val lang = segment.optString("lang")
    if (lang != null) {
      typography?.toMapList()?.firstOrNull { it.optString("lang") == lang }?.let { langProfile ->
        profile.merge(langProfile)
      }
    }
    if (segment.hasKey("typography") && !segment.isNull("typography")) {
      segment.getMap("typography")?.let { profile.merge(it) }
    }
    listOf("fontFamily", "color", "fontScale", "baselineOffset", "lineHeightMultiplier").forEach { key ->
      if (segment.hasKey(key) && !segment.isNull(key)) {
        when (segment.getType(key)) {
          ReadableType.String -> profile.putString(key, segment.getString(key))
          ReadableType.Number -> profile.putDouble(key, segment.getDouble(key))
          ReadableType.Boolean -> profile.putBoolean(key, segment.getBoolean(key))
          else -> Unit
        }
      }
    }
    return profile
  }

  private fun installSelectionMenu() {
    customSelectionActionModeCallback = object : ActionMode.Callback {
      override fun onCreateActionMode(mode: ActionMode, menu: Menu): Boolean {
        addCustomMenuItems(mode, menu)
        return true
      }

      override fun onPrepareActionMode(mode: ActionMode, menu: Menu): Boolean {
        addCustomMenuItems(mode, menu)
        return false
      }

      override fun onActionItemClicked(mode: ActionMode, item: MenuItem): Boolean {
        val index = item.itemId - MENU_BASE_ID
        val items = menuItems
        if (items != null && index >= 0 && index < items.size()) {
          val menuItem = items.getMap(index) ?: return false
          emitMenuAction(menuItem)
          mode.finish()
          return true
        }
        return false
      }

      override fun onDestroyActionMode(mode: ActionMode) = Unit
    }
  }

  private fun addCustomMenuItems(mode: ActionMode, menu: Menu) {
    val items = menuItems ?: return
    for (index in 0 until items.size()) {
      val item = items.getMap(index) ?: continue
      val title = item.optString("title") ?: continue
      val id = MENU_BASE_ID + index
      if (menu.findItem(id) == null) {
        menu.add(Menu.NONE, id, 100 + index, title)
          .setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS)
      }
    }
    mode.title = null
  }

  private fun emitSelection(start: Int, end: Int) {
    sendEvent("onSelection", selectionMap(start, end))
  }

  private fun emitMenuAction(item: ReadableMap) {
    val start = selectionStart
    val end = selectionEnd
    if (start < 0 || end <= start || end > readerText.length) return

    val event = Arguments.createMap()
    event.putString("id", item.optString("id") ?: item.optString("title") ?: "")
    event.putString("title", item.optString("title") ?: item.optString("id") ?: "")
    val selection = selectionMap(start, end)
    val anchor = anchorMap(start, end)
    event.putString("selectionText", selection.getString("text"))
    event.putInt("selectionStart", selection.getInt("start"))
    event.putInt("selectionEnd", selection.getInt("end"))
    event.putDouble("anchorX", anchor.getDouble("x"))
    event.putDouble("anchorY", anchor.getDouble("y"))
    event.putDouble("anchorWidth", anchor.getDouble("width"))
    event.putDouble("anchorHeight", anchor.getDouble("height"))
    sendEvent("onMenuAction", event)
    clearSelection()
  }

  private fun clearSelection() {
    val currentText = text
    if (currentText is Spannable) {
      val collapseAt = selectionStart.coerceIn(0, currentText.length)
      Selection.setSelection(currentText, collapseAt, collapseAt)
    }
    clearFocus()
  }

  private fun emitRangePress(range: ReadableMap) {
    val event = Arguments.createMap()
    event.putString("id", range.optString("id") ?: "")
    event.putInt("start", range.getInt("start"))
    event.putInt("end", range.getInt("end"))
    range.optString("type")?.let { event.putString("type", it) }
    sendEvent("onRangePress", event)
  }

  private fun selectionMap(start: Int, end: Int): WritableMap {
    val map = Arguments.createMap()
    map.putString("text", readerText.substring(start, end))
    map.putInt("start", start)
    map.putInt("end", end)
    return map
  }

  private fun anchorMap(start: Int, end: Int): WritableMap {
    val map = Arguments.createMap()
    val layout = layout
    if (layout == null) {
      map.putDouble("x", 0.0)
      map.putDouble("y", 0.0)
      map.putDouble("width", 0.0)
      map.putDouble("height", 0.0)
      return map
    }

    val density = resources.displayMetrics.density.toDouble()
    val loc = IntArray(2).also { getLocationInWindow(it) }
    val startLine = layout.getLineForOffset(start)
    val endLine = layout.getLineForOffset(end)
    val xStart = layout.getPrimaryHorizontal(start) + totalPaddingLeft
    val xEnd = layout.getPrimaryHorizontal(end) + totalPaddingLeft
    val yTop = layout.getLineTop(startLine) + totalPaddingTop
    val yBottom = layout.getLineBottom(endLine) + totalPaddingTop

    map.putDouble("x", (loc[0] + minOf(xStart, xEnd)) / density)
    map.putDouble("y", (loc[1] + yTop) / density)
    map.putDouble("width", kotlin.math.abs(xEnd - xStart).toDouble() / density)
    map.putDouble("height", (yBottom - yTop).toDouble() / density)
    return map
  }

  private fun offsetForTouch(event: MotionEvent): Int {
    val x = event.x.toInt() - totalPaddingLeft + scrollX
    val y = event.y.toInt() - totalPaddingTop + scrollY
    val line = layout?.getLineForVertical(y) ?: return -1
    return layout?.getOffsetForHorizontal(line, x.toFloat()) ?: -1
  }

  private fun markerRangeForTouch(event: MotionEvent): ReadableMap? {
    val textLayout = layout ?: return null
    val x = event.x - totalPaddingLeft + scrollX
    val y = event.y - totalPaddingTop + scrollY
    val horizontalSlop = 12f * resources.displayMetrics.density
    val verticalSlop = 36f * resources.displayMetrics.density

    return normalizedRanges
      .filter { it.optString("presentation") == "marker" }
      .firstOrNull { range ->
        val start = range.getInt("start")
        val end = range.getInt("end")
        if (start < 0 || end <= start || end > readerText.length) return@firstOrNull false

        val line = textLayout.getLineForOffset(start)
        val lineTop = textLayout.getLineTop(line).toFloat() - verticalSlop
        val lineBottom = textLayout.getLineBottom(line).toFloat() + verticalSlop
        if (y < lineTop || y > lineBottom) return@firstOrNull false

        val startX = textLayout.getPrimaryHorizontal(start)
        val endX = textLayout.getPrimaryHorizontal(end)
        val left = minOf(startX, endX) - horizontalSlop
        val right = maxOf(startX, endX) + horizontalSlop
        x >= left && x <= right
      }
  }

  private fun sendEvent(name: String, payload: WritableMap) {
    (context as ReactContext)
      .getJSModule(RCTEventEmitter::class.java)
      .receiveEvent(id, name, payload)
  }

  private fun resolveTypeface(fontFamily: String?, style: Int, weight: Int): Typeface {
    if (fontFamily.isNullOrBlank()) return Typeface.defaultFromStyle(style)
    return ReactFontManager.getInstance().getTypeface(fontFamily, style, weight, context.assets)
  }
}

private class ReaderTypefaceSpan(private val resolvedTypeface: Typeface) : MetricAffectingSpan() {
  override fun updateDrawState(tp: TextPaint) {
    apply(tp)
  }

  override fun updateMeasureState(tp: TextPaint) {
    apply(tp)
  }

  private fun apply(paint: Paint) {
    paint.typeface = resolvedTypeface
    paint.isSubpixelText = true
  }
}

private class DipBaselineShiftSpan(private val dip: Float) : MetricAffectingSpan() {
  override fun updateDrawState(tp: TextPaint) {
    tp.baselineShift += dip.roundToInt()
  }

  override fun updateMeasureState(tp: TextPaint) {
    tp.baselineShift += dip.roundToInt()
  }
}

private class FootnoteMarkerSpan(
  private val style: ReadableMap?,
  private val density: Float,
) : ReplacementSpan() {
  private val horizontalPadding = dp(styleDouble("horizontalPadding") ?: 4.0)
  private val verticalPadding = dp(styleDouble("verticalPadding") ?: 1.0)
  private val borderRadius = dp(styleDouble("borderRadius") ?: 4.0)
  private val minWidth = dp(styleDouble("minWidth") ?: 16.0)
  private val minHeight = dp(styleDouble("minHeight") ?: 16.0)
  private val baselineOffset = dp(styleDouble("baselineOffset") ?: 4.0)
  private val fontScale = (styleDouble("fontScale") ?: 0.72).toFloat()
  private val backgroundColor = parseColor(styleString("backgroundColor")) ?: Color.parseColor("#F4EFE7")
  private val borderColor = parseColor(styleString("borderColor")) ?: Color.parseColor("#D7C8B6")
  private val textColor = parseColor(styleString("textColor")) ?: Color.parseColor("#4D3827")

  override fun getSize(
    paint: Paint,
    text: CharSequence,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    val markerPaint = TextPaint(paint).apply { textSize *= fontScale }
    val width = maxOf(markerPaint.measureText(text, start, end) + horizontalPadding * 2, minWidth)
    val fontMetrics = markerPaint.fontMetricsInt
    val height = maxOf((fontMetrics.descent - fontMetrics.ascent).toFloat() + verticalPadding * 2, minHeight)

    if (fm != null) {
      val extraTop = (height - (paint.fontMetricsInt.descent - paint.fontMetricsInt.ascent)).coerceAtLeast(0f)
      fm.ascent = paint.fontMetricsInt.ascent - extraTop.roundToInt()
      fm.descent = paint.fontMetricsInt.descent
      fm.top = fm.ascent
      fm.bottom = fm.descent
    }

    return width.roundToInt()
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    val markerPaint = TextPaint(paint).apply {
      isAntiAlias = true
      textSize *= fontScale
    }
    val textWidth = markerPaint.measureText(text, start, end)
    val width = maxOf(textWidth + horizontalPadding * 2, minWidth)
    val textMetrics = markerPaint.fontMetrics
    val height = maxOf(textMetrics.descent - textMetrics.ascent + verticalPadding * 2, minHeight)
    val markerBaseline = y - baselineOffset
    val rectTop = markerBaseline + textMetrics.ascent - verticalPadding
    val rect = RectF(x, rectTop, x + width, rectTop + height)

    markerPaint.style = Paint.Style.FILL
    markerPaint.color = backgroundColor
    canvas.drawRoundRect(rect, borderRadius, borderRadius, markerPaint)

    markerPaint.style = Paint.Style.STROKE
    markerPaint.strokeWidth = maxOf(1f, density)
    markerPaint.color = borderColor
    canvas.drawRoundRect(rect, borderRadius, borderRadius, markerPaint)

    markerPaint.style = Paint.Style.FILL
    markerPaint.color = textColor
    val textX = x + (width - textWidth) / 2
    canvas.drawText(text, start, end, textX, markerBaseline, markerPaint)
  }

  private fun dp(value: Double): Float = (value * density).toFloat()

  private fun styleString(key: String): String? =
    if (style != null && style.hasKey(key) && !style.isNull(key)) style.getString(key) else null

  private fun styleDouble(key: String): Double? =
    if (style != null && style.hasKey(key) && !style.isNull(key)) style.getDouble(key) else null
}

private fun ReadableArray.toMapList(): List<ReadableMap> =
  (0 until size()).mapNotNull { getMap(it) }

private fun ReadableMap.validRange(textLength: Int): Boolean {
  if (!hasKey("start") || !hasKey("end")) return false
  val start = getInt("start")
  val end = getInt("end")
  return start >= 0 && end > start && end <= textLength
}

private fun ReadableMap.optString(key: String): String? =
  if (hasKey(key) && !isNull(key)) getString(key) else null

private fun ReadableMap.optDouble(key: String): Double? =
  if (hasKey(key) && !isNull(key)) getDouble(key) else null

private fun ReadableMap.optMap(key: String): ReadableMap? =
  if (hasKey(key) && !isNull(key)) getMap(key) else null

private fun parseColor(value: String?): Int? {
  if (value == null) return null

  val hex = value.trim().removePrefix("#")
  if ((hex.length == 6 || hex.length == 8) && hex.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }) {
    val int = hex.toLong(16)
    val hasAlpha = hex.length == 8
    val redShift = if (hasAlpha) 24 else 16
    val greenShift = if (hasAlpha) 16 else 8
    val blueShift = if (hasAlpha) 8 else 0
    val red = ((int shr redShift) and 0xFF).toInt()
    val green = ((int shr greenShift) and 0xFF).toInt()
    val blue = ((int shr blueShift) and 0xFF).toInt()
    val alpha = if (hasAlpha) (int and 0xFF).toInt() else 255
    return Color.argb(alpha, red, green, blue)
  }

  return try {
    Color.parseColor(value)
  } catch (_: IllegalArgumentException) {
    null
  }
}
