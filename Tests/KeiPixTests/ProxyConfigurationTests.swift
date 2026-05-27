import Foundation
import Testing
@testable import KeiPix

@Suite("App-level proxy configuration")
struct ProxyConfigurationTests {

    @Test("System mode falls through to nil so URLSession picks up macOS network settings")
    func systemModeFallsThroughToNil() {
        #expect(ProxyConfiguration.system.connectionProxyDictionary == nil)
    }

    @Test("Direct mode emits an explicit no-proxy dictionary, not nil")
    func directModeBlocksAllProxies() throws {
        let dict = try #require(ProxyConfiguration.direct.connectionProxyDictionary)
        #expect(dict[kCFNetworkProxiesHTTPEnable] as? Int == 0)
        #expect(dict[kCFNetworkProxiesHTTPSEnable] as? Int == 0)
        #expect(dict[kCFNetworkProxiesSOCKSEnable] as? Int == 0)
    }

    @Test("Manual HTTP proxy populates the HTTP-only CFNetwork keys")
    func manualHTTPDictionary() throws {
        let config = ProxyConfiguration.manual(host: "127.0.0.1", port: 7_890, scheme: .http)
        let dict = try #require(config.connectionProxyDictionary)
        #expect(dict[kCFNetworkProxiesHTTPEnable] as? Int == 1)
        #expect(dict[kCFNetworkProxiesHTTPProxy] as? String == "127.0.0.1")
        #expect(dict[kCFNetworkProxiesHTTPPort] as? Int == 7_890)
        #expect(dict[kCFNetworkProxiesHTTPSEnable] == nil)
        #expect(dict[kCFNetworkProxiesSOCKSEnable] == nil)
    }

    @Test("Manual HTTPS proxy populates the HTTPS-only CFNetwork keys")
    func manualHTTPSDictionary() throws {
        let config = ProxyConfiguration.manual(host: "proxy.example.com", port: 8_443, scheme: .https)
        let dict = try #require(config.connectionProxyDictionary)
        #expect(dict[kCFNetworkProxiesHTTPSEnable] as? Int == 1)
        #expect(dict[kCFNetworkProxiesHTTPSProxy] as? String == "proxy.example.com")
        #expect(dict[kCFNetworkProxiesHTTPSPort] as? Int == 8_443)
    }

    @Test("Manual SOCKS5 proxy populates the SOCKS-only CFNetwork keys")
    func manualSOCKSDictionary() throws {
        let config = ProxyConfiguration.manual(host: "10.0.0.1", port: 1_080, scheme: .socks5)
        let dict = try #require(config.connectionProxyDictionary)
        #expect(dict[kCFNetworkProxiesSOCKSEnable] as? Int == 1)
        #expect(dict[kCFNetworkProxiesSOCKSProxy] as? String == "10.0.0.1")
        #expect(dict[kCFNetworkProxiesSOCKSPort] as? Int == 1_080)
    }

    @Test("loadFromUserDefaults restores manual mode round-trip")
    func loadFromUserDefaultsManualRoundTrip() {
        let suite = UserDefaults(suiteName: "ProxyConfigurationTests.manual")!
        defer { suite.removePersistentDomain(forName: "ProxyConfigurationTests.manual") }
        suite.set(ProxyConfigurationMode.manual.rawValue, forKey: ProxyConfiguration.DefaultsKey.mode)
        suite.set("proxy.local", forKey: ProxyConfiguration.DefaultsKey.host)
        suite.set(3_128, forKey: ProxyConfiguration.DefaultsKey.port)
        suite.set(ProxyScheme.http.rawValue, forKey: ProxyConfiguration.DefaultsKey.scheme)

        let restored = ProxyConfiguration.loadFromUserDefaults(suite)
        #expect(restored == .manual(host: "proxy.local", port: 3_128, scheme: .http))
    }

    @Test("Empty manual host falls back to system so a typo can't black-hole all traffic")
    func emptyManualHostFallsBackToSystem() {
        let suite = UserDefaults(suiteName: "ProxyConfigurationTests.empty")!
        defer { suite.removePersistentDomain(forName: "ProxyConfigurationTests.empty") }
        suite.set(ProxyConfigurationMode.manual.rawValue, forKey: ProxyConfiguration.DefaultsKey.mode)
        suite.set("   ", forKey: ProxyConfiguration.DefaultsKey.host)
        suite.set(7_890, forKey: ProxyConfiguration.DefaultsKey.port)
        suite.set(ProxyScheme.http.rawValue, forKey: ProxyConfiguration.DefaultsKey.scheme)

        #expect(ProxyConfiguration.loadFromUserDefaults(suite) == .system)
    }

    @Test("Zero port in manual mode falls back to system instead of producing an unreachable proxy")
    func zeroPortFallsBackToSystem() {
        let suite = UserDefaults(suiteName: "ProxyConfigurationTests.zeroPort")!
        defer { suite.removePersistentDomain(forName: "ProxyConfigurationTests.zeroPort") }
        suite.set(ProxyConfigurationMode.manual.rawValue, forKey: ProxyConfiguration.DefaultsKey.mode)
        suite.set("127.0.0.1", forKey: ProxyConfiguration.DefaultsKey.host)
        suite.set(0, forKey: ProxyConfiguration.DefaultsKey.port)
        suite.set(ProxyScheme.http.rawValue, forKey: ProxyConfiguration.DefaultsKey.scheme)

        #expect(ProxyConfiguration.loadFromUserDefaults(suite) == .system)
    }

    @Test("Default mode is system when no preference has been persisted yet")
    func defaultModeIsSystem() {
        let suite = UserDefaults(suiteName: "ProxyConfigurationTests.empty-defaults")!
        defer { suite.removePersistentDomain(forName: "ProxyConfigurationTests.empty-defaults") }
        #expect(ProxyConfiguration.loadFromUserDefaults(suite) == .system)
    }
}
