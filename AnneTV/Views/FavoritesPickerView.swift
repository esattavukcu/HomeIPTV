import SwiftUI

struct FavoritesPickerView: View {
    @Environment(AppState.self) var app
    var onFinished: () -> Void

    var body: some View {
        NavigationStack {
            List {
                // Done button as first focusable item (important for tvOS)
                Section {
                    Button {
                        onFinished()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Done (\(app.favoriteOrder.count) selected)")
                                .font(Platform.font(30, weight: .semibold))
                            Spacer()
                        }
                    }
                }

                Section {
                    ForEach(app.categories) { category in
                        NavigationLink {
                            CategoryChannelsView(category: category)
                                .environment(app)
                        } label: {
                            HStack {
                                Text(category.name)
                                    .font(Platform.font(30, weight: .medium))
                                Spacer()
                                Text("\(selectedCount(in: category)) / \(app.channels(in: category.id).count)")
                                    .font(Platform.font(22))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, Platform.dim(12))
                        }
                    }
                }
            }
            .navigationTitle("Pick Favorite Channels")
        }
    }

    private func selectedCount(in category: Category) -> Int {
        app.channels(in: category.id).filter { app.isFavorite($0.id) }.count
    }
}

struct CategoryChannelsView: View {
    @Environment(AppState.self) var app
    let category: Category

    var body: some View {
        List {
            ForEach(app.channels(in: category.id)) { channel in
                Button {
                    app.toggleFavorite(channel.id)
                } label: {
                    HStack(spacing: Platform.dim(20)) {
                        logo(channel)
                        Text(channel.name)
                            .font(Platform.font(26, weight: .medium))
                        Spacer()
                        if app.isFavorite(channel.id) {
                            Text("★")
                                .font(Platform.font(32))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.vertical, Platform.dim(10))
                }
            }
        }
        .navigationTitle(category.name)
    }

    @ViewBuilder
    private func logo(_ channel: Channel) -> some View {
        let size = Platform.dim(70)
        if let url = channel.logoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                default: Color.gray.opacity(0.3)
                }
            }
            .frame(width: size, height: size)
            .cornerRadius(8)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
        }
    }
}
