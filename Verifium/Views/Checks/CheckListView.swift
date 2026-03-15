import SwiftUI

struct CheckListView: View {
    @ObservedObject var vm: AuditViewModel
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    @State private var navigationPath = NavigationPath()
    @State private var isTransitioning = false

    enum FilterOption: String, CaseIterable {
        case all      = "filter.all"
        case failing  = "filter.failing"
        case pending  = "filter.pending"
        case passing  = "filter.passing"

        var localizedLabel: String { NSLocalizedString(rawValue, comment: "") }
    }

    var filteredGrouped: [(category: CheckCategory, checks: [SecurityCheck])] {
        vm.checksByCategory.compactMap { group in
            let filtered = group.checks.filter { check in
                let matchesSearch = searchText.isEmpty ||
                    check.title.localizedCaseInsensitiveContains(searchText)
                let matchesFilter: Bool = {
                    switch selectedFilter {
                    case .all:     return true
                    case .failing: return check.status.isFailing
                    case .pending: return check.status == .manualRequired
                    case .passing: return check.status.isPassing
                    }
                }()
                return matchesSearch && matchesFilter
            }
            return filtered.isEmpty ? nil : (category: group.category, checks: filtered)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter pills
                    filterBar
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                    // List
                    if filteredGrouped.isEmpty {
                        emptyState
                    } else {
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                LazyVStack(spacing: 20, pinnedViews: .sectionHeaders) {
                                    ForEach(filteredGrouped, id: \.category.id) { group in
                                        Section {
                                            VStack(spacing: 10) {
                                                ForEach(group.checks) { check in
                                                    NavigationLink(value: check.id) {
                                                        CheckRowView(check: check)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                        } header: {
                                            CategoryHeader(category: group.category, checks: group.checks)
                                                .id(group.category)
                                        }
                                    }
                                    Spacer(minLength: 32)
                                }
                                .padding(.top, 4)
                            .allowsHitTesting(!isTransitioning)
                            }
                            .onAppear {
                                if let category = vm.scrollToCategory {
                                    // Delay to let the layout settle on first appearance
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 150_000_000)
                                        withAnimation(.easeOut(duration: 0.4)) {
                                            scrollProxy.scrollTo(category, anchor: .top)
                                        }
                                        vm.scrollToCategory = nil
                                    }
                                }
                            }
                            .onChange(of: vm.scrollToCategory) { _, category in
                                guard let category else { return }
                                withAnimation(.easeOut(duration: 0.4)) {
                                    scrollProxy.scrollTo(category, anchor: .top)
                                }
                                vm.scrollToCategory = nil
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("tab.checks", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText,
                        prompt: NSLocalizedString("checks.search", comment: ""))
            .navigationDestination(for: String.self) { checkId in
                if let check = vm.check(id: checkId) {
                    CheckDetailView(check: check, vm: vm) {
                        navigateToNextManualCheck(after: checkId)
                    }
                }
            }
        }
        .onChange(of: vm.completionTrigger) { _, trigger in
            guard trigger != nil else { return }
            // Clear the navigation stack when switching to dashboard
            navigationPath = NavigationPath()
        }
        .onChange(of: vm.navigateToCheckId) { _, checkId in
            guard let checkId else { return }
            // Clear stack first, then push the target check
            navigationPath = NavigationPath()
            navigationPath.append(checkId)
            vm.navigateToCheckId = nil
        }
    }

    // MARK: - Auto-navigation

    private func navigateToNextManualCheck(after checkId: String) {
        guard vm.pendingCount > 0,
              let nextId = vm.nextManualCheckId(after: checkId) else {
            // No more pending — just pop back
            if !navigationPath.isEmpty {
                navigationPath.removeLast()
            }
            return
        }
        // Block interactions during the transition
        isTransitioning = true
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            navigationPath.append(nextId)
            isTransitioning = false
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterOption.allCases, id: \.self) { option in
                    FilterPill(label: option.localizedLabel,
                               isSelected: selectedFilter == option) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = option
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary)
            Text(NSLocalizedString("checks.no_results", comment: ""))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? AppColors.background : AppColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.teal : AppColors.cardBg)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.clear : AppColors.cardBorder, lineWidth: 1)
                        )
                )
        }
    }
}

// MARK: - Category Header

struct CategoryHeader: View {
    let category: CheckCategory
    let checks: [SecurityCheck]

    private var passing: Int { checks.filter { $0.status.isPassing }.count }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(category.accentColor)

            Text(category.localizedTitle.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(AppColors.textSecondary)
                .tracking(2)

            Spacer()

            Text("\(passing)/\(checks.count)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(AppColors.background)
    }
}
