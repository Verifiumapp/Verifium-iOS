import Foundation
import SwiftUI

// MARK: - Category

enum CheckCategory: String, CaseIterable, Identifiable {
    case device         = "device"
    case network        = "network"
    case applications   = "applications"
    case privacy        = "privacy"
    case dataProtection = "data_protection"

    var id: String { rawValue }

    var localizedTitle: String { NSLocalizedString("category.\(rawValue)", comment: "") }

    var icon: String {
        switch self {
        case .device:         return "iphone.badge.play"
        case .network:        return "wifi.router"
        case .applications:   return "app.badge.checkmark"
        case .privacy:        return "eye.slash.fill"
        case .dataProtection: return "lock.shield.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .device:         return AppColors.teal
        case .network:        return AppColors.blue
        case .applications:   return AppColors.purple
        case .privacy:        return AppColors.orange
        case .dataProtection: return AppColors.green
        }
    }
}

// MARK: - Severity

enum CheckSeverity: Int, Comparable {
    case low      = 1
    case medium   = 2
    case high     = 3
    case critical = 4

    static func < (lhs: CheckSeverity, rhs: CheckSeverity) -> Bool { lhs.rawValue < rhs.rawValue }

    var localizedLabel: String { NSLocalizedString("severity.\(tag)", comment: "") }

    var tag: String { String(describing: self) }

    /// Weight used for score calculation (separate from rawValue used for sorting).
    var weight: Int {
        switch self {
        case .critical: return 15
        case .high:     return 8
        case .medium:   return 3
        case .low:      return 1
        }
    }

    var color: Color {
        switch self {
        case .critical: return AppColors.red
        case .high:     return AppColors.orange
        case .medium:   return AppColors.yellow
        case .low:      return AppColors.green
        }
    }
}

// MARK: - Status

enum CheckStatus: Equatable {
    case checking
    case passed
    case failed
    case warning
    case manualRequired
    case manualPassed
    case manualFailed

    var isPassing: Bool {
        self == .passed || self == .manualPassed
    }

    var isFailing: Bool {
        self == .failed || self == .manualFailed
    }

    var isManuallyReviewed: Bool {
        self == .manualPassed || self == .manualFailed
    }

    var color: Color {
        switch self {
        case .passed, .manualPassed:   return AppColors.teal
        case .failed, .manualFailed:   return AppColors.red
        case .warning:                  return AppColors.orange
        case .checking:                 return Color.gray
        case .manualRequired:           return AppColors.blue
        }
    }

    var icon: String {
        switch self {
        case .passed, .manualPassed:   return "checkmark.shield.fill"
        case .failed, .manualFailed:   return "xmark.shield.fill"
        case .warning:                  return "exclamationmark.shield.fill"
        case .checking:                 return "clock.fill"
        case .manualRequired:           return "hand.tap.fill"
        }
    }

    var localizedLabel: String { NSLocalizedString("status.\(tag)", comment: "") }

    var tag: String {
        switch self {
        case .passed:          return "passed"
        case .failed:          return "failed"
        case .warning:         return "warning"
        case .checking:        return "checking"
        case .manualRequired:  return "manual_required"
        case .manualPassed:    return "manual_passed"
        case .manualFailed:    return "manual_failed"
        }
    }
}

// MARK: - Source Reference

struct CheckSource: Identifiable {
    let id: String
    let name: String
    let url: URL?
}

// MARK: - SecurityCheck

struct SecurityCheck: Identifiable {
    let id: String
    let category: CheckCategory
    let severity: CheckSeverity
    var status: CheckStatus
    let isAutoCheckable: Bool
    let showsSettingsLink: Bool
    var detectedValue: String? = nil

    // MARK: Localized content
    var title: String           { NSLocalizedString("check.\(id).title", comment: "") }
    var shortDescription: String { NSLocalizedString("check.\(id).short", comment: "") }
    var explanation: String     { NSLocalizedString("check.\(id).explanation", comment: "") }
    var guidanceRaw: String     { NSLocalizedString("check.\(id).guidance", comment: "") }

