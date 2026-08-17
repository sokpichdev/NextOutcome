//
//  EsportsBroadcastPanel.swift
//  NextOutcome
//
//  Created by Sok Pich on 10/08/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The match detail screen's Livestream tab: the embedded broadcast when we can play it,
/// otherwise the event artwork plus a link out.
///
/// Twitch and YouTube embed; other hosts don't. Kick in particular is common on esports
/// events (`resolutionSource` of `https://kick.com/<channel>`), and rather than pretend a
/// dead player, the panel offers to open the broadcast in the browser.
struct EsportsBroadcastPanel: View {
    /// The confirmed-live broadcast to embed, if any.
    let stream: EsportsStream?
    /// Fallback artwork behind the link.
    let imageURL: URL?
    /// The broadcast page, for the link-out fallback.
    let broadcastURL: URL?
    /// Whether the match is currently being played, which decides the empty-state wording.
    let isLive: Bool
    /// Whether the match has finished — a finished match is not "about to start".
    let hasEnded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            EsportsStreamView(stream: stream, imageURL: imageURL)
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))

            // Only shown when there's no player — with one running, the video is its own
            // explanation.
            if stream == nil {
                Text(emptyMessage)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }

            // Offered either way. The inline player is deliberately view-only, so this is
            // the only route to a full-size stream — which makes it *more* useful while
            // something is playing, not less.
            if let broadcastURL {
                Link(destination: broadcastURL) {
                    HStack(spacing: DSLayout.spacingXSmall) {
                        Image(systemName: "arrow.up.forward.app.fill")
                        Text(Self.watchLabel(for: broadcastURL))
                    }
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.accent)
                }
                .accessibilityIdentifier("esports.detail.openBroadcast")
            }
        }
    }

    /// Why there's no player: the match is over, nobody is broadcasting yet, or the host
    /// won't embed.
    private var emptyMessage: String {
        if hasEnded { return "This match has finished." }
        if !isLive { return "The broadcast starts when the match goes live." }
        return broadcastURL == nil
            ? "No broadcast is listed for this match."
            : "This broadcast can't play in the app."
    }

    /// Names the destination rather than saying "Open broadcast" — a link that says where
    /// it goes is worth more than one that doesn't, and we always know the host.
    /// - Parameter url: The broadcast page.
    /// - Returns: e.g. "Watch on Twitch", falling back to a generic label for hosts we
    ///   don't recognise.
    static func watchLabel(for url: URL) -> String {
        guard let host = url.host()?.lowercased() else { return "Open broadcast" }
        if host.contains("twitch") { return "Watch on Twitch" }
        if host.contains("youtube") || host.contains("youtu.be") { return "Watch on YouTube" }
        if host.contains("kick") { return "Watch on Kick" }
        // Honor of Kings and other CN-region events broadcast here; 
        // Douyu has no embeddable player, so this link is the only route to the stream.
        if host.contains("douyu") { return "Watch on Douyu" }
        return "Open broadcast"
    }
}

#if DEBUG
#Preview("Broadcast — playing, with a way out to full size") {
    EsportsBroadcastPanel(
        stream: .twitch(channel: "eslcs"),
        imageURL: nil,
        broadcastURL: URL(string: "https://www.twitch.tv/eslcs"),
        isLive: true,
        hasEnded: false
    )
    .padding()
    .background(DSColor.background)
}

#Preview("Broadcast — no embeddable player") {
    EsportsBroadcastPanel(
        stream: nil,
        imageURL: nil,
        broadcastURL: URL(string: "https://kick.com/eplcs_en"),
        isLive: true,
        hasEnded: false
    )
    .padding()
    .background(DSColor.background)
}
#endif
