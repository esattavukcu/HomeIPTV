import SwiftUI

enum ConnectionType: String, CaseIterable {
    case xtream = "Xtream Codes"
    case m3u = "M3U Playlist"
}

struct SetupView: View {
    @Environment(AppState.self) var app
    var onFinished: () -> Void

    @State private var connectionType: ConnectionType = .xtream
    @State private var serverURL: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var m3uURL: String = ""
    @State private var isTesting = false
    @State private var testError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Platform.dim(40)) {
                Text("Setup")
                    .font(Platform.font(64, weight: .bold))
                    .padding(.top, Platform.dim(40))

                Text("Enter your IPTV provider details")
                    .font(Platform.font(28))
                    .foregroundColor(.secondary)

                Picker("Connection Type", selection: $connectionType) {
                    ForEach(ConnectionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Platform.dim(100))

                if connectionType == .xtream {
                    VStack(spacing: Platform.dim(24)) {
                        field("Server URL (http://...)", text: $serverURL)
                        field("Username", text: $username)
                        field("Password", text: $password, secure: true)
                    }
                    .padding(.horizontal, Platform.dim(100))
                } else {
                    VStack(spacing: Platform.dim(24)) {
                        field("Playlist URL (http://...m3u)", text: $m3uURL)
                    }
                    .padding(.horizontal, Platform.dim(100))
                }

                if let err = testError {
                    Text(err)
                        .foregroundColor(.red)
                        .font(Platform.font(24))
                }

                Button(action: save) {
                    Text(isTesting ? "Connecting..." : "Save & Continue")
                        .font(Platform.font(32, weight: .semibold))
                        .padding(.horizontal, Platform.dim(60))
                        .padding(.vertical, Platform.dim(20))
                }
                .disabled(isTesting || !isFormValid)

                if app.connectionConfig != nil {
                    Button("Cancel") { onFinished() }
                        .font(Platform.font(24))
                        .foregroundColor(.secondary)
                }
            }
            .padding(Platform.dim(60))
        }
    }

    private var isFormValid: Bool {
        switch connectionType {
        case .xtream:
            return !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
        case .m3u:
            return !m3uURL.isEmpty
        }
    }

    private func field(_ title: String, text: Binding<String>, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Platform.font(24)).foregroundColor(.secondary)
            Group {
                if secure {
                    SecureField("", text: text).textContentType(.password)
                } else {
                    TextField("", text: text).textContentType(.URL)
                }
            }
            #if os(iOS)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            #elseif os(macOS)
            .textFieldStyle(.roundedBorder)
            .disableAutocorrection(true)
            #endif
        }
    }

    private func save() {
        isTesting = true
        testError = nil
        Task {
            do {
                switch connectionType {
                case .xtream:
                    let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    let creds = Credentials(serverURL: trimmed, username: username, password: password)
                    let api = XtreamAPI(credentials: creds)
                    let channels = try await api.fetchLiveStreams()
                    if channels.isEmpty {
                        testError = "No channels found. Please check your details."
                        isTesting = false
                        return
                    }
                    app.saveConnection(.xtream(creds))

                case .m3u:
                    let trimmed = m3uURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let url = URL(string: trimmed) else {
                        testError = "Invalid URL."
                        isTesting = false
                        return
                    }
                    let (data, _) = try await URLSession.shared.data(from: url)
                    guard let text = String(data: data, encoding: .utf8) else {
                        testError = "Could not read playlist."
                        isTesting = false
                        return
                    }
                    let result = M3UParser.parse(text)
                    if result.channels.isEmpty {
                        testError = "No channels found in playlist."
                        isTesting = false
                        return
                    }
                    app.saveConnection(.m3u(M3UConfig(playlistURL: trimmed)))
                }
                await app.refresh()
                isTesting = false
                onFinished()
            } catch {
                testError = "Connection failed: \(error.localizedDescription)"
                isTesting = false
            }
        }
    }
}
