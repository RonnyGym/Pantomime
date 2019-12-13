// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "Pantomime",
  platforms: [
    .iOS(.v8),
    .tvOS(.v9)
  ],
  products: [
    .library(
      name: "Pantomime",
      targets: [
        "Pantomime"
      ]
    )
  ],
  targets: [
    .target(
      name: "Pantomime",
      path: "sources"
    )
  ],
  swiftLanguageVersions: [
    .v5
  ]
)
