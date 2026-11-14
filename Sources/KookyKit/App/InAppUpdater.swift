import AppKit
import Sparkle

/// No updater is started without a release-signing public key embedded at build time.
/// Apple notarization and Sparkle archive signatures are separate checks.
struct UpdateTrustConfiguration {
    let feedURL: URL
    let publicKey: String

    init?(info: [String: Any]) {
        guard let key = info["SUPublicEDKey"] as? String,
              let decoded = Data(base64Encoded: key), decoded.count == 32,
              decoded.base64EncodedString() == key,
              decoded.contains(where: { $0 != 0 }),
              let feed = info["SUFeedURL"] as? String,
              feed == "https://raw.githubusercontent.com/uuuyuqi/kookoo/main/appcast.xml",
              let url = URL(string: feed),
              info["SUVerifyUpdateBeforeExtraction"] as? Bool == true else { return nil }
        publicKey = key
        feedURL = url
    }
}

@MainActor
final class InAppUpdater: NSObject, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?
    private var pendingInstall: (() -> Void)?
    private(set) var isConfigured = false

    override init() {
        super.init()
        // Fail closed: no network, no installer and no placeholder trust key.
        guard UpdateTrustConfiguration(info: Bundle.main.infoDictionary ?? [:]) != nil else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: false,
                                                       updaterDelegate: self,
                                                       userDriverDelegate: nil)
        self.controller = controller
        controller.updater.automaticallyChecksForUpdates = false
        controller.updater.automaticallyDownloadsUpdates = false
        controller.updater.sendsSystemProfile = false
        controller.startUpdater()
        isConfigured = true
    }

    func checkForUpdates(_ sender: Any?) {
        if pendingInstall != nil {
            confirmRestart()
        } else {
            controller?.checkForUpdates(sender)
        }
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        KookyApp.isPreview ? ["preview"] : []
    }


    // Always ask at installation time, not just when checking. Terminals may
    // have started new commands while the update downloaded. No forced restart.
    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem,
                 untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        pendingInstall = installHandler
        DispatchQueue.main.async { [weak self] in self?.confirmRestart() }
        return true
    }

    private func confirmRestart() {
        guard let install = pendingInstall else { return }
        let alert = NSAlert()
        alert.messageText = "Install update and restart Kookoo?"
        alert.informativeText = "Restarting closes terminal sessions and stops running commands and agents. Save your work first. Choose Later to continue working; use Check for Updates when you are ready."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Install and Restart")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        pendingInstall = nil
        install()
    }
}
