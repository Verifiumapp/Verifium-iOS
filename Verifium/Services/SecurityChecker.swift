import Foundation
import UIKit
import CoreLocation
import Network
import Darwin

// AppTrackingTransparency imported conditionally
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

// MARK: - SecurityChecker

/// Performs automatic security checks using available iOS APIs.
/// Manual checks return .manualRequired and require user confirmation.
final class SecurityChecker {

    // -------------------------------------------------------------------------
    // MARK: Check Definitions
    // -------------------------------------------------------------------------

    static func allChecks() -> [SecurityCheck] {
        [
            // Face ID & Passcode screen
            SecurityCheck(id: "passcode",
                          category: .device,
                          severity: .critical,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // General → Software Update
            SecurityCheck(id: "os_version",
                          category: .device,
                          severity: .critical,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: true),

            // Privacy & Security (Lockdown Mode is a section within it)
            SecurityCheck(id: "lockdown_mode",
                          category: .device,
                          severity: .critical,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: true),

            // No settings page — reboot is informational only
            SecurityCheck(id: "reboot_time",
                          category: .device,
                          severity: .medium,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: false),

            // Privacy & Security → Tracking (Personalized Ads toggle)
            SecurityCheck(id: "ad_tracking",
                          category: .privacy,
                          severity: .high,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: true),

            // Privacy & Security → Location Services
            SecurityCheck(id: "location_services",
                          category: .privacy,
                          severity: .high,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: true),

            // Bluetooth settings root
            SecurityCheck(id: "bluetooth",
                          category: .network,
                          severity: .medium,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // Wi-Fi settings root
            SecurityCheck(id: "wifi",
                          category: .network,
                          severity: .medium,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // General → VPN & Device Management
            SecurityCheck(id: "vpn",
                          category: .network,
                          severity: .low,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: true),

            // WhatsApp — warning if installed (known attack vector), best score if absent
            SecurityCheck(id: "whatsapp",
                          category: .applications,
                          severity: .medium,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: false),

            // Telegram — action is to delete the app, no settings page needed
            SecurityCheck(id: "telegram",
                          category: .applications,
                          severity: .medium,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: false),

            // WeChat — high risk due to lack of E2EE and documented PRC cooperation
            SecurityCheck(id: "wechat",
                          category: .applications,
                          severity: .medium,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: false),

            // General → Software Update → Automatic Updates
            SecurityCheck(id: "auto_updates",
                          category: .device,
                          severity: .high,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // Apple ID → Sign-In & Security → Two-Factor Authentication
            SecurityCheck(id: "account_2fa",
                          category: .device,
                          severity: .critical,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // Face ID & Passcode → Stolen Device Protection
            SecurityCheck(id: "stolen_device_protection",
                          category: .device,
                          severity: .high,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // Privacy & Security → Analytics & Improvements
            SecurityCheck(id: "analytics",
                          category: .privacy,
                          severity: .low,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // General → AirDrop
            SecurityCheck(id: "airdrop",
                          category: .privacy,
                          severity: .medium,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // Apple ID → iCloud → iCloud Backup
            SecurityCheck(id: "icloud_backup",
                          category: .dataProtection,
                          severity: .high,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // Apple ID → iCloud (no known deep link for ADP specifically)
            SecurityCheck(id: "advanced_data_protection",
                          category: .dataProtection,
                          severity: .high,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // Privacy & Security root (user browses each permission category)
            SecurityCheck(id: "app_permissions",
                          category: .privacy,
                          severity: .medium,
                          status: .manualRequired,
                          isAutoCheckable: false,
                          showsSettingsLink: true),

            // Signal — auto-detect installation, manual security review if present
            SecurityCheck(id: "signal",
                          category: .applications,
                          severity: .medium,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: false),

            // Hardware memory protection (MIE / EMTE)
            SecurityCheck(id: "memory_integrity",
                          category: .device,
                          severity: .high,
                          status: .checking,
                          isAutoCheckable: true,
                          showsSettingsLink: false),
        ]
    }

    // -------------------------------------------------------------------------
    // MARK: Auto-Checkers
    // -------------------------------------------------------------------------

    /// Run a single automatic check by ID and return its result.
    @MainActor
    func runCheck(id: String) async -> (CheckStatus, String?) {
        switch id {
        case "os_version":        return await checkOSVersion()
        case "ad_tracking":       return await checkAdTracking()
        case "location_services": return await checkLocationServices()
        case "vpn":               return checkVPN()
        case "whatsapp":          return await checkApp(scheme: "whatsapp", appName: "WhatsApp", installedStatus: .warning)
        case "telegram":          return await checkApp(scheme: "tg", appName: "Telegram", installedStatus: .failed)
        case "wechat":            return await checkApp(scheme: "weixin", appName: "WeChat", installedStatus: .failed)
        case "signal":            return await checkApp(scheme: "sgnl", appName: "Signal", installedStatus: .manualRequired)
        case "wifi":              return (.manualRequired, nil)
        case "lockdown_mode":     return await checkLockdownMode()
        case "reboot_time":       return checkRebootTime()
        case "memory_integrity":  return checkMemoryIntegrity()
        default:                  return (.manualRequired, nil)
        }
    }

    // MARK: OS Version

    private func checkOSVersion() async -> (CheckStatus, String?) {
        let current = UIDevice.current.systemVersion
        guard let latest = await VersionService.fetchLatestVersion() else {
            return (.warning, NSLocalizedString("os_version.unavailable", comment: ""))
        }
        if VersionService.isUpToDate(current: current, latest: latest) {
            return (.passed, current)
        } else {
            // Encode both versions separated by "|" for the UI to display
            return (.failed, "\(current)|\(latest.displayString)")
        }
    }

    // MARK: Ad Tracking

    private func checkAdTracking() async -> (CheckStatus, String?) {
        #if canImport(AppTrackingTransparency)
        let status = ATTrackingManager.trackingAuthorizationStatus
        switch status {
        case .authorized:      return (.failed, NSLocalizedString("ad_tracking.enabled", comment: ""))
        case .denied:          return (.passed, NSLocalizedString("ad_tracking.disabled", comment: ""))
        case .restricted:      return (.passed, NSLocalizedString("ad_tracking.restricted", comment: ""))
        case .notDetermined:   return (.warning, NSLocalizedString("ad_tracking.not_set", comment: ""))
        @unknown default:      return (.warning, nil)
        }
        #else
        return (.manualRequired, nil)
        #endif
    }

    // MARK: Location Services

    private func checkLocationServices() async -> (CheckStatus, String?) {
        let enabled = await Task.detached {
            CLLocationManager.locationServicesEnabled()
        }.value
        return enabled
            ? (.failed, NSLocalizedString("location.enabled", comment: ""))
            : (.passed, NSLocalizedString("location.disabled", comment: ""))
    }

    // MARK: VPN

    /// Checks network interfaces for an active VPN tunnel (utun, ppp).
    /// ipsec0 is excluded — it is a permanent iOS system interface, always
    /// UP/RUNNING with an IP even when no VPN profile exists.
    /// We require an IPv4 address because system utun interfaces only carry
    /// link-local IPv6; a real VPN tunnel always assigns an IPv4.
    private func checkVPN() -> (CheckStatus, String?) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return (.warning, nil) }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let current = ptr {
            let flags  = Int32(current.pointee.ifa_flags)
            let name   = String(cString: current.pointee.ifa_name)
            let family = current.pointee.ifa_addr?.pointee.sa_family ?? 0

            let isUp       = (flags & IFF_UP)       != 0
            let isRunning  = (flags & IFF_RUNNING)   != 0
            let isLoopback = (flags & IFF_LOOPBACK)  != 0
            let isTunnel   = name.hasPrefix("utun") || name.hasPrefix("ppp")
            let hasIPv4    = family == UInt8(AF_INET)

            if isUp && isRunning && !isLoopback && isTunnel && hasIPv4 {
                return (.passed, name)
            }
            ptr = current.pointee.ifa_next
        }
        return (.warning, NSLocalizedString("vpn.not_detected", comment: ""))
    }

    // MARK: App Detection

    /// Generic app detection. Returns `installedStatus` when the app is found,
    /// `.passed` when absent. Easy to extend for new applications.
    private func checkApp(scheme: String, appName: String, installedStatus: CheckStatus) async -> (CheckStatus, String?) {
        guard let url = URL(string: "\(scheme)://") else { return (.warning, nil) }
        let installed = await MainActor.run { UIApplication.shared.canOpenURL(url) }
        return installed
            ? (installedStatus, String(format: NSLocalizedString("app.installed", comment: ""), appName))
            : (.passed, String(format: NSLocalizedString("app.not_installed", comment: ""), appName))
    }

    // MARK: Lockdown Mode

    private func checkLockdownMode() async -> (CheckStatus, String?) {
        let enabled = await LockdownModeDetector.detect()
        return enabled
            ? (.passed, NSLocalizedString("lockdown.enabled", comment: ""))
            : (.failed, NSLocalizedString("lockdown.disabled", comment: ""))
    }

    // MARK: Reboot Time

    private static let rebootFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private func checkRebootTime() -> (CheckStatus, String?) {
        var tv = timeval()
        var tvSize = MemoryLayout<timeval>.size
        let result = sysctlbyname("kern.boottime", &tv, &tvSize, nil, 0)
        guard result == 0 else { return (.warning, nil) }

        let bootDate = Date(timeIntervalSince1970: Double(tv.tv_sec))
        let days = Calendar.current.dateComponents([.day], from: bootDate, to: .now).day ?? 0

        let relStr = Self.rebootFormatter.localizedString(for: bootDate, relativeTo: .now)

        if days > 30 {
            return (.failed, String(format: NSLocalizedString("reboot.days_ago", comment: ""), days))
        } else if days > 14 {
            return (.warning, relStr)
        } else {
            return (.passed, relStr)
        }
    }

    // MARK: Memory Integrity (MIE / EMTE)

    /// iPhone 17 and iPhone Air models with A19 / A19 Pro chips support
    /// hardware Memory Integrity Enforcement (MIE) with Enhanced Memory
    /// Tagging Extension (EMTE).
    private func checkMemoryIntegrity() -> (CheckStatus, String?) {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm.FEAT_MTE4", &value, &size, nil, 0)

        if result == 0 && value == 1 {
            return (.passed, NSLocalizedString("memory_integrity.supported", comment: ""))
        } else {
            return (.warning, NSLocalizedString("memory_integrity.not_supported", comment: ""))
        }
    }
}
