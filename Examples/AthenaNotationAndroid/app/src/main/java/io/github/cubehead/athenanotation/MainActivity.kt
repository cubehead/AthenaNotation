package io.github.cubehead.athenanotation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.core.content.res.ResourcesCompat
import io.github.cubehead.athenanotation.compose.ScrollableAthenaNotationCanvas
import io.github.cubehead.athenanotation.bridge.R as BridgeR

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val bridge = remember { SwiftNotation() }
            var sceneJSON by remember { mutableStateOf(bridge.renderMusicXML(DemoFixtures.musicXML)) }
            var touchEnabled by remember { mutableStateOf(true) }
            var showsPlaybackCursor by remember { mutableStateOf(true) }
            var selectedEventID by remember { mutableStateOf<String?>(null) }
            var eventStatus by remember { mutableStateOf("等待触摸事件") }
            val bravura = remember { ResourcesCompat.getFont(this, BridgeR.font.bravura)!! }

            Column(modifier = Modifier.fillMaxSize()) {
                Row(modifier = Modifier.fillMaxWidth().padding(8.dp)) {
                    Switch(
                        checked = touchEnabled,
                        onCheckedChange = { touchEnabled = it },
                        modifier = Modifier.testTag("touch-toggle"),
                    )
                    Switch(
                        checked = showsPlaybackCursor,
                        onCheckedChange = { visible ->
                            showsPlaybackCursor = visible
                            sceneJSON = selectedEventID?.let { eventID ->
                                bridge.renderMusicXMLAtEventWithCursorVisibility(
                                    DemoFixtures.musicXML,
                                    eventID,
                                    visible,
                                )
                            } ?: bridge.renderMusicXMLWithCursorVisibility(
                                DemoFixtures.musicXML,
                                visible,
                            )
                        },
                        modifier = Modifier.testTag("cursor-toggle"),
                    )
                    Text(eventStatus, modifier = Modifier.weight(1f).padding(8.dp).testTag("event-status"))
                    Button(
                        onClick = {
                            eventStatus = bridge.resolveABStep(
                                position = 0.49,
                                duration = 1.0,
                                elapsedSeconds = 0.2,
                                beatsPerMinute = 60.0,
                                loopStart = 0.25,
                                loopEnd = 0.5,
                                countInOnLoop = true,
                            )
                        },
                        modifier = Modifier.testTag("ab-demo"),
                    ) { Text("A–B 事件") }
                }
                ScrollableAthenaNotationCanvas(
                    sceneJSON = sceneJSON,
                    bravuraTypeface = bravura,
                    touchEnabled = touchEnabled,
                    onEventTap = { eventID ->
                        selectedEventID = eventID
                        eventStatus = "seeked: $eventID"
                        sceneJSON = bridge.renderMusicXMLAtEventWithCursorVisibility(
                            DemoFixtures.musicXML,
                            eventID,
                            showsPlaybackCursor,
                        )
                    },
                    modifier = Modifier.weight(1f).fillMaxWidth().testTag("notation-canvas"),
                )
                Text(
                    text = bridge.healthCheck(),
                    modifier = Modifier.testTag("swift-status"),
                )
            }
        }
    }
}
