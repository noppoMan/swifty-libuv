import PackageDescription

let package = Package(
	name: "SwiftyLibuv",
	dependencies: [
      .Package(url: "https://github.com/noppoMan/CLibUv.git", majorVersion: 0, minor: 1)
  ]
)
