package io.github.cubehead.athenanotation

internal object DemoFixtures {
    val musicXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <score-partwise version="4.0">
          <part-list>
            <score-part id="P1"><part-name>Piano</part-name></score-part>
          </part-list>
          <part id="P1">
            <measure number="1">
              <attributes>
                <divisions>4</divisions>
                <key><fifths>0</fifths></key>
                <time><beats>4</beats><beat-type>4</beat-type></time>
                <staves>2</staves>
                <clef number="1"><sign>G</sign><line>2</line></clef>
                <clef number="2"><sign>F</sign><line>4</line></clef>
              </attributes>
              <note>
                <pitch><step>C</step><octave>5</octave></pitch>
                <duration>2</duration><voice>1</voice><type>eighth</type><staff>1</staff>
                <notations><technical><fingering>1</fingering></technical></notations>
              </note>
              <note>
                <pitch><step>D</step><octave>5</octave></pitch>
                <duration>2</duration><voice>1</voice><type>eighth</type><staff>1</staff>
              </note>
              <backup><duration>4</duration></backup>
              <note>
                <pitch><step>C</step><octave>3</octave></pitch>
                <duration>4</duration><voice>2</voice><type>quarter</type><staff>2</staff>
              </note>
              <barline location="right"><bar-style>light-heavy</bar-style></barline>
            </measure>
          </part>
        </score-partwise>
    """.trimIndent()

    val midi = byteArrayOf(
        0x4D, 0x54, 0x68, 0x64, 0, 0, 0, 6, 0, 0, 0, 1, 0x01, 0xE0.toByte(),
        0x4D, 0x54, 0x72, 0x6B, 0, 0, 0, 0x14,
        0, 0xFF.toByte(), 0x51, 3, 0x07, 0xA1.toByte(), 0x20,
        0, 0x90.toByte(), 60, 100,
        0x83.toByte(), 0x60, 0x80.toByte(), 60, 0,
        0, 0xFF.toByte(), 0x2F, 0,
    )
}
