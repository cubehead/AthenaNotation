package io.github.cubehead.athenanotation.compose

import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.Typeface
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.min
import kotlin.math.roundToInt

/** Semantic colors used when executing an AthenaNotation display list. */
data class AthenaNotationColors(
    val background: Int,
    val foreground: Int,
    val playbackHighlight: Int,
) {
    companion object {
        val Light = AthenaNotationColors(
            background = Color.WHITE,
            foreground = Color.BLACK,
            playbackHighlight = Color.argb(51, 0, 122, 255),
        )

        val Dark = AthenaNotationColors(
            background = Color.rgb(14, 18, 26),
            foreground = Color.rgb(232, 237, 245),
            playbackHighlight = Color.argb(77, 59, 130, 246),
        )

        fun forDarkTheme(darkTheme: Boolean): AthenaNotationColors =
            if (darkTheme) Dark else Light
    }
}

/** Executes the JSON display list produced by AndroidScoreRenderer. */
@Composable
fun AthenaNotationCanvas(
    sceneJSON: String,
    bravuraTypeface: Typeface,
    modifier: Modifier = Modifier,
    darkTheme: Boolean = isSystemInDarkTheme(),
    colors: AthenaNotationColors = AthenaNotationColors.forDarkTheme(darkTheme),
    touchEnabled: Boolean = true,
    onEventTap: ((String) -> Unit)? = null,
) {
    val scene = remember(sceneJSON) { NotationScene.parse(sceneJSON) }
    NotationSceneCanvas(
        scene = scene,
        bravuraTypeface = bravuraTypeface,
        modifier = modifier,
        fitWidth = false,
        colors = colors,
        touchEnabled = touchEnabled,
        onEventTap = onEventTap,
    )
}

/**
 * A reusable notation viewport that never shrinks the score to satisfy a short height.
 *
 * The display list is fitted to the available width and keeps its aspect-ratio height.
 * If that height (or [minimumSystemHeight] per system) exceeds the viewport, only this
 * notation area scrolls vertically.
 */
@Composable
fun ScrollableAthenaNotationCanvas(
    sceneJSON: String,
    bravuraTypeface: Typeface,
    systemCount: Int = 1,
    minimumSystemHeight: Dp = 310.dp,
    modifier: Modifier = Modifier,
    darkTheme: Boolean = isSystemInDarkTheme(),
    colors: AthenaNotationColors = AthenaNotationColors.forDarkTheme(darkTheme),
    touchEnabled: Boolean = true,
    onEventTap: ((String) -> Unit)? = null,
) {
    require(systemCount > 0) { "systemCount must be positive" }
    require(minimumSystemHeight > 0.dp) { "minimumSystemHeight must be positive" }
    val scene = remember(sceneJSON) { NotationScene.parse(sceneJSON) }
    val scrollState = rememberScrollState()
    val density = LocalDensity.current

    BoxWithConstraints(
        modifier = modifier.notationPointerInput(
            scene = scene,
            fitWidth = true,
            touchEnabled = touchEnabled,
            onEventTap = onEventTap,
            verticalScrollOffset = { scrollState.value.toFloat() },
        ),
    ) {
        val aspectHeight = maxWidth * (scene.height / scene.width)
        val contentHeight = maxOf(
            aspectHeight,
            minimumSystemHeight * systemCount.toFloat(),
        )
        val widthPixels = with(density) { maxWidth.toPx() }
        val viewportPixels = with(density) { maxHeight.toPx() }
        LaunchedEffect(scene.highlightedCenterY, widthPixels, viewportPixels) {
            val highlightedY = scene.highlightedCenterY ?: return@LaunchedEffect
            withFrameNanos { }
            val scale = widthPixels / scene.width
            val target = (highlightedY * scale - viewportPixels / 2f)
                .roundToInt()
                .coerceIn(0, scrollState.maxValue)
            scrollState.animateScrollTo(target)
        }
        Column(
            modifier = Modifier.verticalScroll(scrollState),
        ) {
            NotationSceneCanvas(
                scene = scene,
                bravuraTypeface = bravuraTypeface,
                modifier = Modifier.fillMaxWidth().height(contentHeight),
                fitWidth = true,
                colors = colors,
                touchEnabled = false,
                onEventTap = null,
            )
        }
    }
}

