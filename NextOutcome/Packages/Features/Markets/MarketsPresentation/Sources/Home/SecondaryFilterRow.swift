//
//  SecondaryFilterRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import DesignSystem

/// Home's secondary filter row: sort menu, status menu, Hide-sports toggle.
public struct SecondaryFilterRow: View {
    /// The event-list view model whose sort/status/hide-sports state this row drives.
    @Bindable private var viewModel: EventListViewModel
    /// Creates the row.
    /// - Parameter viewModel: The event-list view model to bind to.
    public init(viewModel: EventListViewModel) { self.viewModel = viewModel }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(EventListViewModel.MarketSort.allCases, id: \.self) { s in
                        Button(s.title) { Task { await viewModel.setSort(s) } }
                    }
                } label: { DSMenuLabel(viewModel.sort.title, systemImage: "arrow.up.arrow.down") }

                Menu {
                    ForEach(EventListViewModel.MarketStatus.allCases, id: \.self) { s in
                        Button(s.title) { Task { await viewModel.setStatus(s) } }
                    }
                } label: { DSMenuLabel(viewModel.status.title, systemImage: "chevron.down") }

                Button { viewModel.toggleHideSports() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.hideSports ? "checkmark.square.fill" : "square")
                        Text("Hide sports")
                    }
                    .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
    }
}

/// A capsule label (icon + text) used as the tappable label for the sort/status menus.
private struct DSMenuLabel: View {
    /// The label text.
    let title: String
    /// The SF Symbol name shown before the text.
    let systemImage: String
    /// Creates the label.
    init(_ title: String, systemImage: String) { self.title = title; self.systemImage = systemImage }
    var body: some View {
        HStack(spacing: 6) { Image(systemName: systemImage); Text(title) }
            .font(DSFont.caption).foregroundStyle(DSColor.textPrimary)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(DSColor.surface).clipShape(Capsule())
    }
}
