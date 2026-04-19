import Foundation

struct XtreamAPI {
    let credentials: Credentials

    private var playerAPI: URL? {
        guard let base = credentials.baseURL else { return nil }
        var comps = URLComponents(url: base.appendingPathComponent("player_api.php"),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "username", value: credentials.username),
            URLQueryItem(name: "password", value: credentials.password)
        ]
        return comps?.url
    }

    private var xmltvURL: URL? {
        guard let base = credentials.baseURL else { return nil }
        var comps = URLComponents(url: base.appendingPathComponent("xmltv.php"),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "username", value: credentials.username),
            URLQueryItem(name: "password", value: credentials.password)
        ]
        return comps?.url
    }

    func streamURL(for channel: Channel) -> URL? {
        guard let base = credentials.baseURL else { return nil }
        // Xtream live stream convention
        return base
            .appendingPathComponent("live")
            .appendingPathComponent(credentials.username)
            .appendingPathComponent(credentials.password)
            .appendingPathComponent("\(channel.id).m3u8")
    }

    func fetchLiveCategories() async throws -> [Category] {
        guard let url = playerAPI else { throw URLError(.badURL) }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems?.append(URLQueryItem(name: "action", value: "get_live_categories"))
        let (data, _) = try await URLSession.shared.data(from: comps.url!)
        let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return raw.compactMap { dict in
            guard let id = dict["category_id"] as? String,
                  let name = dict["category_name"] as? String else { return nil }
            return Category(id: id, name: name)
        }
    }

    func fetchLiveStreams() async throws -> [Channel] {
        guard var url = playerAPI else { throw URLError(.badURL) }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems?.append(URLQueryItem(name: "action", value: "get_live_streams"))
        url = comps.url!

        let (data, _) = try await URLSession.shared.data(from: url)
        let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return raw.compactMap { dict in
            guard let id = dict["stream_id"] as? Int,
                  let name = dict["name"] as? String else { return nil }
            let logo = (dict["stream_icon"] as? String).flatMap { URL(string: $0) }
            let epgId = (dict["epg_channel_id"] as? String) ?? ""
            let categoryId = dict["category_id"] as? String
            return Channel(id: "\(id)",
                           name: name,
                           logoURL: logo,
                           epgChannelId: epgId,
                           categoryId: categoryId,
                           streamURL: nil)
        }
    }

    func fetchEPG() async throws -> [String: [EPGProgram]] {
        guard let url = xmltvURL else { return [:] }
        let (data, _) = try await URLSession.shared.data(from: url)
        return XMLTVParser.parse(data: data)
    }
}
