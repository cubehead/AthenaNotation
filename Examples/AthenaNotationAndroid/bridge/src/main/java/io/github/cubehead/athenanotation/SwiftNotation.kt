package io.github.cubehead.athenanotation

class SwiftNotation {
    external fun healthCheck(): String
    external fun renderMusicXML(musicXML: String): String
    external fun renderMIDI(midiData: ByteArray): String

    companion object {
        init {
            // Swift 6.3's FoundationXML Android binary omits its zlib dependency.
            // This app-local, DF_1_GLOBAL bootstrap exports zlib before Swift loads.
            System.loadLibrary("AthenaZlib")
            System.loadLibrary("AthenaNotationAndroidBridge")
        }
    }
}
