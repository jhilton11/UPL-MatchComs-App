//
//  FirebaseService.swift
//  UPL MatchComs App
//

import Foundation
import FirebaseCore
import FirebaseFirestore

private var firestore: Firestore!

enum FirebaseRemoteServiceError: LocalizedError {
    case invalidDocumentPath(String)
    case invalidCollectionPath(String)
    case documentNotFound(String)
    case operationFailed(operation: String, resourcePath: String, underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .invalidDocumentPath(let resourcePath):
            return "Invalid Firestore document path: \(resourcePath). A document path must contain an even number of path components."

        case .invalidCollectionPath(let resourcePath):
            return "Invalid Firestore collection path: \(resourcePath). A collection path must contain an odd number of path components."

        case .documentNotFound(let resourcePath):
            return "Firestore document was not found at \(resourcePath)."

        case .operationFailed(let operation, let resourcePath, let underlyingError):
            let error = underlyingError as NSError
            return "\(operation) failed for Firestore path \(resourcePath): \(error.localizedDescription) [domain: \(error.domain), code: \(error.code)]."
        }
    }
}

final class FirebaseService: RemoteService {
    static let shared = FirebaseService()

    private init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        firestore = Firestore.firestore()
    }

    func updateData<T: Encodable>(
        data: T,
        at resourcePath: String
    ) async throws {
        let document = try documentReference(for: resourcePath)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    try document.setData(from: data, merge: true) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            throw contextualized(
                error,
                operation: "Update",
                resourcePath: resourcePath
            )
        }
    }

    func deleteData(at resourcePath: String) async throws {
        let document = try documentReference(for: resourcePath)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                document.delete { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            throw contextualized(
                error,
                operation: "Delete",
                resourcePath: resourcePath
            )
        }
    }

    func postData<T: Encodable>(
        data: T,
        to resourcePath: String
    ) async throws {
        let document = try documentReference(for: resourcePath)

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    try document.setData(from: data) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } catch {
            throw contextualized(
                error,
                operation: "Write",
                resourcePath: resourcePath
            )
        }
    }

    func fetchData<T: Decodable>(from resourcePath: String) async throws -> T {
        let document = try documentReference(for: resourcePath)

        do {
            let snapshot = try await document.getDocument()

            guard snapshot.exists else {
                throw FirebaseRemoteServiceError.documentNotFound(resourcePath)
            }

            return try snapshot.data(as: T.self)
        } catch {
            throw contextualized(
                error,
                operation: "Read document",
                resourcePath: resourcePath
            )
        }
    }

    func fetchCollectionData<T: Decodable>(
        from resourcePath: String
    ) async throws -> [T] {
        let collection = try collectionReference(for: resourcePath)

        do {
            let snapshot = try await collection.getDocuments()

            return try snapshot.documents.map { document in
                do {
                    return try document.data(as: T.self)
                } catch {
                    throw FirebaseRemoteServiceError.operationFailed(
                        operation: "Decode collection document",
                        resourcePath: "\(resourcePath)/\(document.documentID)",
                        underlyingError: error
                    )
                }
            }
        } catch {
            throw contextualized(
                error,
                operation: "Read collection",
                resourcePath: resourcePath
            )
        }
    }

    func fetchCollectionData<T: Decodable>(
        from resourcePath: String,
        dateField: String,
        equalTo dateValue: Date
    ) async throws -> [T] {
        let collection = try collectionReference(for: resourcePath)

        do {
            let snapshot = try await collection
                .whereField(dateField, isEqualTo: dateValue)
                .getDocuments()

            return try decodeDocuments(
                snapshot,
                collectionPath: resourcePath
            )
        } catch {
            throw contextualized(
                error,
                operation: "Read collection for date",
                resourcePath: resourcePath
            )
        }
    }

    func fetchCollectionData<T: Decodable>(
        from resourcePath: String,
        matching filters: [RemoteQueryFilter]
    ) async throws -> [T] {
        let collection = try collectionReference(for: resourcePath)
        var query: Query = collection

        for filter in filters {
            query = query.whereField(filter.field, isEqualTo: filter.value)
        }

        do {
            let snapshot = try await query.getDocuments()

            return try decodeDocuments(
                snapshot,
                collectionPath: resourcePath
            )
        } catch {
            throw contextualized(
                error,
                operation: "Read filtered collection",
                resourcePath: resourcePath
            )
        }
    }

    func observeCollectionData<T: Decodable>(
        from resourcePath: String,
        dateField: String,
        equalTo dateValue: Date,
        onChange: @escaping (Result<[T], Error>) -> Void
    ) throws -> any RemoteObservation {
        let collection = try collectionReference(for: resourcePath)

        let registration = collection
            .whereField(dateField, isEqualTo: dateValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else {
                    return
                }

                if let error {
                    onChange(
                        .failure(
                            self.contextualized(
                                error,
                                operation: "Observe collection for date",
                                resourcePath: resourcePath
                            )
                        )
                    )
                    return
                }

                guard let snapshot else {
                    let missingSnapshotError = NSError(
                        domain: "FirebaseService",
                        code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Firestore returned no snapshot and no error."
                        ]
                    )

                    onChange(
                        .failure(
                            self.contextualized(
                                missingSnapshotError,
                                operation: "Observe collection for date",
                                resourcePath: resourcePath
                            )
                        )
                    )
                    return
                }

                do {
                    let documents: [T] = try self.decodeDocuments(
                        snapshot,
                        collectionPath: resourcePath
                    )
                    onChange(.success(documents))
                } catch {
                    onChange(.failure(error))
                }
            }

        return FirebaseCollectionObservation(registration: registration)
    }

    private func decodeDocuments<T: Decodable>(
        _ snapshot: QuerySnapshot,
        collectionPath: String
    ) throws -> [T] {
        try snapshot.documents.map { document in
            do {
                return try document.data(as: T.self)
            } catch {
                throw FirebaseRemoteServiceError.operationFailed(
                    operation: "Decode collection document",
                    resourcePath: "\(collectionPath)/\(document.documentID)",
                    underlyingError: error
                )
            }
        }
    }

    private func documentReference(for resourcePath: String) throws -> DocumentReference {
        let components = pathComponents(in: resourcePath)

        guard !components.isEmpty, components.count.isMultiple(of: 2) else {
            throw FirebaseRemoteServiceError.invalidDocumentPath(resourcePath)
        }

        return firestore.document(resourcePath)
    }

    private func collectionReference(for resourcePath: String) throws -> CollectionReference {
        let components = pathComponents(in: resourcePath)

        guard !components.isEmpty, !components.count.isMultiple(of: 2) else {
            throw FirebaseRemoteServiceError.invalidCollectionPath(resourcePath)
        }

        return firestore.collection(resourcePath)
    }

    private func pathComponents(in resourcePath: String) -> [Substring] {
        resourcePath.split(separator: "/", omittingEmptySubsequences: true)
    }

    private func contextualized(
        _ error: Error,
        operation: String,
        resourcePath: String
    ) -> Error {
        if error is FirebaseRemoteServiceError {
            return error
        }

        return FirebaseRemoteServiceError.operationFailed(
            operation: operation,
            resourcePath: resourcePath,
            underlyingError: error
        )
    }
}
private final class FirebaseCollectionObservation: RemoteObservation {
    private var registration: ListenerRegistration?

    init(registration: ListenerRegistration) {
        self.registration = registration
    }

    func cancel() {
        registration?.remove()
        registration = nil
    }

    deinit {
        cancel()
    }
}

