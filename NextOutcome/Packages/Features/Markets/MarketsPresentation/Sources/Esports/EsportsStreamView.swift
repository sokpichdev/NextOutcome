//
//  EsportsStreamView.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import WebKit
import DesignSystem

/// The hero card's media area: an embedded, muted Twitch player when the match's
/// `resolutionSource` points at a Twitch channel, otherwise the event image with a
/// dimming gradient. The player is best-effort — if Twitch declines to embed, its own
/// iframe shows the error and the surrounding card still works.
struct EsportsStreamView: View {
    /// The Twitch channel to embed, parsed from the event's `resolutionSource`.
    let twitchChannel: String?
    /// Fallback artwork when there's no embeddable stream.
    let imageURL: URL?
    /// Whether the player starts muted. Autoplay only works muted on iOS.
    @State private var isMuted = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            #if canImport(UIKit)
            if let twitchChannel {
                TwitchPlayerView(channel: twitchChannel, isMuted: isMuted)
                muteButton
            } else {
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
}

#if canImport(UIKit)
/// A muted, inline Twitch player embed. Loads the iframe player with
/// `parent=polymarket.com` and a matching `baseURL`, the pairing Twitch's embed API
/// validates against.
private struct TwitchPlayerView: UIViewRepresentable {
    let channel: String
    let isMuted: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        load(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Re-render only when the channel or mute state changes.
        let signature = "\(channel)-\(isMuted)"
        if context.coordinator.signature != signature {
            context.coordinator.signature = signature
            load(into: webView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator { var signature = "" }

    /// Loads the Twitch iframe player HTML. `baseURL` must match the `parent` parameter.
    private func load(into webView: WKWebView) {
        let html = """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
        iframe{border:0;width:100%;height:100%}</style></head><body>
        <iframe src="https://player.twitch.tv/?channel=\(channel)&parent=polymarket.com&autoplay=true&muted=\(isMuted)"
                allowfullscreen allow="autoplay; fullscreen"></iframe>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://polymarket.com"))
    }
}
#endif
