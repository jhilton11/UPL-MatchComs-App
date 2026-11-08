//
//  RemoteService.swift
//  UPL MatchComs App
//
//  Created by Yinka Ige on 22/09/2026.
//

import Foundation

struct RemoteQueryFilter: Hashable, Sendable {
    let field: String
    let value: String
}

protocol RemoteObservation {
    func cancel()
}

protocol RemoteService {
    func fetchData<T: Decodable>(from resourcePath: String) async throws -> T

    func fetchCollectionData<T: Decodable>(
        from resourcePath: String
    ) async throws -> [T]

    func fetchCollectionData<T: Decodable>(
        from resourcePath: String,
        dateField: String,
        equalTo dateValue: Date
    ) async throws -> [T]

    func fetchCollectionData<T: Decodable>(
        from resourcePath: String,
        matching filters: [RemoteQueryFilter]
    ) async throws -> [T]

    func observeCollectionData<T: Decodable>(
        from resourcePath: String,
        dateField: String,
        equalTo dateValue: Date,
        onChange: @escaping (Result<[T], Error>) -> Void
    ) throws -> any RemoteObservation

    func updateData<T: Encodable>(
        data: T,
        at resourcePath: String
    ) async throws

    func deleteData(at resourcePath: String) async throws

    func postData<T: Encodable>(
        data: T,
        to resourcePath: String
    ) async throws
}
