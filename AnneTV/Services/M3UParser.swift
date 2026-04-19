import Foundation

enum M3UParser {
    struct ParseResult {
        let channels: [Channel]
        let categories: [Category]
    }

    static func parse(_ text: String) -> ParseResult {
        var channels: [Channel] = []
        var categoryNames: Set<String> = []
        let lines = text.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#EXTINF:") {
                let name = extractDisplayName(from: line)
                let tvgId = extractAttribute("tvg-id", from: line) ?? ""
                let tvgLogo = extractAttribute("tvg-logo", from: line)
                let groupTitle = extractAttribute("group-title", from: line)

                // Next non-empty, non-comment line is the stream URL
                i += 1
                while i < lines.count {
                    let urlLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if !urlLine.isEmpty && !urlLine.hasPrefix("#") {
                        if let url = URL(string: urlLine) {
                            let channel = Channel(
                                id: urlLine,
                                name: name,
                                logoURL: tvgLogo.flatMap { URL(string: $0) },
                                epgChannelId: tvgId,
                                categoryId: groupTitle,
                                streamURL: url
                            )
                            channels.append(channel)
                            if let group = groupTitle, !group.isEmpty {
                                categoryNames.insert(group)
                            }
                        }
                        break
                    }
                    i += 1
                }
            }
            i += 1
        }

        let categories = categoryNames.sorted().map { Category(id: $0, name: $0) }
        return ParseResult(channels: channels, categories: categories)
    }

    private static func extractAttribute(_ attr: String, from line: String) -> String? {
        guard let range = line.range(of: "\(attr)=\"") else { return nil }
        let start = range.upperBound
        guard let end = line[start...].firstIndex(of: "\"") else { return nil }
        let value = String(line[start..<end])
        return value.isEmpty ? nil : value
    }

    private static func extractDisplayName(from line: String) -> String {
        guard let commaIndex = line.lastIndex(of: ",") else { return "Unknown" }
        let name = String(line[line.index(after: commaIndex)...])
            .trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown" : name
    }
}
