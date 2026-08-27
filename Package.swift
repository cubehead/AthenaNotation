// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AthenaNotation",
  platforms: [
    .iOS(.v17),
    .macOS(.v15),
  ],
  products: [
    .library(
      name: "AthenaNotation",
      targets: [
        "AthenaNotationCore",
        "AthenaNotationLayout",
        "AthenaNotationRenderApple",
        "AthenaScoreAnalysis",
        "AthenaMusicXML",
        "AthenaMIDI",
      ]
    ),
    .library(name: "AthenaNotationCore", targets: ["AthenaNotationCore"]),
    .library(name: "AthenaNotationRenderApple", targets: ["AthenaNotationRenderApple"]),
    .library(name: "AthenaNotationRenderAndroid", targets: ["AthenaNotationRenderAndroid"]),
    .library(name: "AthenaMusicXML", targets: ["AthenaMusicXML"]),
    .library(name: "AthenaMIDI", targets: ["AthenaMIDI"]),
    .library(name: "AthenaScoreAnalysis", targets: ["AthenaScoreAnalysis"]),
    .executable(name: "AthenaNotationExample", targets: ["AthenaNotationExample"]),
  ],
  targets: [
    .target(name: "AthenaNotationCore"),
    .target(
      name: "AthenaNotationLayout",
      dependencies: ["AthenaNotationCore"]
    ),
    .target(
      name: "AthenaNotationRenderApple",
      dependencies: [
        "AthenaNotationCore",
        "AthenaNotationLayout",
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "AthenaNotationRenderAndroid",
      dependencies: [
        "AthenaNotationCore",
        "AthenaNotationLayout",
      ],
      resources: [.process("Resources")]
    ),
    .target(
      name: "AthenaScoreAnalysis",
      dependencies: ["AthenaNotationCore"]
    ),
    .target(
      name: "AthenaMusicXML",
      dependencies: ["AthenaNotationCore"]
    ),
    .target(
      name: "AthenaMIDI",
      dependencies: ["AthenaNotationCore"]
    ),
    .executableTarget(
      name: "AthenaNotationExample",
      dependencies: [
        "AthenaNotationCore",
        "AthenaNotationRenderApple",
        "AthenaMusicXML",
        "AthenaMIDI",
      ],
      path: "Examples/AthenaNotationExample",
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "AthenaNotationTests",
      dependencies: [
        "AthenaNotationCore",
        "AthenaNotationLayout",
        "AthenaNotationRenderApple",
      ]
    ),
    .testTarget(
      name: "AthenaNotationRenderAndroidTests",
      dependencies: [
        "AthenaNotationCore",
        "AthenaNotationRenderAndroid",
      ]
    ),
    .testTarget(
      name: "AthenaScoreAnalysisTests",
      dependencies: ["AthenaScoreAnalysis"]
    ),
    .testTarget(name: "AthenaMusicXMLTests", dependencies: ["AthenaMusicXML"]),
    .testTarget(name: "AthenaMIDITests", dependencies: ["AthenaMIDI"]),
  ]
)
