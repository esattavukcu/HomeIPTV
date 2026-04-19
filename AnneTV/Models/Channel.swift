import Foundation

struct Channel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let logoURL: URL?
    let epgChannelId: String
    let categoryId: String?
    let streamURL: URL?       // Direct URL for M3U channels; nil for Xtream
}

struct Category: Identifiable, Codable, Hashable {
    let id: String        // category_id
    let name: String      // category_name
}

struct Credentials: Codable {
    let serverURL: String   // e.g. "http://server.com:8080"
    let username: String
    let password: String

    var baseURL: URL? { URL(string: serverURL) }
}

enum ConnectionConfig: Codable {
    case xtream(Credentials)
    case m3u(M3UConfig)
}

struct M3UConfig: Codable {
    let playlistURL: String
}

struct EPGProgram: Identifiable {
    let id = UUID()
    let channelId: String
    let title: String
    let start: Date
    let stop: Date
}
