//
//  LiveMatchesViewModel.swift
//  UPL MatchComs App
//

import Foundation
import Observation

@MainActor
@Observable
final class LiveMatchesViewModel {
    private let collectionPath: String
    private let dateField: String
    private let remoteService: RemoteService
    private let timeService: TimeService

    @ObservationIgnored private var matchObservation: (any RemoteObservation)?

    private(set) var matches: [LiveMatch] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var currentDate: Date?

    init(
        collectionPath: String = "matches",
        dateField: String = "date",
        remoteService: RemoteService = FirebaseService.shared,
        timeService: TimeService = FirebaseTimeService()
    ) {
        self.collectionPath = collectionPath
        self.dateField = dateField
        self.remoteService = remoteService
        self.timeService = timeService
    }

    func loadMatches() async {
        isLoading = true
        errorMessage = nil
        matchObservation?.cancel()

        do {
            let trustedDate = try await timeService.currentDate()
            let calendar = Calendar.autoupdatingCurrent
            let dateValue = calendar.startOfDay(for: trustedDate)

            currentDate = trustedDate
            matchObservation = try remoteService.observeCollectionData(
                from: collectionPath,
                dateField: dateField,
                equalTo: dateValue
            ) { [weak self] (result: Result<[LiveMatch], Error>) in
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }

                    self.isLoading = false

                    switch result {
                    case .success(let matches):
                        self.matches = matches
                        self.errorMessage = nil

                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func stopObservingMatches() {
        matchObservation?.cancel()
        matchObservation = nil
    }
}

