import Foundation
import StrandSync

/// Bridges `ProfileStore` + the display-driving UserDefaults prefs to the Local Sync settings mirror:
/// the iPhone encodes `current(...)`; the Mac `apply(...)`s a relayed payload into its own stores so every
/// existing `@AppStorage`/`ProfileStore` reader (Fitness Age, Vitality, HR zones, units, key-metrics) works
/// with no view changes. The Mac's own settings are backed up on first apply and restored on unpair.
@MainActor
enum SyncSettingsBridge {
    private static let d = UserDefaults.standard
    private static let unitsSystemKey = "units.system"
    private static let unitsTempKey = "units.temperature"
    private static let effortScaleKey = "effort.scale"
    private static let keyMetricsKey = "today.keyMetrics"
    private static let cycleKey = "noopCycleAwareness"
    private static let hydrationKey = "noop.hydrationTracking"
    private static let backupKey = "localsync.settingsBackup"

    /// Build this device's current settings payload (iPhone source).
    static func current(profile: ProfileStore) -> SyncSettings {
        SyncSettings(
            age: profile.age, sex: profile.sex, weightKg: profile.weightKg, heightCm: profile.heightCm,
            waistCm: profile.waistCm, hrMaxOverride: profile.hrMaxOverride,
            stepTicksPerStep: profile.stepTicksPerStep,
            stepsCalibrationCoefficient: profile.stepsCalibrationCoefficient,
            stepsCalibrationSampleDays: profile.stepsCalibrationSampleDays,
            stepsCalibrationConfidence: profile.stepsCalibrationConfidence,
            stepsCalibrationManual: profile.stepsCalibrationManual,
            stepsManualCoefficient: profile.stepsManualCoefficient,
            avatarImageData: profile.avatarImageData,
            unitsSystem: d.string(forKey: unitsSystemKey) ?? "",
            unitsTemperature: d.string(forKey: unitsTempKey) ?? "",
            effortScale: d.string(forKey: effortScaleKey) ?? "",
            keyMetrics: d.string(forKey: keyMetricsKey) ?? "",
            cycleAwareness: d.bool(forKey: cycleKey),
            hydrationTracking: d.bool(forKey: hydrationKey))
    }

    /// Apply a relayed payload to THIS device (Mac). Backs up the Mac's own settings on the first apply
    /// so `restoreOwn` can revert on unpair.
    static func apply(_ s: SyncSettings, to profile: ProfileStore) {
        if d.data(forKey: backupKey) == nil { d.set(current(profile: profile).encoded(), forKey: backupKey) }
        write(s, to: profile)
    }

    /// Revert to the Mac's own settings (called on unpair). No-op if this device never mirrored.
    static func restoreOwn(profile: ProfileStore) {
        guard let data = d.data(forKey: backupKey), let own = SyncSettings(data: data) else { return }
        write(own, to: profile)
        d.removeObject(forKey: backupKey)
    }

    /// If pairing disappeared outside the normal unpair path (for example the Keychain item was cleared),
    /// restore the Mac's backed-up local settings on launch instead of leaving the iPhone profile stranded.
    static func restoreIfStranded(profile: ProfileStore) {
        guard SyncPairing.load() == nil, d.data(forKey: backupKey) != nil else { return }
        restoreOwn(profile: profile)
    }

    private static func write(_ s: SyncSettings, to profile: ProfileStore) {
        // ProfileStore @Published setters persist to UserDefaults + publish, so readers update live.
        profile.age = s.age
        profile.sex = s.sex
        profile.weightKg = s.weightKg
        profile.heightCm = s.heightCm
        profile.waistCm = s.waistCm
        profile.hrMaxOverride = s.hrMaxOverride
        profile.stepTicksPerStep = s.stepTicksPerStep
        profile.stepsCalibrationCoefficient = s.stepsCalibrationCoefficient
        profile.stepsCalibrationSampleDays = s.stepsCalibrationSampleDays
        profile.stepsCalibrationConfidence = s.stepsCalibrationConfidence
        profile.stepsCalibrationManual = s.stepsCalibrationManual
        profile.stepsManualCoefficient = s.stepsManualCoefficient
        profile.avatarImageData = s.avatarImageData
        d.set(s.unitsSystem, forKey: unitsSystemKey)
        d.set(s.unitsTemperature, forKey: unitsTempKey)
        d.set(s.effortScale, forKey: effortScaleKey)
        d.set(s.keyMetrics, forKey: keyMetricsKey)
        d.set(s.cycleAwareness, forKey: cycleKey)
        d.set(s.hydrationTracking, forKey: hydrationKey)
    }
}
