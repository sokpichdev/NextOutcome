//
//  SecondaryFilterRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import SwiftUI
import DesignSystem

/// Home's top row: a search field plus the toggle that shows/hides `AdvancedFilterRow`.
/// Always visible (non-collapsible).
public struct SearchFilterRow: View {
    /// The event-list view model whose search query and filter-row visibility this row drives.
    @Bindable private var viewModel: EventListViewModel
    /// Creates the row.
    /// - Parameter viewModel: The event-list view model to bind to.
    public init(viewModel: EventListViewModel) { self.viewModel = viewModel }

    public var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
                TextField("Search", text: $viewModel.searchQuery)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textPrimary)
                if !viewModel.searchQuery.isEmpty {
                    Button { viewModel.searchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(DSColor.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(DSColor.surface).clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))

            Button { viewModel.toggleFilterRowVisible() } label: {
                Image(systemName: viewModel.filterRowVisible ? "slider.horizontal.3" : "line.3.horizontal.decrease")
                    .foregroundStyle(DSColor.textPrimary)
                    .padding(10)
                    .background(DSColor.surface).clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSLayout.margin)
        .padding(.vertical, DSLayout.spacing)
    }
}

/// The collapsible advanced-filter row: sort/status/period menus, hide toggles, and a
/// clear-filters button. Shown only while `viewModel.filterRowVisible` is true.
public struct AdvancedFilterRow: View {
    /// The event-list view model whose sort/status/period/hide state this row drives.
    @Bindable private var viewModel: EventListViewModel
    /// Creates the row.
    /// - Parameter viewModel: The event-list view model to bind to.
    public init(viewModel: EventListViewModel) { self.viewModel = viewModel }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(EventListViewModel.MarketSort.options(for: viewModel.status), id: \.self) { s in
                        Button(s.title) { Task { await viewModel.setSort(s) } }
                    }
                } label: { DSMenuLabel(viewModel.sort.title, systemImage: "arrow.up.arrow.down") }

                Menu {
                    ForEach(EventListViewModel.MarketStatus.allCases, id: \.self) { s in
                        Button(s.title) { Task { await viewModel.setStatus(s) } }
                    }
                } label: { DSMenuLabel(viewModel.status.title, systemImage: "chevron.down") }

                Menu {
                    ForEach(EventListViewModel.MarketPeriod.allCases, id: \.self) { p in
                        Button(p.title) { Task { await viewModel.setPeriod(p) } }
                    }
                } label: { DSMenuLabel(viewModel.period.title, systemImage: "chevron.down") }

                hideToggle("Hide sports", isOn: viewModel.hideSports) { viewModel.toggleHideSports() }
                hideToggle("Hide crypto", isOn: viewModel.hideCrypto) { viewModel.toggleHideCrypto() }
                hideToggle("Hide earnings", isOn: viewModel.hideEarnings) { viewModel.toggleHideEarnings() }

                Button { Task { await viewModel.clearFilters() } } label: {
                    Text("Clear filter")
                        .font(DSFont.caption.bold())
                        .foregroundStyle(DSColor.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
    }

    /// A "checkbox + label" toggle button used for the hide-sports/crypto/earnings filters.
    private func hideToggle(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                Text(title)
            }
            .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
        }
        .buttonStyle(.plain)
    }
}

/// A capsule label (icon + text) used as the tappable label for the sort/status/period menus.
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
