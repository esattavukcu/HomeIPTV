#!/usr/bin/env swift
import AppKit
import Foundation

// MARK: - Screenshot Sizes
struct ScreenSize {
    let name: String
    let width: Int
    let height: Int
}

let sizes: [ScreenSize] = [
    ScreenSize(name: "iPhone_6.7", width: 1290, height: 2796),
    ScreenSize(name: "iPhone_6.5", width: 1284, height: 2778),
    ScreenSize(name: "iPad_12.9", width: 2048, height: 2732),
    ScreenSize(name: "AppleTV", width: 1920, height: 1080),
]

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

// MARK: - Colors
let darkBg = NSColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 1.0)
let cardBg = NSColor(red: 0.12, green: 0.12, blue: 0.20, alpha: 1.0)
let accentBlue = NSColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
let accentPurple = NSColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 1.0)
let textWhite = NSColor.white
let textGray = NSColor(white: 0.6, alpha: 1.0)
let greenColor = NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
let redColor = NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)

// MARK: - Helper Functions
func createBitmap(width: Int, height: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: width, height: height)
    return rep
}

func savePNG(_ rep: NSBitmapImageRep, path: String) {
    if let data = rep.representation(using: .png, properties: [:]) {
        try! data.write(to: URL(fileURLWithPath: path))
        print("Saved: \(path)")
    }
}

func drawGradientBackground(_ ctx: NSGraphicsContext, width: CGFloat, height: CGFloat) {
    let gradient = NSGradient(colors: [
        NSColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0),
        NSColor(red: 0.10, green: 0.08, blue: 0.18, alpha: 1.0),
        NSColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0),
    ])!
    gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)
}

func drawRoundedRect(rect: NSRect, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
}

func drawText(_ text: String, at point: NSPoint, font: NSFont, color: NSColor, maxWidth: CGFloat = 0) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    if maxWidth > 0 {
        let rect = NSRect(x: point.x, y: point.y, width: maxWidth, height: 1000)
        text.draw(with: rect, options: [.usesLineFragmentOrigin], attributes: attrs)
    } else {
        text.draw(at: point, withAttributes: attrs)
    }
}

func drawCenteredText(_ text: String, y: CGFloat, width: CGFloat, font: NSFont, color: NSColor) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let size = text.size(withAttributes: attrs)
    let x = (width - size.width) / 2
    text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}

func drawStatusBar(width: CGFloat, height: CGFloat, scale: CGFloat) {
    let barHeight = 44 * scale
    let y = height - barHeight
    drawText("9:41", at: NSPoint(x: width/2 - 20*scale, y: y + 12*scale),
             font: NSFont.systemFont(ofSize: 14*scale, weight: .semibold), color: textWhite)
}

func drawPlayIcon(center: NSPoint, size: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    let halfSize = size / 2
    path.move(to: NSPoint(x: center.x - halfSize * 0.4, y: center.y - halfSize))
    path.line(to: NSPoint(x: center.x + halfSize * 0.6, y: center.y))
    path.line(to: NSPoint(x: center.x - halfSize * 0.4, y: center.y + halfSize))
    path.close()
    color.setFill()
    path.fill()
}

func drawTVIcon(center: NSPoint, size: CGFloat, color: NSColor) {
    let w = size
    let h = size * 0.7
    let screenRect = NSRect(x: center.x - w/2, y: center.y - h/2 + size*0.1, width: w, height: h)
    let path = NSBezierPath(roundedRect: screenRect, xRadius: size*0.08, yRadius: size*0.08)
    color.setStroke()
    path.lineWidth = size * 0.06
    path.stroke()

    // Stand
    let standPath = NSBezierPath()
    standPath.move(to: NSPoint(x: center.x - w*0.2, y: center.y - h/2 + size*0.1))
    standPath.line(to: NSPoint(x: center.x - w*0.3, y: center.y - h/2 - size*0.1))
    standPath.move(to: NSPoint(x: center.x + w*0.2, y: center.y - h/2 + size*0.1))
    standPath.line(to: NSPoint(x: center.x + w*0.3, y: center.y - h/2 - size*0.1))
    color.setStroke()
    standPath.lineWidth = size * 0.05
    standPath.stroke()

    // Play icon in screen
    drawPlayIcon(center: NSPoint(x: center.x, y: center.y + size*0.1), size: size*0.25, color: color)
}

