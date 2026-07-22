import Foundation

/// The minimal key-value surface `Preferences` needs. `UserDefaults` satisfies
/// it as-is; tests inject an in-memory double so persistence logic is verifiable
/// without touching the real defaults database.
public protocol PreferenceStore: AnyObject {
    func data(forKey defaultName: String) -> Data?
    func double(forKey defaultName: String) -> Double
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

extension UserDefaults: PreferenceStore {}
