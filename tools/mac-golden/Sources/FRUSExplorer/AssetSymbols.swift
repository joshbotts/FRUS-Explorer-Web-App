// The one asset symbol the app uses, as Xcode generates it from Assets.xcassets for an app target
// (ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS in project.yml). SwiftPM generates
// none. The tool never draws the image.

import DeveloperToolsSupport

extension ImageResource {
    static let launchAppTile = ImageResource(name: "LaunchAppTile", bundle: .main)
}
