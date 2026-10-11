import SwiftUI
import DuplixCore

public struct MainView: View {
    @StateObject private var dashboardViewModel = ClonesDashboardViewModel()
    @StateObject private var scannerViewModel = AppScannerViewModel()

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .frame(minWidth: 860, minHeight: 580)
    }

    private var sidebarContent: some View {
        List(selection: $dashboardViewModel.selectedSection) {
            Section("Workspace") {
                NavigationLink(value: NavigationSection.clones) {
                    Label {
                        HStack {
                            Text(NavigationSection.clones.rawValue)
                            Spacer()
                            if !dashboardViewModel.clones.isEmpty {
                                Text("\(dashboardViewModel.clones.count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: NavigationSection.clones.icon)
                    }
                }

                NavigationLink(value: NavigationSection.scanner) {
                    Label(NavigationSection.scanner.rawValue, systemImage: NavigationSection.scanner.icon)
                }
            }

            Section("System") {
                NavigationLink(value: NavigationSection.about) {
                    Label(NavigationSection.about.rawValue, systemImage: NavigationSection.about.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch dashboardViewModel.selectedSection {
        case .clones:
            ClonesDashboardView(
                viewModel: dashboardViewModel,
                onBrowseAppsRequested: {
                    dashboardViewModel.selectedSection = .scanner
                }
            )
        case .scanner:
            AppScannerView(
                viewModel: scannerViewModel,
                onCloneCreated: {
                    Task {
                        await dashboardViewModel.loadClones()
                        dashboardViewModel.selectedSection = .clones
                    }
                }
            )
        case .about:
            AboutView()
        }
    }
}
