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
        val accessibility = scene.getJSONArray("accessibility")
        assertTrue(accessibility.length() > 0)
        assertTrue(accessibility.getJSONObject(0).getString("label").startsWith("Measure 1, beat 1"))
        assertTrue(accessibility.getJSONObject(0).has("eventID"))
    }

    @Test
    fun midiImportsAndRendersInsideAndroid() {
        val scene = JSONObject(bridge.renderMIDI(DemoFixtures.midi))
        assertFalse(scene.has("error"))
        assertTrue(scene.getJSONArray("commands").length() > 8)
    }

    @Test
    fun sharedABAndCountInSemanticsRunInsideAndroid() {
        val step = JSONObject(
            bridge.resolveABStep(0.49, 1.0, 0.2, 60.0, 0.25, 0.5, true)
        )
        assertEquals("looped", step.getString("reason"))
        assertEquals("beginCountIn", step.getString("action"))
        assertEquals(0.25, step.getDouble("position"), 0.000_001)
        assertEquals(4.0, bridge.countInDuration(4, 4, 60.0), 0.000_001)
        assertEquals(4, bridge.countInBeat(3.9, 4, 4, 60.0))
    }
}
