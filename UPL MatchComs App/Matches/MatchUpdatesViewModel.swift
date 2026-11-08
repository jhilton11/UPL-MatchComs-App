//
//  MatchUpdatesViewModel.swift
//  UPL MatchComs App
//

import Foundation
import Observation

enum MatchEventTeam: CaseIterable, Identifiable {
    case home
    case away

    var id: Self {
        self
    }
}

enum MatchEventType: CaseIterable, Identifiable {
    case yellowCard
    case goal
    case cancelledGoal
    case redCard
    case secondYellow
    case missedPenalty
    case penaltyGoal
    case ownGoal

    var id: Self {
        self
    }

    var label: LocalizedStringResource {
        switch self {
        case .yellowCard:
            return "Yellow card"
        case .goal:
            return "Goal"
        case .cancelledGoal:
            return "Cancelled goal"
        case .redCard:
            return "Red card"
        case .secondYellow:
            return "Second yellow"
        case .missedPenalty:
            return "Missed penalty"
        case .penaltyGoal:
            return "Penalty goal"
        case .ownGoal:
            return "Own goal"
        }
    }

    var statType: String {
        switch self {
        case .yellowCard:
            return "yellow"
        case .goal:
            return "goal"
        case .cancelledGoal:
            return "cancelled goal"
        case .redCard:
            return "red"
        case .secondYellow:
            return "second yellow"
        case .missedPenalty:
            return "missed penalty"
        case .penaltyGoal:
            return "penalty goal"
        case .ownGoal:
            return "own goal"
        }
    }
}

struct LeaguePlayer: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let imageUrl: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case playerId
        case name
        case playerName
        case fullName
        case imageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        guard let name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .playerName)
            ?? container.decodeIfPresent(String.self, forKey: .fullName) else {
            throw DecodingError.keyNotFound(
                CodingKeys.name,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected a player name in name, playerName, or fullName."
                )
            )
        }

        self.name = name
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .playerId)
            ?? name
    }
}

private struct MatchDetailsUpdate: Encodable {
    let homeScore: Int
    let awayScore: Int
    let status: String
}

private struct MatchEventPayload: Encodable {
    let home: Bool
    let id: String
    let leagueId: String
    let matchId: String
    let matchTitle: String
    let minute: String
    let name: String
    let playerId: String
    let playerImageUrl: String?
    let teamId: String
    let teamName: String
    let type: String
}

private enum MatchUpdatesError: LocalizedError {
    case missingMatchID
    case missingMatchInformation
    case invalidScore
    case invalidMinute
    case playerNotSelected

    var errorDescription: String? {
        switch self {
        case .missingMatchID:
            return "This match has no document ID to update."
        case .missingMatchInformation:
            return "This match is missing information needed to add an event."
        case .invalidScore:
            return "Scores must be whole numbers greater than or equal to zero."
        case .invalidMinute:
            return "Enter a valid match minute."
        case .playerNotSelected:
            return "Choose a player before adding the event."
        }
    }
}

@MainActor
@Observable
final class MatchUpdatesViewModel {
    private let playersCollectionPath = "league_players"
    private let statsCollectionPath = "stats"
    private let remoteService: RemoteService
    private let leagueId: String?
    private let homeTeamId: String?
    private let awayTeamId: String?

    let matchID: String?
    let homeTeamName: String
    let awayTeamName: String

    var homeScoreText: String
    var awayScoreText: String
    var selectedMatchStatus: MatchStatus
    var selectedTeam: MatchEventTeam = .home {
        didSet {
            selectedPlayerID = nil
        }
    }
    var selectedPlayerID: String?
    var minuteText = ""
    var selectedEventType: MatchEventType = .goal

    private(set) var isLoadingPlayers = false
    private(set) var playerLoadingError: String?
    private(set) var isUpdatingMatch = false
    private(set) var matchUpdateError: String?
    private(set) var didUpdateMatch = false
    private(set) var isLoadingMatchEvents = false
    private(set) var matchEventsError: String?
    private(set) var isAddingMatchEvent = false
    private(set) var matchEventError: String?
    private(set) var didAddMatchEvent = false
    private(set) var deletingEventIDs: Set<String> = []
    private(set) var matchEventDeletionError: String?
    private(set) var matchEvents: [MatchEvent] = []

    private var homePlayers: [LeaguePlayer] = []
    private var awayPlayers: [LeaguePlayer] = []

    var selectedTeamPlayers: [LeaguePlayer] {
        switch selectedTeam {
        case .home:
            return homePlayers
        case .away:
            return awayPlayers
        }
    }

    private var selectedPlayer: LeaguePlayer? {
        guard let selectedPlayerID else {
            return nil
        }

        return selectedTeamPlayers.first { $0.id == selectedPlayerID }
    }

    init(
        match: LiveMatch,
        remoteService: RemoteService = FirebaseService.shared
    ) {
        self.remoteService = remoteService
        matchID = match.id
        leagueId = match.leagueId
        homeTeamId = match.homeTeamId
        awayTeamId = match.awayTeamId
        homeTeamName = match.homeTeam ?? "Home team"
        awayTeamName = match.awayTeam ?? "Away team"
        homeScoreText = String(match.homeScore ?? 0)
        awayScoreText = String(match.awayScore ?? 0)

        let matchStatus = match.status ?? .notPlayed
        selectedMatchStatus = MatchStatus.moderatorSelectableStatuses.contains(matchStatus)
            ? matchStatus
            : .notPlayed
    }