@Composable
private fun NotationSceneCanvas(
    scene: NotationScene,
    bravuraTypeface: Typeface,
    modifier: Modifier,
    fitWidth: Boolean,
    colors: AthenaNotationColors,
    touchEnabled: Boolean,
    onEventTap: ((String) -> Unit)?,
) {
    val interactionModifier = Modifier.notationPointerInput(
        scene = scene,
        fitWidth = fitWidth,
        touchEnabled = touchEnabled,
        onEventTap = onEventTap,
    )
    Box(modifier = modifier.then(interactionModifier)) {
        Canvas(modifier = Modifier.matchParentSize()) {
            val widthScale = size.width / scene.width
            val scale = if (fitWidth) widthScale else min(widthScale, size.height / scene.height)
            val offsetX = (size.width - scene.width * scale) / 2f
            val offsetY = if (fitWidth) 0f else (size.height - scene.height * scale) / 2f
            val canvas = drawContext.canvas.nativeCanvas
            canvas.save()
            canvas.translate(offsetX, offsetY)
            canvas.scale(scale, scale)

            scene.commands.forEach { command ->
                val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = command.resolvedColor(colors)
                    style = if (command.fill) Paint.Style.FILL else Paint.Style.STROKE
                    strokeWidth = command.lineWidth
                    strokeCap = if (command.role == "stem") Paint.Cap.BUTT else Paint.Cap.ROUND
                    strokeJoin = Paint.Join.ROUND
                }
                when (command.kind) {
                    "line" -> if (command.points.size >= 2) {
                        canvas.drawLine(
                            command.points[0].x, command.points[0].y,
                            command.points[1].x, command.points[1].y,
                            paint,
                        )
                    }
                    "rectangle" -> canvas.drawRect(
                        command.x, command.y,
                        command.x + command.width, command.y + command.height,
                        paint,
                    )
                    "ellipse" -> canvas.drawOval(
                        command.x, command.y,
                        command.x + command.width, command.y + command.height,
                        paint,
                    )
                    "polygon" -> if (command.points.isNotEmpty()) {
                        val path = Path().apply {
                            moveTo(command.points[0].x, command.points[0].y)
                            command.points.drop(1).forEach { lineTo(it.x, it.y) }
                            close()
                        }
                        canvas.drawPath(path, paint)
                    }
                    "path" -> canvas.drawPath(command.androidPath(), paint)
                    "glyph", "text" -> command.text?.let { value ->
                        paint.style = Paint.Style.FILL
                        paint.textSize = command.fontSize
                        paint.textAlign = Paint.Align.CENTER
                        if (command.kind == "glyph") paint.typeface = bravuraTypeface
                        val baseline = if (command.kind == "glyph") {
                            val inkBounds = Rect()
                            paint.getTextBounds(value, 0, value.length, inkBounds)
                            command.y - inkBounds.exactCenterY()
                        } else {
                            val metrics = paint.fontMetrics
                            command.y - (metrics.ascent + metrics.descent) / 2f
                        }
                        canvas.drawText(value, command.x, baseline, paint)
                    }
                }
            }
            canvas.restore()
        }
        Column(modifier = Modifier.matchParentSize()) {
            scene.accessibility.forEach { element ->
                Spacer(
                    modifier = Modifier
                        .size(1.dp)
                        .semantics { contentDescription = element.label },
                )
            }
        }
    }
}

private fun Modifier.notationPointerInput(
    scene: NotationScene,
    fitWidth: Boolean,
    touchEnabled: Boolean,
    onEventTap: ((String) -> Unit)?,
    verticalScrollOffset: () -> Float = { 0f },
): Modifier = pointerInput(scene, fitWidth, touchEnabled, onEventTap) {
        if (!touchEnabled || onEventTap == null) return@pointerInput
        awaitEachGesture {
            val down = awaitFirstDown(requireUnconsumed = false)
            val up = waitForUpOrCancellation() ?: return@awaitEachGesture
            val movement = up.position - down.position
            val distance = kotlin.math.sqrt(
                movement.x * movement.x + movement.y * movement.y
            )
            if (distance > viewConfiguration.touchSlop) return@awaitEachGesture
            val widthScale = size.width.toFloat() / scene.width
            val scale = if (fitWidth) {
                widthScale
            } else {
                min(widthScale, size.height.toFloat() / scene.height)
            }
            val offsetX = (size.width - scene.width * scale) / 2f
            val offsetY = if (fitWidth) 0f else (size.height - scene.height * scale) / 2f
            scene.eventAt(
                x = (up.position.x - offsetX) / scale,
                y = (up.position.y - offsetY + verticalScrollOffset()) / scale,
            )?.let(onEventTap)
        }
    }

private fun DrawCommand.resolvedColor(colors: AthenaNotationColors): Int = when {
    role == "background" -> colors.background
    role == "playbackHighlight" -> colors.playbackHighlight
    color.equals("#FF000000", ignoreCase = true) -> colors.foreground
    else -> Color.parseColor(color)
}

private data class Point(val x: Float, val y: Float)

private data class PathElement(val verb: String, val points: List<Point>)

