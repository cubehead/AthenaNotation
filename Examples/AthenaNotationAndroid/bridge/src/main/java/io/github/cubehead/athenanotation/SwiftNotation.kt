package io.github.cubehead.athenanotation

class SwiftNotation {
    external fun healthCheck(): String
    external fun renderMusicXML(musicXML: String): String
    external fun renderMusicXMLWithCursorVisibility(
        musicXML: String,
        showsPlaybackCursor: Boolean,
    ): String
    external fun renderMusicXMLAtEvent(musicXML: String, eventID: String): String
    external fun renderMusicXMLAtEventWithCursorVisibility(
        musicXML: String,
        eventID: String,
        showsPlaybackCursor: Boolean,
    ): String
    external fun renderMIDI(midiData: ByteArray): String
    external fun resolveABStep(
        position: Double,
        duration: Double,
        elapsedSeconds: Double,
        beatsPerMinute: Double,
        loopStart: Double,
        loopEnd: Double,
        countInOnLoop: Boolean,
    ): String
    external fun countInDuration(beats: Int, beatType: Int, beatsPerMinute: Double): Double
    external fun countInBeat(
        remainingSeconds: Double,
        beats: Int,
        beatType: Int,
        beatsPerMinute: Double,
    ): Int

    companion object {
        init {
            // Swift 6.3's FoundationXML Android binary omits its zlib dependency.
            // This app-local, DF_1_GLOBAL bootstrap exports zlib before Swift loads.
            System.loadLibrary("AthenaZlib")
            System.loadLibrary("AthenaNotationAndroidBridge")
        }
    }
}
