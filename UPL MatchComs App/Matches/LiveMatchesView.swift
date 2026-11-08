//
//  LiveMatchesView.swift
//  UPL MatchComs App
//

import SwiftUI

struct LiveMatchesView: View {
    @State private var viewModel = LiveMatchesViewModel()

    var body: some View {
        NavigationStack {
            LiveMatchesContent(
                matches: viewModel.matches,
                isLoading: viewModel.isLoading,
                errorMessage: viewModel.errorMessage,
                retry: {
                    Task {
                        await viewModel.loadMatches()
                    }
                }
            )
            .navigationTitle("Today's Matches")
            .task {
                await viewModel.loadMatches()
            }
            .refreshable {
                await viewModel.loadMatches()
            }
            .onDisappear {
                viewModel.stopObservingMatches()
            }
        }
    }
}

private struct LiveMatchesContent: View {
    let matches: [LiveMatch]
    let isLoading: Bool
    let errorMessage: String?
    let retry: () -> Void

    var body: some View {
        if isLoading && matches.isEmpty {
            ProgressView("Loading live matches…")
        } else if let errorMessage {
            ContentUnavailableView {
                Label("Unable to load matches", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Try again", action: retry)
            }
        } else if matches.isEmpty {
            ContentUnavailableView(
                "No live matches",
                systemImage: "sportscourt",
                description: Text("There are no live matches at the moment.")
            )
        } else {
            List(matches) { match in
                NavigationLink {
                    MatchUpdatesView(match: match)
                } label: {
                    LiveMatchRow(match: match)
                }
            }
        }
    }
}

private struct LiveMatchRow: View {
    let match: LiveMatch

    private var displaysPendingScores: Bool {
        switch match.status {
        case .notPlayed?, .abandoned?, .postponed?:
            return true
        default:
            return false
        }
    }

    private var homeScoreText: String {
        displaysPendingScores ? "?" : match.homeScore.map(String.init) ?? "–"
    }

    private var awayScoreText: String {
        displaysPendingScores ? "?" : match.awayScore.map(String.init) ?? "–"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(match.homeTeam ?? "Home team")
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)

            TeamLogoView(imageURL: match.homeTeamImageUrl)

            Text(homeScoreText)
                .fontWeight(.semibold)

            Text("–")
                .foregroundStyle(.secondary)

            Text(awayScoreText)
                .fontWeight(.semibold)

            TeamLogoView(imageURL: match.awayTeamImageUrl)

            Text(match.awayTeam ?? "Away team")
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

private struct TeamLogoView: View {
    let imageURL: String?

    var body: some View {
        AsyncImage(url: imageURL.flatMap(URL.init(string:))) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
        .background(.quaternary, in: Circle())
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

#Preview {
    LiveMatchesView()
}
