import Foundation
import WebKit

// MARK: - LockdownModeDetector
//
// Detects whether Lockdown Mode is enabled at the device level by testing
// for WebAssembly support inside a headless WKWebView. When Lockdown Mode
// is active, the JIT compiler is disabled and WebAssembly is unavailable.
//
// This is a behavioural heuristic — no official public API exists for
// device-level Lockdown Mode detection as of iOS 18. If Apple introduces
// one in the future, this file is the single place to swap in the real API.

@MainActor
final class LockdownModeDetector: NSObject, WKNavigationDelegate {

    /// Returns `true` when Lockdown Mode appears to be enabled.
    /// Available on iOS 16+ (Lockdown Mode doesn't exist before that).
    /// Result is cached for the app session to avoid repeated WKWebView probes.
    static func detect() async -> Bool {
        if let cached = cachedResult { return cached }
        guard #available(iOS 16, *) else {
            cachedResult = false
            return false
        }
        let result = await LockdownModeDetector().run()
        cachedResult = result
        return result
    }

    // MARK: - Private

    @MainActor private static var cachedResult: Bool?
    private var continuation: CheckedContinuation<Bool, Never>?
    private var webView: WKWebView?
    private var timeoutTask: Task<Void, Never>?

    /// Inline HTML that checks for WebAssembly support and posts the result
    /// back via a message handler.
    private static let probeHTML = """
    <!DOCTYPE html>
    <html><body><script>
    try {
        // WebAssembly is disabled when Lockdown Mode is active.
        const supported = typeof WebAssembly === 'object'
                       && typeof WebAssembly.instantiate === 'function';
        window.webkit.messageHandlers.lockdownProbe.postMessage(supported ? "yes" : "no");
    } catch(e) {
        window.webkit.messageHandlers.lockdownProbe.postMessage("no");
    }
    </script></body></html>
    """

    private func run() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            self.continuation = cont

            let config = WKWebViewConfiguration()
            let handler = ScriptMessageHandler { [weak self] body in
                let wasmAvailable = (body as? String) == "yes"
                self?.finish(lockdownEnabled: !wasmAvailable)
            }
            config.userContentController.add(handler, name: "lockdownProbe")

            let wv = WKWebView(frame: .zero, configuration: config)
            wv.navigationDelegate = self
            self.webView = wv
            wv.loadHTMLString(Self.probeHTML, baseURL: nil)

            // Safety timeout — if the page never responds, assume we can't determine.
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                self?.finish(lockdownEnabled: false)
            }
        }
    }

    private func finish(lockdownEnabled: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        // Clean up message handler before tearing down to reduce WebKit process errors
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "lockdownProbe")
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        cont.resume(returning: lockdownEnabled)
    }

    // WKNavigationDelegate — handle load failures
    nonisolated func webView(_ webView: WKWebView,
                             didFail navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor in finish(lockdownEnabled: false) }
    }

    nonisolated func webView(_ webView: WKWebView,
                             didFailProvisionalNavigation navigation: WKNavigation!,
                             withError error: Error) {
        Task { @MainActor in finish(lockdownEnabled: false) }
    }
}

// MARK: - Script Message Handler

/// Lightweight `WKScriptMessageHandler` that forwards to a closure,
/// avoiding the need for `LockdownModeDetector` to conform directly
/// (which would create a retain cycle with the content controller).
private final class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let callback: @MainActor (Any) -> Void

    init(callback: @escaping @MainActor (Any) -> Void) {
        self.callback = callback
    }

    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        // WebKit always delivers this on the main thread
        MainActor.assumeIsolated {
            callback(message.body)
        }
    }
}
