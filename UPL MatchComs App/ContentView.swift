//
//  ContentView.swift
//  UPL MatchComs App
//
//  Created by Yinka Ige on 22/09/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var loginViewModel = LoginViewModel()
    @State private var selectedTab = AppTab.home

    var body: some View {
        if loginViewModel.isAuthenticated {
            selectedTab.content(loginViewModel: loginViewModel)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    AppTabBar(selectedTab: $selectedTab)
                }
        } else {
            LoginView(viewModel: loginViewModel)
        }
    }
}

private enum AppTab {
    case home
    case more

    @ViewBuilder
    func content(loginViewModel: LoginViewModel) -> some View {
        switch self {
        case .home:
            LiveMatchesView()
        case .more:
            MoreView(loginViewModel: loginViewModel)
        }
    }
}

private struct AppTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                tabButton(for: .home, title: "Home", systemImage: "house")
                tabButton(for: .more, title: "More", systemImage: "ellipsis.circle")
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea(edges: .bottom))
    }

    private func tabButton(for tab: AppTab, title: String, systemImage: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.body)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}

private struct MoreView: View {
    let loginViewModel: LoginViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Sign Out", role: .destructive) {
                        loginViewModel.signOut()
                    }
                }
            }
            .navigationTitle("More")
            .alert(
                "Unable to sign out",
                isPresented: Binding(
                    get: { loginViewModel.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            loginViewModel.dismissError()
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    loginViewModel.dismissError()
                }
            } message: {
                Text(loginViewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    ContentView()
}
