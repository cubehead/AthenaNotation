/// The exact note-on/note-off delta between two playback frames.
/// The platform-neutral delta is deterministic and reusable by playback consumers.
public struct PianoNoteTransition: Hashable, Sendable {
  public let noteOns: Set<UInt8>
  public let noteOffs: Set<UInt8>

  public init(noteOns: Set<UInt8>, noteOffs: Set<UInt8>) {
    self.noteOns = noteOns
    self.noteOffs = noteOffs
  }
}

public enum PianoNoteStatePlanner {
  public static func transition(
    from sounding: Set<UInt8>,
    to desired: Set<UInt8>
  ) -> PianoNoteTransition {
    PianoNoteTransition(
      noteOns: desired.subtracting(sounding),
      noteOffs: sounding.subtracting(desired)
    )
  }
}
