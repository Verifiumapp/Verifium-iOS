import Foundation

/// Fetches and caches the latest iOS version from the Verifium backend.
///
/// - On success: caches the result in UserDefaults (valid for 1 h).
/// - On failure: returns the cached value if still valid, otherwise `nil`.
enum VersionService {

    private static let endpoint = URL(string: "https://verifium.app/api/v1/ios-latest.json")!
    private static let cacheKey = "VersionService.latestVersion"
    private static let cacheDateKey = "VersionService.latestVersionDate"
    private static let cacheTTL: TimeInterval = 3_600 // 1 h

    struct LatestVersion {
        let major: Int
        let minor: Int
        let patch: Int

        var displayString: String {
            patch > 0 ? "\(major).\(minor).\(patch)" : "\(major).\(minor)"
        }
    }

    /// Returns the latest iOS version, or `nil` if unavailable (no network + no valid cache).
    static func fetchLatestVersion() async -> LatestVersion? {
        if let fetched = await fetchFromNetwork() {
            cache(fetched)
            return fetched
        }
        return cachedVersion()
    }

    // MARK: - Network

    private static func fetchFromNetwork() async -> LatestVersion? {
        do {
            let (data, response) = try await URLSession.shared.data(from: endpoint)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let json = try JSONDecoder().decode(VersionResponse.self, from: data)
            return parse(json.latest)
        } catch {
            return nil
        }
    }

    // MARK: - Cache

    private static func cache(_ version: LatestVersion) {
        let defaults = UserDefaults.standard
        defaults.set(version.displayString, forKey: cacheKey)
        defaults.set(Date().timeIntervalSince1970, forKey: cacheDateKey)
    }

    private static func cachedVersion() -> LatestVersion? {
        let defaults = UserDefaults.standard
        guard let cached = defaults.string(forKey: cacheKey) else { return nil }
        let timestamp = defaults.double(forKey: cacheDateKey)
        guard Date().timeIntervalSince1970 - timestamp < cacheTTL else { return nil }
        return parse(cached)
    }

    // MARK: - Helpers

    static func parse(_ versionString: String) -> LatestVersion? {
        let parts = versionString.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        return LatestVersion(major: parts[0], minor: parts[1], patch: parts.count >= 3 ? parts[2] : 0)
    }

    /// Returns true if `current` is at least as recent as `latest`.
    static func isUpToDate(current: String, latest: LatestVersion) -> Bool {
        guard let cur = parse(current) else { return false }
        if cur.major != latest.major { return cur.major > latest.major }
        if cur.minor != latest.minor { return cur.minor > latest.minor }
        return cur.patch >= latest.patch
    }

    private struct VersionResponse: Decodable {
        let latest: String
    }
}
