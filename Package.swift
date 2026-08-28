// swift-tools-version: 6.0

import PackageDescription

var products: [Product] = [
  .library(name: "AthenaNotationCore", targets: ["AthenaNotationCore"]),
  .library(name: "AthenaNotationLayout", targets: ["AthenaNotationLayout"]),
  .library(name: "AthenaNotationRenderApple", targets: ["AthenaNotationRenderApple"]),
  .library(name: "AthenaNotationRenderAndroid", targets: ["AthenaNotationRenderAndroid"]),
  .library(name: "AthenaNotationRenderWindows", targets: ["AthenaNotationRenderWindows"]),
  .library(name: "AthenaMusicXML", targets: ["AthenaMusicXML"]),
  .library(name: "AthenaMIDI", targets: ["AthenaMIDI"]),
  .library(name: "AthenaScoreAnalysis", targets: ["AthenaScoreAnalysis"]),
  .executable(name: "AthenaNotationExample", targets: ["AthenaNotationExample"]),
  .executable(
    name: "AthenaNotationWindowsExample",
    targets: ["AthenaNotationWindowsExample"]
  ),
]

var targets: [Target] = [
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
      "AthenaScoreAnalysis",
    ],
    resources: [.process("Resources")]
  ),
  .target(
    name: "AthenaNotationRenderWindows",
    dependencies: ["AthenaNotationRenderAndroid"]
  ),
  .target(
    name: "AthenaNotationRenderAndroid",
    dependencies: [
      "AthenaNotationCore",
      "AthenaNotationLayout",
      "AthenaScoreAnalysis",
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
    name: "AthenaNotationWindowsExample",
    dependencies: [
      "AthenaNotationCore",
      "AthenaNotationRenderWindows",
      "AthenaScoreAnalysis",
      "AthenaMusicXML",
      "AthenaMIDI",
    ],
    path: "Examples/AthenaNotationWindows"
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
    ],
    exclude: ["__Snapshots__"]
  ),
  .testTarget(
    name: "AthenaNotationRenderWindowsTests",
    dependencies: [
      "AthenaNotationCore",
      "AthenaNotationRenderWindows",
    ]
  ),
  .testTarget(
    name: "AthenaScoreAnalysisTests",
    dependencies: ["AthenaScoreAnalysis"]
  ),
  .testTarget(name: "AthenaMusicXMLTests", dependencies: ["AthenaMusicXML"]),
  .testTarget(name: "AthenaMIDITests", dependencies: ["AthenaMIDI"]),
]

#if os(Windows)
  products.removeAll { product in
    product.name == "AthenaNotationRenderApple" || product.name == "AthenaNotationExample"
  }
  targets.removeAll { target in
    target.name == "AthenaNotationRenderApple"
      || target.name == "AthenaNotationExample"
      || target.name == "AthenaNotationTests"
  }
#endif

let umbrellaTargets =
  [
    "AthenaNotationCore",
    "AthenaNotationLayout",
    "AthenaScoreAnalysis",
    "AthenaMusicXML",
    "AthenaMIDI",
  ]
  + {
    #if os(Windows)
      ["AthenaNotationRenderWindows"]
    #else
      ["AthenaNotationRenderApple"]
    #endif
  }()

products.insert(
  .library(name: "AthenaNotation", targets: umbrellaTargets),
  at: 0
)

let package = Package(
  name: "AthenaNotation",
  platforms: [
    .iOS(.v17),
    .macOS(.v15),
  ],
  products: products,
  targets: targets
)
