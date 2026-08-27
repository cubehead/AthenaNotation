package io.github.cubehead.athenanotation

import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.toPixelMap
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import java.io.FileOutputStream
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NotationComposeInstrumentedTest {
    @get:Rule
    val compose = createAndroidComposeRule<MainActivity>()

    @Test
    fun composeCanvasDrawsNotationAndExportsScreenshot() {
        compose.onNodeWithTag("swift-status").assertExists()
        val image = compose.onNodeWithTag("notation-canvas").captureToImage()
        val pixels = image.toPixelMap()
        var darkPixels = 0
        var bluePixels = 0
        for (y in 0 until pixels.height) {
            for (x in 0 until pixels.width) {
                val color = pixels[x, y]
                if (color.red < 0.35f && color.green < 0.35f && color.blue < 0.35f) darkPixels++
                if (color.blue > color.red + 0.08f && color.blue > color.green + 0.04f) bluePixels++
            }
        }
        assertTrue("Expected engraved black pixels", darkPixels > 1_000)
        assertTrue("Expected playback highlight pixels", bluePixels > 50)

        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val capture = File(context.getExternalFilesDir(null), "athena-notation.png")
        FileOutputStream(capture).use { output ->
            image.asAndroidBitmap().compress(Bitmap.CompressFormat.PNG, 100, output)
        }
        assertTrue(capture.exists() && capture.length() > 1_000)
    }
}
