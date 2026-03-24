import Foundation

enum SpotlightCaffeinatePaths {
    static let appDirectoryName = "SpotlightCaffeinate"

    static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support", directoryHint: .isDirectory)

        return baseDirectory.appending(path: appDirectoryName, directoryHint: .isDirectory)
    }
}
