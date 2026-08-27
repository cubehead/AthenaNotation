package io.github.cubehead.athenanotation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.core.content.res.ResourcesCompat
import io.github.cubehead.athenanotation.compose.AthenaNotationCanvas
import io.github.cubehead.athenanotation.bridge.R as BridgeR

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val bridge = remember { SwiftNotation() }
            val sceneJSON = remember { bridge.renderMusicXML(DemoFixtures.musicXML) }
            val bravura = remember { ResourcesCompat.getFont(this, BridgeR.font.bravura)!! }

            Box(modifier = Modifier.fillMaxSize()) {
                AthenaNotationCanvas(
                    sceneJSON = sceneJSON,
                    bravuraTypeface = bravura,
                    modifier = Modifier.fillMaxSize().testTag("notation-canvas"),
                )
                Text(
                    text = bridge.healthCheck(),
                    modifier = Modifier.testTag("swift-status"),
                )
            }
        }
    }
}
