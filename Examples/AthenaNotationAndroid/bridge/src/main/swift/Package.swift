// swift-tools-version: 6.3

import PackageDescription

let package = Package(
  name: "AthenaNotationAndroidBridge",
  products: [
    .library(
      name: "AthenaNotationAndroidBridge",
      type: .dynamic,
      targets: ["AthenaNotationAndroidBridge"]
    )
  ],
  dependencies: [
    .package(name: "AthenaNotation", path: "../../../../../..")
  ],
  targets: [
    .target(
      name: "AthenaNotationAndroidBridge",
      dependencies: [
        .product(name: "AthenaNotationCore", package: "AthenaNotation"),
        .product(name: "AthenaNotationRenderAndroid", package: "AthenaNotation"),
        .product(name: "AthenaScoreAnalysis", package: "AthenaNotation"),
        .product(name: "AthenaMusicXML", package: "AthenaNotation"),
        .product(name: "AthenaMIDI", package: "AthenaNotation"),
      ]
    )
  ]
)
