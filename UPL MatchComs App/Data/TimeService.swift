//
//  TimeService.swift
//  UPL MatchComs App
//

import FirebaseFunctions
import Foundation

protocol TimeService {
    func currentDate() async throws -> Date
}

struct FirebaseTimeService: TimeService {
    func currentDate() async throws -> Date {
        do {
            let result = try await Functions.functions()
                .httpsCallable("getTime")
                .call()

            return try date(from: result.data)
        } catch let error as TimeServiceError {
            throw error
        } catch {
            throw TimeServiceError.functionCallFailed(error)
        }
    }

    private func date(from response: Any) throws -> Date {
        if let number = response as? NSNumber {
            return date(fromUnixTimestamp: number.doubleValue)
        }

        if let payload = response as? [String: Any] {
            guard let timestamp = payload["timestamp"] else {
                throw TimeServiceError.missingTimestamp(
                    receivedKeys: payload.keys.sorted().joined(separator: ", ")
                )
            }

            if let timestamp = timestamp as? String {
                return try date(fromISO8601Timestamp: timestamp)
            }

            if let timestamp = timestamp as? NSNumber {
                return date(fromUnixTimestamp: timestamp.doubleValue)
            }

            throw TimeServiceError.invalidTimestampValue(
                String(describing: type(of: timestamp))
            )
        }

        throw TimeServiceError.invalidResponse(
            expected: "a Unix timestamp number or a dictionary containing a timestamp field",
            received: String(describing: type(of: response))
        )
    }

    private func date(fromUnixTimestamp timestamp: TimeInterval) -> Date {
        let seconds = timestamp > 10_000_000_000 ? timestamp / 1_000 : timestamp
        return Date(timeIntervalSince1970: seconds)
    }

    private func date(fromISO8601Timestamp timestamp: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]

        guard let date = formatter.date(from: timestamp) else {
            throw TimeServiceError.invalidISO8601Timestamp(timestamp)
        }

        return date
    }
}

private enum TimeServiceError: LocalizedError {
    case functionCallFailed(Error)
    case invalidResponse(expected: String, received: String)
    case missingTimestamp(receivedKeys: String)
    case invalidTimestampValue(String)
    case invalidISO8601Timestamp(String)

    var errorDescription: String? {
        switch self {
        case .functionCallFailed(let underlyingError):
            let error = underlyingError as NSError
            return "getTime failed: \(error.localizedDescription) [domain: \(error.domain), code: \(error.code)]."

        case .invalidResponse(let expected, let received):
            return "getTime returned \(received), but expected \(expected)."

        case .missingTimestamp(let receivedKeys):
            return "getTime did not return a timestamp. Received keys: \(receivedKeys)."

        case .invalidTimestampValue(let received):
            return "getTime returned a timestamp with unsupported type \(received)."

        case .invalidISO8601Timestamp(let timestamp):
            return "getTime returned an invalid ISO-8601 timestamp: \(timestamp)."
        }
    }
}
