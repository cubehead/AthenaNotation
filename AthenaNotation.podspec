Pod::Spec.new do |spec|
  spec.name = 'AthenaNotation'
  spec.version = '1.0.0'
  spec.summary = 'Native Swift music notation, MusicXML and MIDI for Apple platforms.'
  spec.description = <<-DESC
    AthenaNotation is a dependency-free Swift notation engine with a semantic
    score model, engraving layout, native SwiftUI renderer, score timeline
    analysis, MusicXML import and Standard MIDI File import.
  DESC
  spec.homepage = 'https://github.com/cubehead/AthenaNotation'
  spec.license = { :type => 'MIT', :file => 'LICENSE' }
  spec.author = { 'Athena Piano Contributors' => 'cubehead@users.noreply.github.com' }
  spec.source = {
    :git => 'https://github.com/cubehead/AthenaNotation.git',
    :tag => spec.version.to_s
  }

  spec.ios.deployment_target = '17.0'
  spec.osx.deployment_target = '15.0'
  spec.swift_version = '6.0'
  spec.source_files = 'Sources/**/*.swift'
  spec.exclude_files = 'Sources/AthenaNotationRenderWindows/**/*.swift'
  spec.frameworks = 'CoreText', 'Foundation', 'SwiftUI'
  spec.resource_bundles = {
    'AthenaNotationResources' => [
      'Sources/AthenaNotationRenderApple/Resources/Bravura.otf',
      'Sources/AthenaNotationRenderApple/Resources/Bravura.LICENSE.txt'
    ]
  }
end
