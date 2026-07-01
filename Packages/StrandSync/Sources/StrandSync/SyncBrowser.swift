import Foundation
import Network

/// Discovers `_noopsync._tcp` peers on the local network (the Mac side). Reports each discovered
/// endpoint via a callback; the coordinator decides whether to pull from it. Kept payload-agnostic so
/// the package stays app-independent.
public final class SyncBrowser {
    private var browser: NWBrowser?
    private let type: String
    private let onEndpoint: (NWEndpoint) -> Void

    /// `type` is the Bonjour service to browse — `_noopsync._tcp` for the history channel,
    /// `_noopsync-live._tcp` for the live stream.
    public init(type: String = "_noopsync._tcp", onEndpoint: @escaping (NWEndpoint) -> Void) {
        self.type = type
        self.onEndpoint = onEndpoint
    }

    public func start() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            for result in results { self?.onEndpoint(result.endpoint) }
        }
        browser.start(queue: SyncConnection.queue)
        self.browser = browser
    }

    public func stop() { browser?.cancel(); browser = nil }
}
