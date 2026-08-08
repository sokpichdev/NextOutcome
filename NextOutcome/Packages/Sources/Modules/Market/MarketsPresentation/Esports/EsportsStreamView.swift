//
//  EsportsStreamView.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import WebKit
import DesignSystem
import MarketsDomain

/// The hero card's media area: an embedded, muted player when the match's broadcast is
/// confirmed live (Twitch or YouTube, per the hub's `LiveStreamProbing` check), otherwise
/// the event image with a dimming gradient. The player is best-effort — if the site
/// declines to embed, its own iframe shows the error and the surrounding card still works.
struct EsportsStreamView: View {
    /// The confirmed-live broadcast to embed, or `nil` to show artwork.
    let stream: EsportsStream?
    /// Fallback artwork when there's no live stream.
    let imageURL: URL?
    /// Whether the player starts muted. Autoplay only works muted on iOS.
    @State private var isMuted = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            #if canImport(UIKit)
            switch stream {
            case .twitch(let channel):
                StreamWebView(embedHTML: Self.twitchHTML(channel: channel, muted: isMuted),
                              signature: "twitch-\(channel)-\(isMuted)")
                muteButton
            case .youtube(let videoID):
                StreamWebView(embedHTML: Self.youTubeHTML(videoID: videoID, muted: isMuted),
                              signature: "youtube-\(videoID)-\(isMuted)")
                muteButton
            case nil:
                fallbackImage
            }
            #else
            fallbackImage
            #endif
        }
        .frame(height: 190)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    /// The mute/unmute toggle overlaid on the player.
    private var muteButton: some View {
        Button {
            isMuted.toggle()
        } label: {
            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(8)
                .background(.black.opacity(0.5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(DSLayout.spacingSmall)
    }

    /// The event artwork with a subtle darkening gradient, standing in for the stream.
    private var fallbackImage: some View {
        GeometryReader { geo in
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.9)],
                               startPoint: .top, endPoint: .bottom)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .overlay(
                LinearGradient(colors: [.clear, .black.opacity(0.55)],
                               startPoint: .center, endPoint: .bottom)
            )
        }
    }

    // MARK: - Embed HTML

    /// Shared skeleton wrapping a full-bleed player iframe on a black page.
    private static func embedPage(iframeSrc: String) -> String {
        """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
        iframe{border:0;width:100%;height:100%}</style></head><body>
        <iframe src="\(iframeSrc)" allowfullscreen allow="autoplay; fullscreen"></iframe>
        </body></html>
        """
    }

    /// The Twitch iframe player. `parent` must match the page's `baseURL` host.
    static func twitchHTML(channel: String, muted: Bool) -> String {
        embedPage(iframeSrc:
            "https://player.twitch.tv/?channel=\(channel)&parent=polymarket.com&autoplay=true&muted=\(muted)")
    }

    /// The YouTube iframe player for a live video id.
    static func youTubeHTML(videoID: String, muted: Bool) -> String {
        embedPage(iframeSrc:
            "https://www.youtube.com/embed/\(videoID)?autoplay=1&mute=\(muted ? 1 : 0)&playsinline=1&controls=1")
    }
}

#if canImport(UIKit)
/// A muted, inline stream embed. Loads the player HTML with a `polymarket.com` base URL —
/// the pairing Twitch's embed API validates its `parent` parameter against (YouTube's
/// embed doesn't care about the referrer).
private struct StreamWebView: UIViewRepresentable {
    /// The full embed page HTML.
    let embedHTML: String
    /// Changes when the page should re-render (channel/video/mute changes).
    let signature: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        context.coordinator.signature = signature
        webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://polymarket.com"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.signature != signature {
            context.coordinator.signature = signature
            webView.loadHTMLString(embedHTML, baseURL: URL(string: "https://polymarket.com"))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator { var signature = "" }
}
#endif
