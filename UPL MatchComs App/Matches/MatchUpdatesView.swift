//
//  MatchUpdatesView.swift
//  UPL MatchComs App
//

import SwiftUI

struct MatchUpdatesView: View {
    @State private var viewModel: MatchUpdatesViewModel

    init(match: LiveMatch) {
        _viewModel = State(initialValue: MatchUpdatesViewModel(match: match))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section("Scores") {
                ScoreField(
                    teamName: viewModel.homeTeamName,
                    score: $viewModel.homeScoreText
                )

                ScoreField(
                    teamName: viewModel.awayTeamName,
                    score: $viewModel.awayScoreText
                )
            }

            Section("Match status") {
                Picker("Status", selection: $viewModel.selectedMatchStatus) {
                    ForEach(MatchStatus.moderatorSelectableStatuses, id: \.self) { status in
                        Text(status.label)
                            .tag(status)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    Task {
                        await viewModel.updateMatchDetails()
                    }
                } label: {
                    if viewModel.isUpdatingMatch {
                        ProgressView("Updating match…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Update match")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isUpdatingMatch)

                if viewModel.didUpdateMatch {
                    Label("Match details updated.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let matchUpdateError = viewModel.matchUpdateError {
                    Text(matchUpdateError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Add match event") {
                Picker("Team", selection: $viewModel.selectedTeam) {
                    Text(viewModel.homeTeamName)
                        .tag(MatchEventTeam.home)

                    Text(viewModel.awayTeamName)
                        .tag(MatchEventTeam.away)
                }
                .pickerStyle(.menu)

                Picker("Player", selection: $viewModel.selectedPlayerID) {
                    if viewModel.isLoadingPlayers {
                        Text("Loading players…")
                            .tag(String?.none)
                    } else if viewModel.selectedTeamPlayers.isEmpty {
                        Text("No players available")
                            .tag(String?.none)
                    } else {
                        Text("Select player")
                            .tag(String?.none)

                        ForEach(viewModel.selectedTeamPlayers) { player in
                            Text(player.name)
                                .tag(Optional(player.id))
                        }
                    }
                }
                .pickerStyle(.menu)
                .disabled(
                    viewModel.isLoadingPlayers
                    || viewModel.selectedTeamPlayers.isEmpty
                )

                if let playerLoadingError = viewModel.playerLoadingError {
                    Text(playerLoadingError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                TextField("Minute", text: $viewModel.minuteText)
                    .keyboardType(.numberPad)

                Picker("Event type", selection: $viewModel.selectedEventType) {
                    ForEach(MatchEventType.allCases) { eventType in
                        Text(eventType.label)
                            .tag(eventType)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    Task {
                        await viewModel.addMatchEvent()
                    }
                } label: {
                    if viewModel.isAddingMatchEvent {
                        ProgressView("Adding event…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Add match event")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isAddingMatchEvent
                    || viewModel.isLoadingPlayers
                    || viewModel.selectedPlayerID == nil
                )

                if viewModel.didAddMatchEvent {
                    Label("Match event added.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                if let matchEventError = viewModel.matchEventError {
                    Text(matchEventError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Match events") {
                if viewModel.isLoadingMatchEvents {
                    ProgressView("Loading match events…")
                } else if let matchEventsError = viewModel.matchEventsError {
                    Text(matchEventsError)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if viewModel.matchEvents.isEmpty {
                    Text("No match events recorded.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.matchEvents) { event in
                        MatchEventRow(
                            isHomeEvent: event.home,
                            minute: event.minute,
                            playerName: event.name,
                            teamName: event.teamName,
                            type: event.type
                        )
                        .opacity(
                            viewModel.deletingEventIDs.contains(event.id)
                            ? 0.5
                            : 1
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteMatchEvent(event)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(viewModel.deletingEventIDs.contains(event.id))
                        }
                    }
                }

                if let matchEventDeletionError = viewModel.matchEventDeletionError {
                    Text(matchEventDeletionError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Match Updates")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadInitialData()
        }
    }
}

private struct ScoreField: View {
    let teamName: String
    @Binding var score: String

    var body: some View {
        LabeledContent {
            TextField("Score", text: $score)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 48)
        } label: {
            Text(teamName)
        }
    }
}

private struct MatchEventRow: View {
    let isHomeEvent: Bool
    let minute: String
    let playerName: String
    let teamName: String
    let type: String

    var body: some View {
        HStack {
            if isHomeEvent {
                eventDetails
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
                eventDetails
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var eventDetails: some View {
        VStack(alignment: isHomeEvent ? .leading : .trailing, spacing: 2) {
            HStack(spacing: 6) {
                if isHomeEvent {
                    eventIcon
                }

                Text("\(minute)′")
                    .font(.headline)

                Text(type)
                    .foregroundStyle(.secondary)

                if !isHomeEvent {
                    eventIcon
                }
            }

            Text(playerName)

            Text(teamName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var eventIcon: some View {
        if let assetName = assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: systemImageName)
                .font(.subheadline)
                .foregroundStyle(systemImageColor)
                .frame(width: 16, height: 16)
        }
    }

    private var normalizedType: String {
        type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var assetName: String? {
        switch normalizedType {
        case "goal", "penalty goal", "own goal":
            "goal"
        case "yellow", "yellow card":
            "yellow_card"
        case "second yellow":
            "second_yellow"
        default:
            nil
        }
    }

    private var systemImageName: String {
        switch normalizedType {
        case "red", "red card":
            "rectangle.fill"
        case "cancelled goal":
            "xmark.circle.fill"
        case "missed penalty":
            "xmark.circle.fill"
        default:
            "sportscourt.fill"
        }
    }

    private var systemImageColor: Color {
        switch normalizedType {
        case "red", "red card":
            .red
        case "cancelled goal", "missed penalty":
            .secondary
        default:
            .secondary
        }
    }
}

#Preview {
    MatchUpdatesView(
        match: LiveMatch(
            id: "preview-match",
            awayScore: 0,
            awayTeam: "Away team",
            awayTeamImageUrl: nil,
            awayTeamId: "away-team",
            homeScore: 0,
            homeTeam: "Home team",
            homeTeamImageUrl: nil,
            homeTeamId: "home-team",
            leagueId: "league",
            status: .notPlayed
        )
    )
}