    var guidanceSteps: [String] {
        guidanceRaw.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var sources: [CheckSource] { CheckSourceRegistry.sources(for: id) }

    /// Parsed OS version components when `detectedValue` contains "current|latest".
    var osVersionComponents: (current: String, latest: String)? {
        guard id == "os_version",
              let value = detectedValue,
              value.contains("|") else { return nil }
        let parts = value.split(separator: "|")
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    // MARK: Scoring

    /// Points multiplier — converts weight to a player-visible reward.
    static let pointsMultiplier = 10

    var scoreValue: Int {
        if status.isPassing { return severity.weight }
        if status == .warning { return max(1, severity.weight / 2) }
        return 0
    }
    var maxScore: Int { severity.weight }

    /// Points this check awards when passing (weight × 10).
    var points: Int { severity.weight * Self.pointsMultiplier }

    /// Points currently earned for this check.
    var earnedPoints: Int { scoreValue * Self.pointsMultiplier }
}

// MARK: - Source Registry

enum CheckSourceRegistry {

    // MARK: Shared source objects (allocated once)

    private static let anssiCTI      = CheckSource(id: "anssi_cti", name: "ANSSI / CERTFR-2025-CTI-012",
                                                   url: URL(string: "https://www.cert.ssi.gouv.fr/cti/CERTFR-2025-CTI-012/"))
    private static let anssi10       = CheckSource(id: "anssi_dur", name: "ANSSI / CERTFR-2025-DUR-001",
                                                   url: URL(string: "https://www.cert.ssi.gouv.fr/dur/CERTFR-2025-DUR-001/"))
    private static let cisa          = CheckSource(id: "cisa", name: "CISA / Mobile Communications Best Practices",
                                                   url: URL(string: "https://www.cisa.gov/resources-tools/resources/mobile-communications-best-practice-guidance"))
    private static let cisaChecklist = CheckSource(id: "cisa_checklist", name: "CISA / Mobile Device Cybersecurity Checklist",
                                                   url: URL(string: "https://www.cisa.gov/resources-tools/resources/capacity-enhancement-guide-federal-agencies-ceg-mobile-device-0"))
    private static let amnesty       = CheckSource(id: "amnesty", name: "Amnesty Security Lab / Digital Security Resources",
                                                   url: URL(string: "https://securitylab.amnesty.org/digital-resources/"))
    private static let amnestyMVT    = CheckSource(id: "amnesty_mvt", name: "Amnesty Security Lab / Mobile Verification Toolkit",
                                                   url: URL(string: "https://github.com/mvt-project/mvt"))
    private static let citizenLab    = CheckSource(id: "citizen_lab", name: "Citizen Lab (Security Planner)",
                                                   url: URL(string: "https://citizenlab.ca/tools-resources/"))
    private static let citizenLabWeChat = CheckSource(id: "citizen_lab_wechat", name: "Citizen Lab / WeChat Privacy Report",
                                                      url: URL(string: "https://citizenlab.ca/research/privacy-in-the-wechat-ecosystem-full-report/"))
    private static let occrp         = CheckSource(id: "occrp", name: "OCCRP",
                                                   url: URL(string: "https://www.occrp.org/en/investigation/telegram-the-fsb-and-the-man-in-the-middle"))
    private static let kremlingram   = CheckSource(id: "kremlingram", name: "Kremlingram / Dangers of Telegram",
                                                   url: URL(string: "https://kremlingram.org/en"))
    private static let waFaq         = CheckSource(id: "wa_faq", name: "WhatsApp / Security Best Practices",
                                                   url: URL(string: "https://faq.whatsapp.com/1095301557782068/"))
    private static let waSecurity    = CheckSource(id: "wa_security", name: "WhatsApp / Security Overview",
                                                   url: URL(string: "https://www.whatsapp.com/security"))
    private static let signalSafety  = CheckSource(id: "signal_safety", name: "Signal / How to Protect Yourself",
                                                   url: URL(string: "https://support.signal.org/hc/en-us/articles/9932632052378-How-to-protect-yourself-on-Signal"))
    private static let apple         = CheckSource(id: "apple_updates", name: "Apple / Security Updates",
                                                   url: URL(string: "https://support.apple.com/en-us/100100"))
    private static let lockdown      = CheckSource(id: "apple_lockdown", name: "Apple / About Lockdown Mode",
                                                   url: URL(string: "https://support.apple.com/en-us/105120"))
    private static let adp           = CheckSource(id: "apple_adp", name: "Apple / Advanced Data Protection",
                                                   url: URL(string: "https://support.apple.com/en-us/108756"))
    private static let stolenDev     = CheckSource(id: "apple_stolen", name: "Apple / Stolen Device Protection",
                                                   url: URL(string: "https://support.apple.com/en-us/120340"))
    private static let applePlatSec  = CheckSource(id: "apple_platform", name: "Apple / Platform Security Guide",
                                                   url: URL(string: "https://help.apple.com/pdf/security/en_US/apple-platform-security-guide.pdf"))
    private static let applePrivacy  = CheckSource(id: "apple_privacy", name: "Apple / Privacy Controls",
                                                   url: URL(string: "https://www.apple.com/privacy/control/"))
    private static let appleCloudSec = CheckSource(id: "apple_icloud_sec", name: "Apple / iCloud data security overview",
                                                   url: URL(string: "https://support.apple.com/en-us/102651"))
    private static let appleMIE      = CheckSource(id: "apple_mie", name: "Apple / Memory Integrity Enforcement",
                                                   url: URL(string: "https://security.apple.com/blog/memory-integrity-enforcement/"))
    private static let effAdid       = CheckSource(id: "eff_adid", name: "EFF / How to Disable Ad ID Tracking",
                                                   url: URL(string: "https://www.eff.org/deeplinks/2022/05/how-disable-ad-id-tracking-ios-and-android-and-why-you-should-do-it-now"))
    private static let effAdp       = CheckSource(id: "eff_adp", name: "EFF / How to Enable Advanced Data Protection",
                                                   url: URL(string: "https://www.eff.org/deeplinks/2023/05/how-enable-advanced-data-protection-ios-and-why-you-should"))
    private static let aivdPhish     = CheckSource(id: "aivd_phish_warning", name: "AIVD / Phishing via messaging apps Signal and WhatsApp",
                                                   url: URL(string: "https://english.aivd.nl/documents/2026/03/09/cybersecurity-advisory.-phishing-via-messaging-apps-signal-and-whatsapp"))
    private static let waStrict      = CheckSource(id: "wa_strict", name: "WhatsApp / Strict Account Settings",
                                                   url: URL(string: "https://blog.whatsapp.com/whatsapps-latest-privacy-protection-strict-account-settings"))
    
    // MARK: Lookup

    private static let mapping: [String: [CheckSource]] = [
        "passcode":                 [anssiCTI, applePlatSec],
        "os_version":               [anssi10, cisa, apple],
        "lockdown_mode":            [anssiCTI, cisa, lockdown, amnesty],
        "reboot_time":              [anssi10, anssiCTI, amnesty],
        "auto_updates":             [anssi10, cisa, cisaChecklist],
        "account_2fa":              [cisa, anssi10, amnesty, citizenLab],
        "stolen_device_protection": [stolenDev, applePlatSec],
        "ad_tracking":              [effAdid, applePrivacy],
        "location_services":        [applePrivacy, amnesty],
        "analytics":                [applePrivacy],
        "airdrop":                  [anssi10, cisa],
        "bluetooth":                [anssi10, cisa],
        "wifi":                     [anssi10, cisa],
        "vpn":                      [anssiCTI, cisa],
        "whatsapp":                 [waStrict, waFaq, waSecurity, anssiCTI, amnestyMVT, aivdPhish],
        "telegram":                 [occrp, kremlingram],
        "wechat":                   [citizenLabWeChat],
        "icloud_backup":            [appleCloudSec],
        "advanced_data_protection": [effAdp, adp],
        "app_permissions":          [anssi10, amnesty],
        "signal":                   [signalSafety, aivdPhish],
        "memory_integrity":         [appleMIE, applePlatSec],
    ]

    static func sources(for id: String) -> [CheckSource] {
        mapping[id] ?? [anssi10, cisa]
    }

}

// MARK: - Color Palette

enum AppColors {
    static let background    = Color(hex: "060D16")
    static let cardBg        = Color(hex: "0D1B2A")
    static let cardBorder    = Color(hex: "1A3A5C")
    static let teal          = Color(hex: "00E5CC")
    static let tealDim       = Color(hex: "007A6E")
    static let blue          = Color(hex: "0A84FF")
    static let purple        = Color(hex: "9B59F5")
    static let green         = Color(hex: "30D158")
    static let orange        = Color(hex: "FF9F0A")
    static let red           = Color(hex: "FF453A")
    static let yellow        = Color(hex: "FFD60A")
    static let textPrimary   = Color(hex: "E0F4F2")
    static let textSecondary = Color(hex: "6B8FA8")
    static let textMono      = Color(hex: "00C8A0")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
