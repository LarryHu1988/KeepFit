import Foundation
import Security
import CryptoKit
import Combine

struct MealNutrition: Codable {
    let caloriesKcal: Double
    let proteinG: Double
    let fatG: Double
    let carbsG: Double
    var isValid: Bool { [caloriesKcal, proteinG, fatG, carbsG].allSatisfy { $0.isFinite && $0 >= 0 } }
}
struct MealNutritionSource: Codable {
    let id: String
    let name: String
    let url: String?
    let version: String
    let note: String
}
struct ModelMealItem: Codable, Identifiable {
    let id: String
    let name: String
    let originalPortion: String
    let consumedGrams: Double?
    let portionIsEstimate: Bool
    let nutritionBasis: String
    let nutritionSource: MealNutritionSource?
    let nutrientsPer100G: MealNutrition?
    let nutrients: MealNutrition?
    let includedInTotals: Bool
    let estimationNotes: [String]
}
struct ModelMealQuestion: Codable, Identifiable {
    let id: String
    let text: String
    let options: [String]
}
struct ModelMealUnderstanding: Codable {
    let mealTime: Date?
    let questions: [ModelMealQuestion]
    let warnings: [String]
}
struct ModelMealProvenance: Codable {
    let provider: String
    let baseModel: String
    let simulated: Bool
    let nutritionVersion: String
}
struct ModelMealDraft: Codable, Identifiable {
    let id: String
    let revision: Int
    let status: String
    let originalText: String
    let understanding: ModelMealUnderstanding
    let items: [ModelMealItem]
    let totals: MealNutrition?
    let totalsComplete: Bool
    let requiresEstimateAcceptance: Bool
    let recordId: String?
    let model: ModelMealProvenance
}
struct ModelMealRecord: Codable {
    let id: String
    let acceptedEstimates: Bool
    let snapshot: ModelMealDraft
}
private struct MealErrorEnvelope: Decodable { struct Detail: Decodable { let code: String?; let message: String }; let error: Detail }
private struct MealEmptyResponse: Decodable {}
struct MealAuthChallenge: Decodable { let id: String; let nonce: String }
private struct MealSession: Codable { let token: String; let expiresAt: Double; var userID: String? = nil }
struct MealModelError: LocalizedError {
    let message: String
    var statusCode: Int? = nil
    var errorDescription: String? { message }
}

@MainActor
final class MealModelClient: ObservableObject {
    @Published private(set) var authenticated = false
    let baseURL: URL?
    private var session: MealSession?
    var signedInUserID: String? { session?.userID }
    private let keychainAccount: String
    private let networking: URLSession

    init() {
        var address = Bundle.main.object(forInfoDictionaryKey: "KeepFitModelURL") as? String ?? ""
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["KEEPFIT_MODEL_URL"] { address = override }
        #endif
        let candidate = URL(string: address)
        #if DEBUG
        baseURL = candidate.flatMap { ($0.scheme == "https" || ($0.scheme == "http" && ["127.0.0.1", "localhost"].contains($0.host ?? ""))) ? $0 : nil }
        #else
        baseURL = candidate.flatMap { $0.scheme == "https" ? $0 : nil }
        #endif
        keychainAccount = "meal-service:" + (baseURL?.absoluteString ?? "unconfigured")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 65
        config.timeoutIntervalForResource = 90
        config.urlCache = nil
        networking = URLSession(configuration: config)
        session = loadSession()
        authenticated = (session?.expiresAt ?? 0) > Date().timeIntervalSince1970
        #if DEBUG
        if let token = ProcessInfo.processInfo.environment["KEEPFIT_MODEL_TEST_TOKEN"], !token.isEmpty {
            session = MealSession(token: token, expiresAt: Date().timeIntervalSince1970 + 3600)
            authenticated = true
        }
        #endif
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw MealModelError(message: "记录时间格式无效，请重新识别。")
        }
        return decoder
    }
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: [String: Any]? = nil, key: String? = nil, needsAuth: Bool = true) async throws -> T {
        guard let baseURL else { throw MealModelError(message: "饮食识别服务尚未配置，请使用完成部署后的 KeepFit 版本。") }
        if needsAuth && !authenticated { throw MealModelError(message: "请先使用 Apple 登录启用饮食识别。") }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if needsAuth, let token = session?.token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let key { request.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await networking.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw MealModelError(message: "服务暂时不可用。") }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { signOut() }
            let error = try? Self.decoder.decode(MealErrorEnvelope.self, from: data)
            let message: String
            if http.statusCode == 401 { message = localized("登录已过期，请重新使用 Apple 登录。", "Your session expired. Sign in with Apple again.") }
            else if ["provider_auth_failed", "provider_balance", "provider_model_unavailable"].contains(error?.error.code ?? "") {
                message = localized("饮食识别服务暂时不可用，请稍后再试。已有记录仍可查看。", "Meal recognition is temporarily unavailable. Existing records are still available.")
            } else { message = error?.error.message ?? localized("服务暂时不可用，请稍后重试。", "Service unavailable. Try again later.") }
            throw MealModelError(message: message, statusCode: http.statusCode)
        }
        return try Self.decoder.decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
    }
    func challenge() async throws -> MealAuthChallenge { try await request("v1/auth/challenge", method: "POST", needsAuth: false) }
    func signIn(identityToken: String, challenge: MealAuthChallenge, userID: String) async throws {
        let result: MealSession = try await request("v1/auth/apple", method: "POST", body: ["identity_token": identityToken, "challenge_id": challenge.id], needsAuth: false)
        var saved = result; saved.userID = userID
        try saveSession(saved)
        session = saved; authenticated = true
    }
    func deleteRemoteData() async throws {
        let _: MealEmptyResponse = try await request("v1/account", method: "DELETE")
        signOut()
    }
    func signOut() {
        session = nil; authenticated = false
        SecItemDelete(keychainQuery as CFDictionary)
    }
    private var keychainQuery: [String: Any] {
        [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:"com.larry.keepfit", kSecAttrAccount as String:keychainAccount]
    }
    private func loadSession() -> MealSession? {
        var query = keychainQuery; query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(MealSession.self, from: data)
    }
    private func saveSession(_ value: MealSession) throws {
        let data = try JSONEncoder().encode(value)
        var query = keychainQuery
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw MealModelError(message: "无法安全保存登录状态。") }
        } else if status != errSecSuccess { throw MealModelError(message: "无法安全保存登录状态。") }
    }

    static func logID(recordID: String, itemID: String) -> UUID {
        let bytes = Array(SHA256.hash(data: Data((recordID + ":" + itemID).utf8)).prefix(16))
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }
}
