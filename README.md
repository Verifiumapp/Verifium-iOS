# Verifium

An open-source iOS security and privacy auditor. Verifium walks you through hardening best practices from [ANSSI](https://www.cert.ssi.gouv.fr/cti/CERTFR-2025-CTI-012/), [CISA](https://www.cisa.gov/resources-tools/resources/mobile-communications-best-practice-guidance), and Apple's own guidelines, as well as Citizen Lab, Amnesty International and EFF recommendations.

## What it does

Verifium runs 22 security checks across five categories: device hardening, network exposure, installed apps, privacy settings, and data protection. Each check is scored by severity (critical, high, medium, low) and contributes to a weighted security score.

11 checks run automatically using iOS APIs:
- OS version, Lockdown Mode, reboot frequency
- Ad tracking status, location services
- VPN tunnel detection
- App detection for WhatsApp, Telegram, WeChat, and Signal
- Hardware memory protection (MIE/EMTE) on iPhone 17 and iPhone Air

11 checks require manual verification with step-by-step guidance:
- Passcode strength, 2FA, Stolen Device Protection, automatic updates
- Bluetooth and Wi-Fi disabled when not in use
- iCloud Backup, Advanced Data Protection
- AirDrop, app permissions, Apple analytics sharing

Other features:
- App icon badge showing how many manual checks are still pending
- "Open Settings" button with fallback to Settings root (iOS does not allow apps to deep-link into specific system settings)
- Confetti animation when all checks are reviewed
- Localized in English and French

## Screenshots

See [verifium.app](https://verifium.app).

## Requirements

- iOS 17.0+
- Xcode 16+
- No external dependencies

## Getting started

1. Clone the repo
2. Open `Verifium.xcodeproj` in Xcode
3. Select your target device and run

Note: app detection (WhatsApp, Telegram, Signal, WeChat) requires the `LSApplicationQueriesSchemes` entries in Info.plist. The Xcode project must point to the custom `Verifium/Info.plist` via the `INFOPLIST_FILE` build setting; otherwise Xcode generates its own and ignores the query schemes.

## Backend

The OS version check fetches the latest iOS version from a remote JSON endpoint. A Python script in `backend/` generates this file from Apple's IPSW signing API:

## Privacy

Verifium does not collect, store, or transmit any user data. The only network request is an HTTPS fetch of the latest iOS version number. All checks run locally on-device.

## License

GPL-3.0