// MARK: - Channel List Screenshot
func generateChannelList(size: ScreenSize) {
    let w = CGFloat(size.width)
    let h = CGFloat(size.height)
    let isTV = size.name.contains("TV")
    let isIPad = size.name.contains("iPad")
    let scale: CGFloat = isTV ? 1.0 : (isIPad ? 1.5 : w / 1290.0)

    let rep = createBitmap(width: size.width, height: size.height)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx

    // Background
    drawGradientBackground(ctx, width: w, height: h)

    let margin = isTV ? 80.0 : 32.0 * scale
    let cardHeight = isTV ? 80.0 : 72.0 * scale
    let cardSpacing = isTV ? 12.0 : 10.0 * scale
    let cornerRadius = isTV ? 16.0 : 14.0 * scale
    let titleFontSize = isTV ? 34.0 : 28.0 * scale
    let channelFontSize = isTV ? 22.0 : 18.0 * scale
    let categoryFontSize = isTV ? 16.0 : 13.0 * scale

    // Header
    let headerY = h - (isTV ? 100.0 : 120.0 * scale)
    drawText("HomeIPTV", at: NSPoint(x: margin, y: headerY),
             font: NSFont.systemFont(ofSize: titleFontSize, weight: .bold), color: textWhite)

    // Category pills
    let pillY = headerY - (isTV ? 50.0 : 45.0 * scale)
    let categories = ["All", "Entertainment", "Sports", "News", "Movies"]
    var pillX = margin
    for (i, cat) in categories.enumerated() {
        let pillWidth = CGFloat(cat.count) * (isTV ? 14.0 : 11.0*scale) + (isTV ? 24.0 : 20.0*scale)
        let pillHeight = isTV ? 36.0 : 30.0 * scale
        let pillColor = i == 0 ? accentBlue : cardBg
        drawRoundedRect(rect: NSRect(x: pillX, y: pillY, width: pillWidth, height: pillHeight),
                       radius: pillHeight/2, color: pillColor)
        drawText(cat, at: NSPoint(x: pillX + (isTV ? 12 : 10*scale), y: pillY + (isTV ? 8 : 7*scale)),
                font: NSFont.systemFont(ofSize: categoryFontSize, weight: i == 0 ? .semibold : .regular),
                color: i == 0 ? .white : textGray)
        pillX += pillWidth + (isTV ? 10 : 8*scale)
    }

    // Channel list
    let channels = [
        ("TRT 1 HD", "Entertainment", true),
        ("Show TV", "Entertainment", true),
        ("ATV HD", "Entertainment", true),
        ("Star TV", "Entertainment", false),
        ("Kanal D HD", "Entertainment", true),
        ("Fox TV", "Entertainment", true),
        ("TV8 HD", "Entertainment", false),
        ("NTV Spor", "Sports", true),
        ("CNN Türk", "News", true),
        ("Haber Global", "News", false),
        ("TLC", "Entertainment", true),
        ("beIN Sports 1", "Sports", true),
        ("Eurosport", "Sports", false),
        ("National Geographic", "Documentary", true),
        ("Discovery Channel", "Documentary", false),
    ]

    let listStartY = pillY - (isTV ? 30.0 : 25.0*scale)
    let maxChannels = isTV ? 8 : (isIPad ? 14 : 12)

    for (i, channel) in channels.prefix(maxChannels).enumerated() {
        let cardY = listStartY - CGFloat(i) * (cardHeight + cardSpacing)
        if cardY < 0 { break }

        let isSelected = i == 2
        let cardColor = isSelected ? accentBlue.withAlphaComponent(0.2) : cardBg
        let borderColor = isSelected ? accentBlue : NSColor.clear

        // Card background
        drawRoundedRect(rect: NSRect(x: margin, y: cardY, width: w - margin*2, height: cardHeight),
                       radius: cornerRadius, color: cardColor)

        if isSelected {
            let borderPath = NSBezierPath(roundedRect: NSRect(x: margin, y: cardY, width: w - margin*2, height: cardHeight),
                                          xRadius: cornerRadius, yRadius: cornerRadius)
            borderColor.setStroke()
            borderPath.lineWidth = 2
            borderPath.stroke()
        }

        // Channel logo placeholder (colored circle)
        let logoSize = isTV ? 48.0 : 44.0 * scale
        let logoX = margin + (isTV ? 16.0 : 14.0*scale)
        let logoY = cardY + (cardHeight - logoSize) / 2
        let logoColors = [accentBlue, accentPurple, greenColor, NSColor.orange, redColor]
        let logoColor = logoColors[i % logoColors.count]
        let logoPath = NSBezierPath(ovalIn: NSRect(x: logoX, y: logoY, width: logoSize, height: logoSize))
        logoColor.withAlphaComponent(0.3).setFill()
        logoPath.fill()

        // Channel initial
        let initial = String(channel.0.prefix(1))
        drawCenteredText(initial, y: logoY + logoSize*0.2, width: logoSize,
                        font: NSFont.systemFont(ofSize: logoSize*0.45, weight: .bold), color: logoColor)
        // Offset to center in circle
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: logoSize*0.45, weight: .bold), .foregroundColor: logoColor]
        let iSize = initial.size(withAttributes: attrs)
        // Draw initial centered
        initial.draw(at: NSPoint(x: logoX + (logoSize - iSize.width)/2, y: logoY + (logoSize - iSize.height)/2), withAttributes: attrs)

        // Channel name
        let textX = logoX + logoSize + (isTV ? 16.0 : 12.0*scale)
        let nameY = cardY + cardHeight*0.55
        drawText(channel.0, at: NSPoint(x: textX, y: nameY),
                font: NSFont.systemFont(ofSize: channelFontSize, weight: .medium), color: textWhite)

        // Category label
        drawText(channel.1, at: NSPoint(x: textX, y: cardY + cardHeight*0.2),
                font: NSFont.systemFont(ofSize: categoryFontSize), color: textGray)

        // Live indicator
        if channel.2 {
            let liveX = w - margin - (isTV ? 70 : 60*scale)
            let liveY = cardY + cardHeight/2 - (isTV ? 10 : 8*scale)
            let dotSize = isTV ? 8.0 : 6.0*scale
            let dotPath = NSBezierPath(ovalIn: NSRect(x: liveX, y: liveY + (isTV ? 6 : 5*scale), width: dotSize, height: dotSize))
            greenColor.setFill()
            dotPath.fill()
            drawText("LIVE", at: NSPoint(x: liveX + dotSize + 4, y: liveY),
                    font: NSFont.systemFont(ofSize: categoryFontSize - 1, weight: .semibold), color: greenColor)
        }
    }

    // Promotional text at top
    if !isTV {
        let promoY = h - 70 * scale
        drawCenteredText("Your Channels, Your Way", y: promoY,
                        width: w, font: NSFont.systemFont(ofSize: 16*scale, weight: .medium), color: accentBlue)
    }

    NSGraphicsContext.restoreGraphicsState()
    savePNG(rep, path: "\(outputDir)/\(size.name)_1_channels.png")
}

