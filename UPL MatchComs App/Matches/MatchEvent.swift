//
//  MatchEvent.swift
//  UPL MatchComs App
//

import Foundation

struct MatchEvent: Decodable, Identifiable, Equatable {
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

    var minuteNumber: Int {
        Int(minute) ?? 0
    }
}
