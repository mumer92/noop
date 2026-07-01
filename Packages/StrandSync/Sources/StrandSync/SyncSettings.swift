import Foundation

/// Profile + display-driving preferences relayed iPhone→Mac (read-only mirror). These live in
/// UserDefaults, not the synced database, yet drive Fitness Age, Vitality, HR zones, unit conversions,
/// and the key-metric grid — so without this the Mac renders them wrong/default. Pure value type; the
/// app maps its ProfileStore + prefs to/from this (see Strand/Sync/SyncSettingsBridge.swift).
public struct SyncSettings: Codable, Sendable, Equatable {
    // Profile (Strand/Data/Profile.swift ProfileStore)
    public var age: Int
    public var sex: String
    public var weightKg: Double
    public var heightCm: Double
    public var waistCm: Double
    public var hrMaxOverride: Int
    public var stepTicksPerStep: Double
    public var stepsCalibrationCoefficient: Double
    public var stepsCalibrationSampleDays: Int
    public var stepsCalibrationConfidence: Double
    public var stepsCalibrationManual: Bool
    public var stepsManualCoefficient: Double
    public var avatarImageData: Data?
    // Display prefs (UserDefaults keys)
    public var unitsSystem: String       // "units.system"
    public var unitsTemperature: String  // "units.temperature"
    public var effortScale: String       // "effort.scale"
    public var keyMetrics: String        // "today.keyMetrics"
    public var cycleAwareness: Bool       // "noopCycleAwareness"
    public var hydrationTracking: Bool    // "noop.hydrationTracking"

    public init(age: Int, sex: String, weightKg: Double, heightCm: Double, waistCm: Double,
                hrMaxOverride: Int, stepTicksPerStep: Double, stepsCalibrationCoefficient: Double,
                stepsCalibrationSampleDays: Int, stepsCalibrationConfidence: Double,
                stepsCalibrationManual: Bool, stepsManualCoefficient: Double, avatarImageData: Data?,
                unitsSystem: String, unitsTemperature: String, effortScale: String, keyMetrics: String,
                cycleAwareness: Bool, hydrationTracking: Bool) {
        self.age = age; self.sex = sex; self.weightKg = weightKg; self.heightCm = heightCm
        self.waistCm = waistCm; self.hrMaxOverride = hrMaxOverride; self.stepTicksPerStep = stepTicksPerStep
        self.stepsCalibrationCoefficient = stepsCalibrationCoefficient
        self.stepsCalibrationSampleDays = stepsCalibrationSampleDays
        self.stepsCalibrationConfidence = stepsCalibrationConfidence
        self.stepsCalibrationManual = stepsCalibrationManual
        self.stepsManualCoefficient = stepsManualCoefficient; self.avatarImageData = avatarImageData
        self.unitsSystem = unitsSystem; self.unitsTemperature = unitsTemperature
        self.effortScale = effortScale; self.keyMetrics = keyMetrics
        self.cycleAwareness = cycleAwareness; self.hydrationTracking = hydrationTracking
    }

    public func encoded() -> Data { (try? JSONEncoder().encode(self)) ?? Data() }
    public init?(data: Data) {
        guard let s = try? JSONDecoder().decode(SyncSettings.self, from: data) else { return nil }
        self = s
    }
}
