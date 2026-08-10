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

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            EsportsStreamView(stream: stream, imageURL: imageURL)
                .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))

            if stream == nil {
                VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                    Text(emptyMessage)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                    if let broadcastURL {
                        Link(destination: broadcastURL) {
                            HStack(spacing: DSLayout.spacingXSmall) {
                                Image(systemName: "play.rectangle.fill")
                                Text("Open broadcast")
                            }
                            .font(DSFont.subheadline.bold())
                            .foregroundStyle(DSColor.accent)
                        }
                        .accessibilityIdentifier("esports.detail.openBroadcast")
                    }
                }
            }
        }
    }

    /// Why there's no player: either nobody is broadcasting yet, or the host won't embed.
    private var emptyMessage: String {
        if !isLive { return "The broadcast starts when the match goes live." }
        return broadcastURL == nil
            ? "No broadcast is listed for this match."
            : "This broadcast can't play in the app."
    }
}

#if DEBUG
#Preview("Broadcast — no embeddable player") {
    EsportsBroadcastPanel(
        stream: nil,
        imageURL: nil,
        broadcastURL: URL(string: "https://kick.com/eplcs_en"),
        isLive: true
    )
    .padding()
    .background(DSColor.background)
}
#endif
