//
//  LiveMatch.swift
//  UPL MatchComs App
//

import Foundation

struct LiveMatch: Decodable, Identifiable, Equatable {
    let id: String?
    let awayScore: Int?
    let awayTeam: String?
    let awayTeamImageUrl: String?
    let awayTeamId: String?
    let homeScore: Int?
    let homeTeam: String?
    let homeTeamImageUrl: String?
    let homeTeamId: String?
    let leagueId: String?
    let status: MatchStatus?
}

enum MatchStatus: Decodable, Equatable, Hashable {
    case played
    case notPlayed
    case abandoned
    case postponed
    case live
    case halfTime
    case unknown(String)

    static let moderatorSelectableStatuses: [MatchStatus] = [
        .notPlayed,
        .live,
        .halfTime,
        .played,
        .abandoned,
        .postponed
    ]

    var firestoreValue: String {
        switch self {
        case .played:
            return "played"
        case .notPlayed:
            return "not played"
        case .abandoned:
            return "abandoned"
        case .postponed:
            return "postponed"
        case .live:
            return "live"
        case .halfTime:
            return "half time"
        case .unknown(let value):
            return value
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .played:
            return "Played"
        case .notPlayed:
            return "Not played"
        case .abandoned:
            return "Abandoned"
        case .postponed:
            return "Postponed"
        case .live:
            return "Live"
        case .halfTime:
            return "Half time"
        case .unknown:
            return "Unknown"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        let normalizedValue = rawValue
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacing("-", with: "")
            .replacing(" ", with: "")

        switch normalizedValue {
        case "played":
            self = .played
        case "notplayed":
            self = .notPlayed
        case "abandoned":
            self = .abandoned
        case "postponed":
            self = .postponed
        case "live":
            self = .live
        case "halftime":
            self = .halfTime
        default:
            self = .unknown(rawValue)
        }
    }
}
