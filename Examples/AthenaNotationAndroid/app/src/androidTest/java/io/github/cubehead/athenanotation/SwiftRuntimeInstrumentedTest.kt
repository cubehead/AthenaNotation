package io.github.cubehead.athenanotation

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SwiftRuntimeInstrumentedTest {
    private val bridge = SwiftNotation()

    @Test
    fun swiftBridgeLoadsOnAndroidRuntime() {
        assertEquals("AthenaNotation Swift Android bridge OK", bridge.healthCheck())
    }

    @Test
    fun musicXMLImportsAndRendersInsideAndroid() {
        val scene = JSONObject(bridge.renderMusicXML(DemoFixtures.musicXML))
        assertFalse(scene.has("error"))
        assertTrue(scene.getJSONArray("commands").length() > 20)
        val roles = scene.getJSONArray("commands").let { commands ->
            (0 until commands.length()).map { commands.getJSONObject(it).getString("role") }.toSet()
        }
        assertTrue("staffLine" in roles)
        assertTrue("notehead" in roles)
        assertTrue("beam" in roles)
        assertTrue("playbackHighlight" in roles)
        assertTrue("barline" in roles)
    }

    @Test
    fun midiImportsAndRendersInsideAndroid() {
        val scene = JSONObject(bridge.renderMIDI(DemoFixtures.midi))
        assertFalse(scene.has("error"))
        assertTrue(scene.getJSONArray("commands").length() > 8)
    }
}
