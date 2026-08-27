package io.github.cubehead.athenanotation.compose

import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Typeface
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.nativeCanvas
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.min

/** Executes the JSON display list produced by AndroidScoreRenderer. */
@Composable
fun AthenaNotationCanvas(
    sceneJSON: String,
    bravuraTypeface: Typeface,
    modifier: Modifier = Modifier,
) {
    val scene = remember(sceneJSON) { NotationScene.parse(sceneJSON) }
    Canvas(modifier = modifier) {
        val scale = min(size.width / scene.width, size.height / scene.height)
        val offsetX = (size.width - scene.width * scale) / 2f
        val offsetY = (size.height - scene.height * scale) / 2f
        val canvas = drawContext.canvas.nativeCanvas
        canvas.save()
        canvas.translate(offsetX, offsetY)
        canvas.scale(scale, scale)

        scene.commands.forEach { command ->
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor(command.color)
                style = if (command.fill) Paint.Style.FILL else Paint.Style.STROKE
                strokeWidth = command.lineWidth
                strokeCap = Paint.Cap.ROUND
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
                    val metrics = paint.fontMetrics
                    val baseline = command.y - (metrics.ascent + metrics.descent) / 2f
                    canvas.drawText(value, command.x, baseline, paint)
                }
            }
        }
        canvas.restore()
    }
}

private data class Point(val x: Float, val y: Float)

private data class PathElement(val verb: String, val points: List<Point>)

private data class DrawCommand(
    val kind: String,
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
) {
    companion object {
        fun parse(json: String): NotationScene {
            val root = JSONObject(json)
            return NotationScene(
                width = root.getDouble("width").toFloat(),
                height = root.getDouble("height").toFloat(),
                commands = root.getJSONArray("commands").objects().map { command ->
                    DrawCommand(
                        kind = command.getString("kind"),
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
            )
        }
    }
}

private fun JSONArray.objects(): List<JSONObject> =
    (0 until length()).map { getJSONObject(it) }

private fun JSONArray.points(): List<Point> = objects().map {
    Point(it.getDouble("x").toFloat(), it.getDouble("y").toFloat())
}

