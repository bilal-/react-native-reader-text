package com.readertext

import android.graphics.Color
import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import android.text.style.BackgroundColorSpan
import android.text.style.MetricAffectingSpan
import android.text.style.RelativeSizeSpan
import android.text.style.TypefaceSpan
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
import com.facebook.react.bridge.WritableMap
import com.facebook.react.common.MapBuilder
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.uimanager.events.RCTEventEmitter
import kotlin.math.max
import kotlin.math.roundToInt

private const val MENU_BASE_ID = 7300

class ReaderTextViewManager : SimpleViewManager<ReaderTextView>() {
  override fun getName(): String = "ReaderTextView"

  override fun createViewInstance(reactContext: ThemedReactContext): ReaderTextView =
    ReaderTextView(reactContext)

  @ReactProp(name = "text")
  fun setText(view: ReaderTextView, text: String?) {
    view.readerText = text.orEmpty()
  }

  @ReactProp(name = "segments")
  fun setSegments(view: ReaderTextView, segments: ReadableArray?) {
    view.segments = segments
  }

  @ReactProp(name = "selectable", defaultBoolean = true)
  fun setSelectable(view: ReaderTextView, selectable: Boolean) {
    view.readerSelectable = selectable
  }

  @ReactProp(name = "menuItems")
  fun setMenuItems(view: ReaderTextView, menuItems: ReadableArray?) {
    view.menuItems = menuItems
  }

  @ReactProp(name = "highlights")
  fun setHighlights(view: ReaderTextView, highlights: ReadableArray?) {
    view.highlights = highlights
  }

  @ReactProp(name = "ranges")
  fun setRanges(view: ReaderTextView, ranges: ReadableArray?) {
    view.ranges = ranges
  }

  @ReactProp(name = "typography")
  fun setTypography(view: ReaderTextView, typography: ReadableMap?) {
    view.typography = typography
  }

  @ReactProp(name = "baseDirection")
  fun setBaseDirection(view: ReaderTextView, baseDirection: String?) {
    view.baseDirection = baseDirection ?: "auto"
  }

  @ReactProp(name = "textStyle")
  fun setTextStyle(view: ReaderTextView, textStyle: ReadableMap?) {
    view.textStyle = textStyle
  }

  @ReactProp(name = "maxLineHeightMultiplier", defaultFloat = 1f)
  fun setMaxLineHeightMultiplier(view: ReaderTextView, multiplier: Float) {
    view.maxLineHeightMultiplier = multiplier
  }

  @ReactProp(name = "allowFontScaling", defaultBoolean = true)
  fun setAllowFontScaling(view: ReaderTextView, allowFontScaling: Boolean) {
    view.allowReaderFontScaling = allowFontScaling
  }

  override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
    MapBuilder.builder<String, Any>()
      .put("onSelection", MapBuilder.of("registrationName", "onSelection"))
      .put("onMenuAction", MapBuilder.of("registrationName", "onMenuAction"))
      .put("onRangePress", MapBuilder.of("registrationName", "onRangePress"))
      .build()
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

  var typography: ReadableMap? = null
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

  private var normalizedRanges: List<ReadableMap> = emptyList()

  init {
    includeFontPadding = true
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
      val offset = offsetForTouch(event)
      val range = normalizedRanges.firstOrNull {
        val start = it.getInt("start")
        val end = it.getInt("end")
        offset >= start && offset < end
      }
      if (range != null && selectionStart == selectionEnd) {
        emitRangePress(range)
      }
    }
    return handled
  }

  private fun rebuildText() {
    normalizedRanges = ranges?.toMapList()?.filter { it.validRange(readerText.length) }.orEmpty()
    val builder = SpannableStringBuilder(readerText)

    applyHighlightSpans(builder)
    applySegmentSpans(builder)
    text = builder
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
      val lineHeight = style.getDouble("lineHeight").toFloat() * max(maxLineHeightMultiplier, 1f)
      setLineSpacing(0f, lineHeight / max(textSize, 1f))
    } else {
      setLineSpacing(0f, max(maxLineHeightMultiplier, 1f))
    }
    if (style.hasKey("fontFamily") && !style.isNull("fontFamily")) {
      typeface = Typeface.create(style.getString("fontFamily"), Typeface.NORMAL)
    }
    if (style.hasKey("textAlign") && !style.isNull("textAlign")) {
      gravity = when (style.getString("textAlign")) {
        "right" -> Gravity.END
        "center" -> Gravity.CENTER_HORIZONTAL
        else -> Gravity.START
      }
    }
  }

  private fun applyDirection() {
    textDirection = when (baseDirection) {
      "ltr" -> View.TEXT_DIRECTION_LTR
      "rtl" -> View.TEXT_DIRECTION_RTL
      else -> View.TEXT_DIRECTION_FIRST_STRONG
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
        builder.setSpan(TypefaceSpan(it), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
      profile.optDouble("baselineOffset")?.let {
        builder.setSpan(DipBaselineShiftSpan(it.toFloat()), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    }
  }

  private fun segmentTypography(segment: ReadableMap): ReadableMap {
    if (segment.hasKey("typography") && !segment.isNull("typography")) {
      return segment.getMap("typography") ?: Arguments.createMap()
    }
    val lang = segment.optString("lang") ?: return Arguments.createMap()
    return typography?.getMap(lang) ?: Arguments.createMap()
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
    event.putMap("selection", selectionMap(start, end))
    event.putMap("anchor", anchorMap(start, end))
    sendEvent("onMenuAction", event)
  }

  private fun emitRangePress(range: ReadableMap) {
    val event = Arguments.createMap()
    event.putString("id", range.optString("id") ?: "")
    event.putInt("start", range.getInt("start"))
    event.putInt("end", range.getInt("end"))
    range.optString("type")?.let { event.putString("type", it) }
    if (range.hasKey("metadata") && !range.isNull("metadata")) {
      event.putMap("metadata", range.getMap("metadata"))
    }
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

  private fun sendEvent(name: String, payload: WritableMap) {
    (context as ReactContext)
      .getJSModule(RCTEventEmitter::class.java)
      .receiveEvent(id, name, payload)
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