private data class DrawCommand(
    val kind: String,
    val role: String,
    val eventID: String?,
    val color: String,
    val fill: Boolean,
    val lineWidth: Float,
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float,
    val points: List<Point>,
    val path: List<PathElement>,
    val text: String?,
    val fontSize: Float,
) {
    fun androidPath() = Path().apply {
        path.forEach { element ->
            when (element.verb) {
                "move" -> element.points.firstOrNull()?.let { moveTo(it.x, it.y) }
                "line" -> element.points.firstOrNull()?.let { lineTo(it.x, it.y) }
                "quadratic" -> if (element.points.size >= 2) {
                    quadTo(
                        element.points[0].x, element.points[0].y,
                        element.points[1].x, element.points[1].y,
                    )
                }
                "close" -> close()
            }
        }
    }
}

private data class NotationScene(
    val width: Float,
    val height: Float,
    val commands: List<DrawCommand>,
    val accessibility: List<AccessibilityElement>,
) {
    val highlightedCenterY: Float?
        get() = commands.firstOrNull { it.role == "playbackHighlight" }?.bounds()?.centerY

    fun eventAt(x: Float, y: Float): String? = commands
        .asSequence()
        .filter { it.eventID != null && it.role != "playbackHighlight" }
        .mapNotNull { command -> command.bounds()?.let { Triple(command.eventID!!, it, it.distanceTo(x, y)) } }
        .minByOrNull { (_, bounds, distance) -> distance + bounds.area * 0.0001f }
        ?.first

    companion object {
        fun parse(json: String): NotationScene {
            val root = JSONObject(json)
            return NotationScene(
                width = root.getDouble("width").toFloat(),
                height = root.getDouble("height").toFloat(),
                commands = root.getJSONArray("commands").objects().map { command ->
                    DrawCommand(
                        kind = command.getString("kind"),
                        role = command.getString("role"),
                        eventID = command.optString("eventID").takeIf {
                            command.has("eventID") && !command.isNull("eventID")
                        },
                        color = command.getString("color"),
                        fill = command.getBoolean("fill"),
                        lineWidth = command.getDouble("lineWidth").toFloat(),
                        x = command.optDouble("x", 0.0).toFloat(),
                        y = command.optDouble("y", 0.0).toFloat(),
                        width = command.optDouble("width", 0.0).toFloat(),
                        height = command.optDouble("height", 0.0).toFloat(),
                        points = command.getJSONArray("points").points(),
                        path = command.getJSONArray("path").objects().map { element ->
                            PathElement(
                                verb = element.getString("verb"),
                                points = element.getJSONArray("points").points(),
                            )
                        },
                        text = command.optString("text").takeIf { command.has("text") },
                        fontSize = command.optDouble("fontSize", 12.0).toFloat(),
                    )
                },
                accessibility = root.optJSONArray("accessibility")?.objects()?.map { element ->
                    AccessibilityElement(
                        eventID = element.getString("eventID"),
                        label = element.getString("label"),
                    )
                } ?: emptyList(),
            )
        }
    }
}

private data class Bounds(val left: Float, val top: Float, val right: Float, val bottom: Float) {
    val centerY: Float get() = (top + bottom) / 2f
    val area: Float get() = (right - left).coerceAtLeast(1f) * (bottom - top).coerceAtLeast(1f)
    fun expanded(value: Float) = Bounds(left - value, top - value, right + value, bottom + value)
    fun contains(x: Float, y: Float) = x in left..right && y in top..bottom
    fun distanceTo(x: Float, y: Float): Float {
        val dx = when { x < left -> left - x; x > right -> x - right; else -> 0f }
        val dy = when { y < top -> top - y; y > bottom -> y - bottom; else -> 0f }
        return kotlin.math.sqrt(dx * dx + dy * dy)
    }
}

private fun DrawCommand.bounds(): Bounds? {
    val coordinates = buildList {
        points.forEach { add(it) }
        path.forEach { addAll(it.points) }
    }
    if (coordinates.isNotEmpty()) {
        return Bounds(
            coordinates.minOf { it.x },
            coordinates.minOf { it.y },
            coordinates.maxOf { it.x },
            coordinates.maxOf { it.y },
        )
    }
    val halfText = if (kind == "glyph" || kind == "text") fontSize * 0.6f else 0f
    val halfHeight = if (kind == "glyph" || kind == "text") fontSize * 0.6f else 0f
    return Bounds(
        x - halfText,
        y - halfHeight,
        x + maxOf(width, halfText),
        y + maxOf(height, halfHeight),
    )
}

private data class AccessibilityElement(
    val eventID: String,
    val label: String,
)

private fun JSONArray.objects(): List<JSONObject> =
    (0 until length()).map { getJSONObject(it) }

private fun JSONArray.points(): List<Point> = objects().map {
    Point(it.getDouble("x").toFloat(), it.getDouble("y").toFloat())
}
