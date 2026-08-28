import FeatureLocalization
import Foundation

enum SettingsSafetyL10n {
    static let introduction = string(
        "settings.safety.introduction",
        default: "Break activities are optional and general. This app cannot assess symptoms or replace professional care.",
    )
    static let routine = string("settings.safety.routine", default: "Routine guidance")
    static let routineDetail = string(
        "settings.safety.routine_detail",
        default: "Choose a comfortable option, use support if needed, and stop if you feel pain, dizziness, unusual shortness of breath, weakness, or instability.",
    )
    static let persistent = string(
        "settings.safety.persistent",
        default: "Persistent or worsening symptoms",
    )
    static let persistentDetail = string(
        "settings.safety.persistent_detail",
        default: "Persistent or worsening eye, neck, back, wrist, or headache symptoms may have causes a reminder app cannot assess. Consider an appropriate health professional.",
    )
    static let urgent = string("settings.safety.urgent", default: "Seek urgent help")
    static let urgentDetail = string(
        "settings.safety.urgent_detail",
        default: "This app cannot assess symptoms. Stop the activity and seek urgent help for chest pain or pressure, fainting, severe unusual shortness of breath, sudden weakness, sudden vision loss, a dark curtain/shadow, sudden flashes or many new floaters, severe eye pain, or new bladder/bowel changes with numbness or leg weakness.",
    )
    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }
}
