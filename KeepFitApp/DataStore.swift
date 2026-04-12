import Foundation

enum DataFile: String, CaseIterable {
    case profile = "profile.json"
    case foods = "food_library.json"
    case exercises = "exercise_library.json"
    case foodLogs = "food_logs.json"
    case exerciseLogs = "exercise_logs.json"
    case bodyMetrics = "body_metrics.json"
}

final class DataStore {
    private let directoryURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        let fileManager = FileManager.default
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "KeepFit"
        directoryURL = supportURL.appendingPathComponent(bundleID, isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load<T: Codable>(_ type: T.Type, for file: DataFile) -> T? {
        let url = directoryURL.appendingPathComponent(file.rawValue)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Codable>(_ value: T, for file: DataFile) {
        let url = directoryURL.appendingPathComponent(file.rawValue)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func latestModificationDate(for files: [DataFile] = DataFile.allCases) -> Date? {
        files.compactMap { file in
            let url = directoryURL.appendingPathComponent(file.rawValue)
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else {
                return nil
            }
            return values.contentModificationDate
        }
        .max()
    }
}
