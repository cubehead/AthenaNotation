import AthenaNotationRenderAndroid

/// Platform-neutral drawing output intended for a Windows canvas adapter.
///
/// The initial Windows port shares the deterministic display-list wire model
/// with Android. These aliases keep the Windows-facing API platform-named while
/// preserving one serializer and one engraving implementation.
public typealias WindowsRenderScene = AndroidRenderScene
public typealias WindowsAccessibilityElement = AndroidAccessibilityElement
public typealias WindowsRenderSystem = AndroidRenderSystem
public typealias WindowsRenderSceneError = AndroidRenderSceneError
public typealias WindowsRenderPoint = AndroidRenderPoint
public typealias WindowsPathVerb = AndroidPathVerb
public typealias WindowsPathElement = AndroidPathElement
public typealias WindowsRenderCommandKind = AndroidRenderCommandKind
public typealias WindowsRenderCommand = AndroidRenderCommand
public typealias WindowsScoreRenderer = AndroidScoreRenderer
public typealias WindowsRenderBridge = AndroidRenderBridge
