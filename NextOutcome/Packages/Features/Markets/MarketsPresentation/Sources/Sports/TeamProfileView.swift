//
//  TeamProfileView.swift
//  NextOutcome
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The team/fighter profile screen: name/logo/record header, an upcoming-match card,
/// and match history. Scoped to what Gamma's public API actually provides — no bio
/// fields, no About/FAQ copy (see `TeamProfileTarget`).
public struct TeamProfileView: View {
    /// The view model driving this screen's data.
    @State private var viewModel: TeamProfileViewModel

    /// Creates the view.
    /// - Parameter viewModel: The team profile view model.
    public init(viewModel: TeamProfileViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                header
                content
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(DSColor.background)
        .task { await viewModel.loadIfNeeded() }
    }

    /// Logo, name, and record (when known).
    private var header: some View {
        HStack(spacing: DSLayout.spacing) {
            AsyncImage(url: viewModel.target.logoURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(DSColor.surfaceElevated).overlay(
                    Text(viewModel.target.name.prefix(1))
                        .font(DSFont.title3.bold())
                        .foregroundStyle(DSColor.textSecondary)
                )
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.target.name)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                if let record = viewModel.record {
                    Text(record)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
        }
    }

    /// The loading/error/loaded body below the header.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            StateView(.loading).frame(maxWidth: .infinity).padding(.top, DSLayout.spacingXLarge)
        case .failed(let message):
            StateView(.error(message)).frame(maxWidth: .infinity).padding(.top, DSLayout.spacingXLarge)
        case .loaded:
            if viewModel.upcomingMatch == nil && viewModel.matchHistory.isEmpty {
                StateView(.empty).frame(maxWidth: .infinity).padding(.top, DSLayout.spacingXLarge)
            } else {
                if let upcoming = viewModel.upcomingMatch { upcomingSection(upcoming) }
                if !viewModel.matchHistory.isEmpty { historySection }
            }
        }
    }

    /// The "Upcoming Match" card.
    private func upcomingSection(_ match: TeamProfileViewModel.Match) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text("Upcoming Match")
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
            DSCard {
                NavigationLink(value: match.event) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(viewModel.target.name) vs \(match.opponentName)")
                                .font(DSFont.subheadline.bold())
                                .foregroundStyle(DSColor.textPrimary)
                            if let kickoff = match.event.gameStartTime {
                                Text(kickoff, format: .dateTime.month().day().hour().minute())
                                    .font(DSFont.caption)
                                    .foregroundStyle(DSColor.textSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(DSColor.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The "Match History" list, each row a W/L badge + opponent, newest first.
    private var historySection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text("Match History")
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
            DSCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.matchHistory.enumerated()), id: \.element.id) { index, record in
                        NavigationLink(value: record.event) {
                            HStack {
                                Text("vs \(record.opponentName)")
                                    .font(DSFont.subheadline)
                                    .foregroundStyle(DSColor.textPrimary)
                                Spacer()
                                Text(record.won ? "W" : "L")
                                    .font(DSFont.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(record.won ? DSColor.positive : DSColor.negative)
                                    .clipShape(Circle())
                            }
                            .padding(.vertical, DSLayout.spacingSmall)
                        }
                        .buttonStyle(.plain)
                        if index < viewModel.matchHistory.count - 1 {
                            Divider().overlay(DSColor.separator)
                        }
                    }
                }
            }
        }
    }
}
