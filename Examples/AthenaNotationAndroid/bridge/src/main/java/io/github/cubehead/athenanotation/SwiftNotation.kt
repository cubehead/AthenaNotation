package io.github.cubehead.athenanotation

class SwiftNotation {
    external fun healthCheck(): String
    external fun renderMusicXMLFixture(): String
    external fun renderMIDIFixture(): String

    companion object {
        init {
            // Swift 6.3's FoundationXML Android binary omits its zlib dependency.
            // This app-local, DF_1_GLOBAL bootstrap exports zlib before Swift loads.
            System.loadLibrary("AthenaZlib")
            System.loadLibrary("AthenaNotationAndroidBridge")
        }
    }
}
