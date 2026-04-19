import SwiftUI

@main
struct BasicIPTVApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
@Observable
final class AppState {
    var connectionConfig: ConnectionConfig? = KeychainStore.load()
    var channels: [Channel] = []
    var categories: [Category] = []
    var favoriteOrder: [String] = FavoritesStore.load()
    var epg: [String: [EPGProgram]] = [:]
    var isLoading = false
    var errorMessage: String?

    var favoriteChannels: [Channel] {
        let byId = Dictionary(uniqueKeysWithValues: channels.map { ($0.id, $0) })
        return favoriteOrder.compactMap { byId[$0] }
    }

    func channels(in categoryId: String) -> [Channel] {
        channels.filter { $0.categoryId == categoryId }
    }

    func isFavorite(_ channelId: String) -> Bool {
        favoriteOrder.contains(channelId)
    }

    func refresh() async {
        guard let config = connectionConfig else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            switch config {
            case .xtream(let creds):
                let api = XtreamAPI(credentials: creds)
                async let channelsTask = api.fetchLiveStreams()
                async let categoriesTask = api.fetchLiveCategories()
                async let epgTask = api.fetchEPG()
                let (ch, cat, ep) = try await (channelsTask, categoriesTask, epgTask)
                self.channels = ch
                self.categories = cat
                self.epg = ep

            case .m3u(let m3uConfig):
                guard let url = URL(string: m3uConfig.playlistURL) else {
                    throw URLError(.badURL)
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    throw URLError(.cannotDecodeContentData)
                }
                let result = M3UParser.parse(text)
                self.channels = result.channels
                self.categories = result.categories
                self.epg = [:]
            }
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Connection error. Please check your internet connection."
        }
    }

    func saveConnection(_ config: ConnectionConfig) {
        KeychainStore.save(config)
        self.connectionConfig = config
    }

    func toggleFavorite(_ channelId: String) {
        if let idx = favoriteOrder.firstIndex(of: channelId) {
            favoriteOrder.remove(at: idx)
        } else {
            favoriteOrder.append(channelId)
        }
        FavoritesStore.save(favoriteOrder)
    }

    func moveFavorite(channelId: String, direction: Int) {
        guard let idx = favoriteOrder.firstIndex(of: channelId) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0 && newIdx < favoriteOrder.count else { return }
        favoriteOrder.swapAt(idx, newIdx)
        FavoritesStore.save(favoriteOrder)
    }

    func currentProgram(for channel: Channel) -> EPGProgram? {
        guard let programs = epg[channel.epgChannelId] else { return nil }
        let now = Date()
        return programs.first { $0.start <= now && $0.stop > now }
    }

    func nextProgram(for channel: Channel) -> EPGProgram? {
        guard let programs = epg[channel.epgChannelId] else { return nil }
        let now = Date()
        return programs.first { $0.start > now }
    }
}