// MARK: - Player Screenshot
func generatePlayer(size: ScreenSize) {
    let w = CGFloat(size.width)
    let h = CGFloat(size.height)
    let isTV = size.name.contains("TV")
    let scale: CGFloat = isTV ? 1.0 : w / 1290.0

    let rep = createBitmap(width: size.width, height: size.height)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx

    // Black background for player
    NSColor.black.setFill()
    NSRect(x: 0, y: 0, width: w, height: h).fill()

    // Simulate video content with a gradient
    let videoGradient = NSGradient(colors: [
        NSColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 1.0),
        NSColor(red: 0.1, green: 0.15, blue: 0.3, alpha: 1.0),
        NSColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1.0),
    ])!
    videoGradient.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 45)

    // TV content area simulation
    let contentW = w * 0.85
    let contentH = isTV ? h * 0.7 : h * 0.4
    let contentX = (w - contentW) / 2
    let contentY = isTV ? (h - contentH) / 2 + 40 : h * 0.4

    // Simulated video frame
    drawRoundedRect(rect: NSRect(x: contentX, y: contentY, width: contentW, height: contentH),
                   radius: 4, color: NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 0.5))

    // Large play icon in center
    let centerX = w / 2
    let centerY = contentY + contentH / 2
    let playSize = isTV ? 60.0 : 50.0 * scale

    // Play button circle
    let circleSize = playSize * 2.5
    let circlePath = NSBezierPath(ovalIn: NSRect(x: centerX - circleSize/2, y: centerY - circleSize/2,
                                                   width: circleSize, height: circleSize))
    NSColor.white.withAlphaComponent(0.15).setFill()
    circlePath.fill()
    NSColor.white.withAlphaComponent(0.4).setStroke()
    circlePath.lineWidth = 2
    circlePath.stroke()

    drawPlayIcon(center: NSPoint(x: centerX + playSize*0.1, y: centerY), size: playSize, color: .white)

    // Channel info overlay at bottom
    let overlayHeight = isTV ? 120.0 : 100.0 * scale
    let overlayGrad = NSGradient(colors: [
        NSColor.black.withAlphaComponent(0.0),
        NSColor.black.withAlphaComponent(0.8),
    ])!
    overlayGrad.draw(in: NSRect(x: 0, y: 0, width: w, height: overlayHeight * 2), angle: 90)

    let margin = isTV ? 60.0 : 32.0 * scale
    let channelNameSize = isTV ? 28.0 : 22.0 * scale
    let infoSize = isTV ? 18.0 : 14.0 * scale

    // Channel name
    drawText("ATV HD", at: NSPoint(x: margin, y: overlayHeight * 0.8),
            font: NSFont.systemFont(ofSize: channelNameSize, weight: .bold), color: textWhite)

    // Program info
    drawText("Now: Movie Night - Action Film", at: NSPoint(x: margin, y: overlayHeight * 0.4),
            font: NSFont.systemFont(ofSize: infoSize), color: textGray)

    // Progress bar
    let barY = overlayHeight * 0.2
    let barWidth = w - margin * 2
    let barHeight = isTV ? 4.0 : 3.0 * scale
    drawRoundedRect(rect: NSRect(x: margin, y: barY, width: barWidth, height: barHeight),
                   radius: barHeight/2, color: NSColor.white.withAlphaComponent(0.2))
    drawRoundedRect(rect: NSRect(x: margin, y: barY, width: barWidth * 0.35, height: barHeight),
                   radius: barHeight/2, color: accentBlue)

    // Time labels
    drawText("00:35:12", at: NSPoint(x: margin, y: barY - infoSize - 4),
            font: NSFont.monospacedDigitSystemFont(ofSize: infoSize * 0.85, weight: .regular), color: textGray)
    drawText("01:42:00", at: NSPoint(x: w - margin - 80*scale, y: barY - infoSize - 4),
            font: NSFont.monospacedDigitSystemFont(ofSize: infoSize * 0.85, weight: .regular), color: textGray)

    // Volume indicator (top right)
    if !isTV {
        let volX = w - margin - 40*scale
        let volY = h - 80*scale
        let volWidth = 4.0 * scale
        let volHeight = 60.0 * scale
        drawRoundedRect(rect: NSRect(x: volX, y: volY, width: volWidth, height: volHeight),
                       radius: volWidth/2, color: NSColor.white.withAlphaComponent(0.2))
        drawRoundedRect(rect: NSRect(x: volX, y: volY, width: volWidth, height: volHeight * 0.7),
                       radius: volWidth/2, color: accentBlue)
    }

    // Channel navigation hint
    let hintY = isTV ? h - 60.0 : h - 60.0 * scale
    let hintFontSize = isTV ? 14.0 : 11.0 * scale

    if isTV {
        drawCenteredText("◀ Previous Channel    ▶ Next Channel", y: hintY,
                        width: w, font: NSFont.systemFont(ofSize: hintFontSize), color: textGray.withAlphaComponent(0.5))
    } else {
        drawCenteredText("← → Switch Channels    ↑ ↓ Volume", y: hintY,
                        width: w, font: NSFont.systemFont(ofSize: hintFontSize), color: textGray.withAlphaComponent(0.5))
    }

    NSGraphicsContext.restoreGraphicsState()
    savePNG(rep, path: "\(outputDir)/\(size.name)_2_player.png")
}

