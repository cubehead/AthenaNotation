# MusicXML coverage

`MusicXMLImporter` accepts `score-partwise` documents and preserves the
following notation in the public semantic model:

- pitches, rests, chords, voices, staves, written durations, and up to three dots
- treble/bass clefs, key signatures, time signatures, backup, and forward
- fingerings, common articulations, ornaments, fermatas, techniques, lyrics,
  text directions, rehearsal text, dynamics, segno, and coda text
- ties, slurs, tuplets, glissandi/slides, hairpins, pedal ranges, and octave shifts
- regular/double/final barlines, repeat counts, alternate endings, and tempo maps

Common articulation and ornament names map to Bravura/SMuFL glyphs on Apple
and Android. Unknown modern attachments remain representable through open
SMuFL glyph, text, technique, accidental, and spanner raw values.

Import diagnostics provide a stable `code`, `severity`, message, and optional
measure number. Grace/zero-duration notes are currently reported and skipped
because the 1.0 event invariant requires positive performed duration.

The 1.0 importer reads the first MusicXML `<part>`. A piano grand staff should
normally be encoded as one part with multiple staves. Applications importing
orchestral scores should split or select parts before importing.

---

# MusicXML 覆盖范围

1.0 导入器支持 `score-partwise`，可保留音高、休止、和弦、多声部/多谱表、附点、
高低音谱号、调号、拍号、指法、常见奏法与装饰音、延长记号、歌词、文字、排练标记、
力度、速度变化、连音线、延音线、Tuplet、滑奏、渐强渐弱、踏板、八度线、重复、
Volta 和终止线。

诊断包含稳定 `code`、严重性、消息和可选小节号。当前语义模型要求演奏时值为正，
因此倚音/零时值音符会产生诊断并跳过。1.0 读取第一个 `<part>`；钢琴双谱表通常应
编码为一个包含多谱表的 part。
