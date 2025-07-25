//
//  SecurityManager.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Foundation
import LocalAuthentication
import CryptoKit
import KeychainAccess

class SecurityManager: ObservableObject {
    private let keychain = Keychain(service: AppConfig.bundleIdentifier)
    private let encryptionKey = "FactCheckPro_Encryption_Key"
    
    @Published var isSecurityEnabled = false
    @Published var biometricType: BiometricType = .none
    @Published var isLocked = false
    
    enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID
        
        var displayName: String {
            switch self {
            case .none: return L("biometric_none")
            case .touchID: return L("biometric_touchid")
            case .faceID: return L("biometric_faceid")
            case .opticID: return L("biometric_opticid")
            }
        }
    }
    
    enum SecurityError: Error, LocalizedError {
        case biometricNotAvailable
        case biometricNotEnrolled
        case authenticationFailed
        case encryptionFailed
        case decryptionFailed
        case keychainError
        
        var errorDescription: String? {
            switch self {
            case .biometricNotAvailable:
                return L("security_error_biometric_unavailable")
            case .biometricNotEnrolled:
                return L("security_error_biometric_not_enrolled")
            case .authenticationFailed:
                return L("security_error_authentication_failed")
            case .encryptionFailed:
                return L("security_error_encryption_failed")
            case .decryptionFailed:
                return L("security_error_decryption_failed")
            case .keychainError:
                return L("security_error_keychain")
            }
        }
    }
    
    init() {
        setupSecurity()
        checkBiometricAvailability()
    }
    
    // MARK: - Public Methods
    
    func enableSecurity() async throws {
        try await authenticateUser()
        
        // Generate and store encryption key
        let key = generateEncryptionKey()
        try storeEncryptionKey(key)
        
        isSecurityEnabled = true
        UserDefaults.standard.set(true, forKey: "security_enabled")
    }
    
    func disableSecurity() async throws {
        try await authenticateUser()
        
        // Remove encryption key
        try keychain.remove(encryptionKey)
        
        isSecurityEnabled = false
        UserDefaults.standard.set(false, forKey: "security_enabled")
    }
    
    func authenticateUser() async throws {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    throw SecurityError.biometricNotAvailable
                case LAError.biometryNotEnrolled.rawValue:
                    throw SecurityError.biometricNotEnrolled
                default:
                    throw SecurityError.authenticationFailed
                }
            }
            throw SecurityError.biometricNotAvailable
        }
        
        let reason = L("security_authentication_reason")
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                isLocked = false
            } else {
                throw SecurityError.authenticationFailed
            }
        } catch {
            throw SecurityError.authenticationFailed
        }
    }
    
    func lockApp() {
        guard isSecurityEnabled else { return }
        isLocked = true
    }
    
    func unlockApp() async throws {
        guard isSecurityEnabled else { return }
        try await authenticateUser()
    }
    
    // MARK: - Data Encryption
    
    func encryptData<T: Codable>(_ data: T) throws -> Data {
        guard isSecurityEnabled else {
            return try JSONEncoder().encode(data)
        }
        
        guard let key = try getEncryptionKey() else {
            throw SecurityError.encryptionFailed
        }
        
        let jsonData = try JSONEncoder().encode(data)
        let sealedBox = try AES.GCM.seal(jsonData, using: key)
        
        guard let encryptedData = sealedBox.combined else {
            throw SecurityError.encryptionFailed
        }
        
        return encryptedData
    }
    
    func decryptData<T: Codable>(_ encryptedData: Data, type: T.Type) throws -> T {
        guard isSecurityEnabled else {
            return try JSONDecoder().decode(type, from: encryptedData)
        }
        
        guard let key = try getEncryptionKey() else {
            throw SecurityError.decryptionFailed
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        
        return try JSONDecoder().decode(type, from: decryptedData)
    }
    
    // MARK: - Secure Storage
    
    func storeSecureData<T: Codable>(_ data: T, forKey key: String) throws {
        let encryptedData = try encryptData(data)
        try keychain.set(encryptedData, key: key)
    }
    
    func retrieveSecureData<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let encryptedData = try keychain.getData(key) else {
            return nil
        }
        
        return try decryptData(encryptedData, type: type)
    }
    
    func removeSecureData(forKey key: String) throws {
        try keychain.remove(key)
    }
    
    // MARK: - Privacy Controls
    
    func enablePrivacyMode() {
        UserDefaults.standard.set(true, forKey: "privacy_mode_enabled")
        NotificationCenter.default.post(name: .privacyModeChanged, object: true)
    }
    
    func disablePrivacyMode() {
        UserDefaults.standard.set(false, forKey: "privacy_mode_enabled")
        NotificationCenter.default.post(name: .privacyModeChanged, object: false)
    }
    
    var isPrivacyModeEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "privacy_mode_enabled")
    }
    
    // MARK: - Data Anonymization
    
    func anonymizeStatement(_ statement: String) -> String {
        guard isPrivacyModeEnabled else { return statement }
        
        var anonymized = statement
        
        // Remove personal identifiers
        let patterns = [
            ("\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b", "[EMAIL]"), // Email
            ("\\b\\d{3}-\\d{3}-\\d{4}\\b", "[PHONE]"), // Phone number
            ("\\b\\d{3}-\\d{2}-\\d{4}\\b", "[SSN]"), // SSN
            ("\\b[A-Z][a-z]+ [A-Z][a-z]+\\b", "[NAME]") // Names (simple pattern)
        ]
        
        for (pattern, replacement) in patterns {
            anonymized = anonymized.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        
        return anonymized
    }
    
    // MARK: - Private Methods
    
    private func setupSecurity() {
        isSecurityEnabled = UserDefaults.standard.bool(forKey: "security_enabled")
        if isSecurityEnabled {
            isLocked = true
        }
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            return
        }
        
        switch context.biometryType {
        case .touchID:
            biometricType = .touchID
        case .faceID:
            biometricType = .faceID
        case .opticID:
            biometricType = .opticID
        default:
            biometricType = .none
        }
    }
    
    private func generateEncryptionKey() -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
    
    private func storeEncryptionKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        try keychain.set(keyData, key: encryptionKey)
    }
    
    private func getEncryptionKey() throws -> SymmetricKey? {
        guard let keyData = try keychain.getData(encryptionKey) else {
            return nil
        }
        return SymmetricKey(data: keyData)
    }
}

extension Notification.Name {
    static let privacyModeChanged = Notification.Name("privacyModeChanged")
}