// MARK: - Setup Screenshot
func generateSetup(size: ScreenSize) {
    let w = CGFloat(size.width)
    let h = CGFloat(size.height)
    let isTV = size.name.contains("TV")
    let isIPad = size.name.contains("iPad")
    let scale: CGFloat = isTV ? 1.0 : w / 1290.0

    let rep = createBitmap(width: size.width, height: size.height)
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx

    // Background
    drawGradientBackground(ctx, width: w, height: h)

    let centerX = w / 2
    let formWidth = isTV ? 600.0 : (isIPad ? w * 0.5 : w * 0.85)
    let formX = centerX - formWidth / 2
    let fieldHeight = isTV ? 50.0 : 48.0 * scale
    let fieldSpacing = isTV ? 16.0 : 14.0 * scale
    let cornerRadius = isTV ? 12.0 : 10.0 * scale
    let titleFontSize = isTV ? 36.0 : 30.0 * scale
    let labelFontSize = isTV ? 16.0 : 13.0 * scale
    let fieldFontSize = isTV ? 18.0 : 16.0 * scale

    // Logo / Icon area
    let iconSize = isTV ? 80.0 : 70.0 * scale
    let iconY = h * 0.72
    let iconCenter = NSPoint(x: centerX, y: iconY)

    // Draw TV icon
    drawTVIcon(center: iconCenter, size: iconSize, color: accentBlue)

    // App name
    let nameY = iconY - iconSize * 0.9
    drawCenteredText("HomeIPTV", y: nameY, width: w,
                    font: NSFont.systemFont(ofSize: titleFontSize, weight: .bold), color: textWhite)

    // Tagline
    let tagY = nameY - (isTV ? 30 : 26*scale)
    drawCenteredText("Stream your IPTV channels anywhere", y: tagY, width: w,
                    font: NSFont.systemFont(ofSize: labelFontSize + 2), color: textGray)

    // Connection type selector
    let selectorY = tagY - (isTV ? 60 : 50*scale)
    let selectorWidth = formWidth * 0.8
    let selectorX = centerX - selectorWidth / 2
    let selectorHeight = isTV ? 44.0 : 38.0 * scale

    drawRoundedRect(rect: NSRect(x: selectorX, y: selectorY, width: selectorWidth, height: selectorHeight),
                   radius: selectorHeight/2, color: cardBg)
    // Active tab
    drawRoundedRect(rect: NSRect(x: selectorX + 2, y: selectorY + 2, width: selectorWidth/2 - 2, height: selectorHeight - 4),
                   radius: (selectorHeight-4)/2, color: accentBlue)

    drawCenteredText("Xtream Codes", y: selectorY + selectorHeight*0.25, width: w - selectorWidth/2,
                    font: NSFont.systemFont(ofSize: labelFontSize, weight: .semibold), color: textWhite)

    let m3uAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: labelFontSize),
        .foregroundColor: textGray
    ]
    let m3uText = "M3U Playlist"
    let m3uSize = m3uText.size(withAttributes: m3uAttrs)
    m3uText.draw(at: NSPoint(x: selectorX + selectorWidth * 0.75 - m3uSize.width/2,
                              y: selectorY + (selectorHeight - m3uSize.height)/2), withAttributes: m3uAttrs)

    // Form fields
    let formStartY = selectorY - (isTV ? 50 : 40*scale)
    let fields = [
        ("Server URL", "http://example.com:8080"),
        ("Username", ""),
        ("Password", ""),
    ]

    for (i, field) in fields.enumerated() {
        let fieldY = formStartY - CGFloat(i) * (fieldHeight + fieldSpacing + (isTV ? 20 : 16*scale))

        // Label
        drawText(field.0, at: NSPoint(x: formX, y: fieldY + fieldHeight + (isTV ? 6 : 4*scale)),
                font: NSFont.systemFont(ofSize: labelFontSize, weight: .medium), color: textGray)

        // Field background
        drawRoundedRect(rect: NSRect(x: formX, y: fieldY, width: formWidth, height: fieldHeight),
                       radius: cornerRadius, color: cardBg)

        // Field border
        let fieldPath = NSBezierPath(roundedRect: NSRect(x: formX, y: fieldY, width: formWidth, height: fieldHeight),
                                      xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor.white.withAlphaComponent(0.1).setStroke()
        fieldPath.lineWidth = 1
        fieldPath.stroke()

        // Placeholder text
        if !field.1.isEmpty {
            drawText(field.1, at: NSPoint(x: formX + (isTV ? 16 : 14*scale), y: fieldY + fieldHeight*0.3),
                    font: NSFont.systemFont(ofSize: fieldFontSize), color: textGray.withAlphaComponent(0.5))
        }
    }

    // Connect button
    let btnY = formStartY - CGFloat(fields.count) * (fieldHeight + fieldSpacing + (isTV ? 20 : 16*scale)) - (isTV ? 10 : 8*scale)
    let btnHeight = isTV ? 54.0 : 50.0 * scale

    let btnGrad = NSGradient(starting: accentBlue, ending: accentPurple)!
    let btnPath = NSBezierPath(roundedRect: NSRect(x: formX, y: btnY, width: formWidth, height: btnHeight),
                                xRadius: cornerRadius, yRadius: cornerRadius)
    btnGrad.draw(in: btnPath, angle: 0)

    drawCenteredText("Connect", y: btnY + btnHeight*0.28, width: w,
                    font: NSFont.systemFont(ofSize: fieldFontSize, weight: .bold), color: textWhite)

    // Feature list at bottom
    let featuresY = btnY - (isTV ? 80 : 70*scale)
    let features = ["Multi-platform Support", "Xtream & M3U", "Favorites & EPG"]
    let featureSpacing = isTV ? 30.0 : 24.0 * scale

    for (i, feature) in features.enumerated() {
        let fY = featuresY - CGFloat(i) * featureSpacing
        let checkmark = "✓ "
        drawCenteredText(checkmark + feature, y: fY, width: w,
                        font: NSFont.systemFont(ofSize: labelFontSize), color: greenColor)
    }

    NSGraphicsContext.restoreGraphicsState()
    savePNG(rep, path: "\(outputDir)/\(size.name)_3_setup.png")
}

// MARK: - Generate All
for size in sizes {
    print("Generating screenshots for \(size.name) (\(size.width)x\(size.height))...")
    generateChannelList(size: size)
    generatePlayer(size: size)
    generateSetup(size: size)
}

print("\nDone! All screenshots generated.")
