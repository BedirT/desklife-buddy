import Foundation

public enum FeatureL10n {
    public static func string(_ key: String, default defaultValue: String) -> String {
        Bundle.module.localizedString(forKey: key, value: defaultValue, table: "Localizable")
    }
}