    func loadInitialData() async {
        await loadPlayers()
        await loadMatchEvents()
    }

    func loadPlayers() async {
        guard let leagueId, let homeTeamId, let awayTeamId else {
            playerLoadingError = "This match is missing the league or team IDs needed to load players."
            return
        }

        isLoadingPlayers = true
        playerLoadingError = nil
        defer { isLoadingPlayers = false }

        do {
            let homePlayers: [LeaguePlayer] = try await remoteService.fetchCollectionData(
                from: playersCollectionPath,
                matching: [
                    RemoteQueryFilter(field: "currentLeague", value: leagueId),
                    RemoteQueryFilter(field: "teamId", value: homeTeamId)
                ]
            )

            let awayPlayers: [LeaguePlayer] = try await remoteService.fetchCollectionData(
                from: playersCollectionPath,
                matching: [
                    RemoteQueryFilter(field: "currentLeague", value: leagueId),
                    RemoteQueryFilter(field: "teamId", value: awayTeamId)
                ]
            )

            self.homePlayers = homePlayers.sorted { $0.name < $1.name }
            self.awayPlayers = awayPlayers.sorted { $0.name < $1.name }
        } catch {
            playerLoadingError = error.localizedDescription
        }
    }

    func loadMatchEvents() async {
        guard let matchID, !matchID.isEmpty else {
            matchEventsError = MatchUpdatesError.missingMatchID.localizedDescription
            return
        }

        isLoadingMatchEvents = true
        matchEventsError = nil
        defer { isLoadingMatchEvents = false }

        do {
            let events: [MatchEvent] = try await remoteService.fetchCollectionData(
                from: statsCollectionPath,
                matching: [RemoteQueryFilter(field: "matchId", value: matchID)]
            )

            matchEvents = events.sorted { lhs, rhs in
                if lhs.minuteNumber == rhs.minuteNumber {
                    return lhs.id < rhs.id
                }

                return lhs.minuteNumber < rhs.minuteNumber
            }
        } catch {
            matchEventsError = error.localizedDescription
        }
    }

    func updateMatchDetails() async {
        guard let matchID, !matchID.isEmpty else {
            matchUpdateError = MatchUpdatesError.missingMatchID.localizedDescription
            return
        }

        guard let homeScore = Int(homeScoreText), homeScore >= 0,
              let awayScore = Int(awayScoreText), awayScore >= 0 else {
            matchUpdateError = MatchUpdatesError.invalidScore.localizedDescription
            return
        }

        isUpdatingMatch = true
        matchUpdateError = nil
        didUpdateMatch = false
        defer { isUpdatingMatch = false }

        let update = MatchDetailsUpdate(
            homeScore: homeScore,
            awayScore: awayScore,
            status: selectedMatchStatus.firestoreValue
        )

        do {
            try await remoteService.updateData(
                data: update,
                at: "matches/\(matchID)"
            )
            didUpdateMatch = true
        } catch {
            matchUpdateError = error.localizedDescription
        }
    }

    func deleteMatchEvent(_ event: MatchEvent) async {
        guard !event.id.isEmpty, !deletingEventIDs.contains(event.id) else {
            return
        }

        deletingEventIDs.insert(event.id)
        matchEventDeletionError = nil
        defer { deletingEventIDs.remove(event.id) }

        do {
            try await remoteService.deleteData(
                at: "\(statsCollectionPath)/\(event.id)"
            )
            matchEvents.removeAll { $0.id == event.id }
        } catch {
            matchEventDeletionError = error.localizedDescription
        }
    }

    func addMatchEvent() async {
        guard let matchID, !matchID.isEmpty,
              let leagueId,
              let homeTeamId,
              let awayTeamId else {
            matchEventError = MatchUpdatesError.missingMatchInformation.localizedDescription
            return
        }

        let minute = minuteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let minuteNumber = Int(minute), minuteNumber >= 0 else {
            matchEventError = MatchUpdatesError.invalidMinute.localizedDescription
            return
        }

        guard let selectedPlayer else {
            matchEventError = MatchUpdatesError.playerNotSelected.localizedDescription
            return
        }

        let eventID = UUID().uuidString
        let isHomeTeam = selectedTeam == .home
        let teamID = isHomeTeam ? homeTeamId : awayTeamId
        let teamName = isHomeTeam ? homeTeamName : awayTeamName
        let matchTitle = "\(homeTeamName) \(homeScoreText) vs \(awayScoreText) \(awayTeamName)"
        let event = MatchEventPayload(
            home: isHomeTeam,
            id: eventID,
            leagueId: leagueId,
            matchId: matchID,
            matchTitle: matchTitle,
            minute: minute,
            name: selectedPlayer.name,
            playerId: selectedPlayer.id,
            playerImageUrl: selectedPlayer.imageUrl,
            teamId: teamID,
            teamName: teamName,
            type: selectedEventType.statType
        )

        isAddingMatchEvent = true
        matchEventError = nil
        didAddMatchEvent = false
        defer { isAddingMatchEvent = false }

        do {
            try await remoteService.postData(
                data: event,
                to: "\(statsCollectionPath)/\(eventID)"
            )
            didAddMatchEvent = true
            minuteText = ""
            selectedPlayerID = nil
            await loadMatchEvents()
        } catch {
            matchEventError = error.localizedDescription
        }
    }
}
