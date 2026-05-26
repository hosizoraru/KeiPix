import Foundation

@MainActor
extension KeiPixStore {
    func bootstrap() async {
        do {
            storedAccounts = try await api.storedAccounts()
            session = try await api.loadSession()
            storedAccounts = try await api.storedAccounts()
            if session != nil {
                await refreshRestrictedModeSetting()
                await refreshAIShowSetting()
                await reloadCurrentFeed()
                await syncBrowsingHistoryFromPixiv()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loginURL() async -> URL {
        await api.makeLoginURL()
    }

    func completeLogin(code: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            setRealAccountMode()
            session = try await api.login(code: code)
            storedAccounts = try await api.storedAccounts()
            isLoginPresented = false
            selectedRoute = .home
            await refreshRestrictedModeSetting()
            await refreshAIShowSetting()
            await reloadCurrentFeed()
            await syncBrowsingHistoryFromPixiv()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeTokenLogin(refreshToken: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            setRealAccountMode()
            session = try await api.login(refreshToken: refreshToken)
            storedAccounts = try await api.storedAccounts()
            isTokenLoginPresented = false
            selectedRoute = .home
            await refreshRestrictedModeSetting()
            await refreshAIShowSetting()
            await reloadCurrentFeed()
            await syncBrowsingHistoryFromPixiv()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func logout() async {
        do {
            setRealAccountMode()
            session = try await api.clearSession()
            storedAccounts = try await api.storedAccounts()
            resetLoadedSessionContent()
            if session != nil {
                await refreshRestrictedModeSetting()
                await refreshAIShowSetting()
                await reloadCurrentFeed()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func switchAccount(userID: String) async {
        guard session?.user.id != userID else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            setRealAccountMode()
            session = try await api.selectAccount(userID: userID)
            storedAccounts = try await api.storedAccounts()
            resetLoadedSessionContent()
            selectedRoute = .home
            if session != nil {
                await refreshRestrictedModeSetting()
                await refreshAIShowSetting()
                await reloadCurrentFeed()
                await syncBrowsingHistoryFromPixiv()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeStoredAccount(userID: String) async {
        do {
            session = try await api.deleteAccount(userID: userID)
            storedAccounts = try await api.storedAccounts()
            resetLoadedSessionContent()
            if session != nil {
                await refreshRestrictedModeSetting()
                await refreshAIShowSetting()
                await reloadCurrentFeed()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func loadAccountSessionMode() -> AccountSessionMode {
        let mode = UserDefaults.standard.string(forKey: "accountSessionMode")
            .flatMap(AccountSessionMode.init(rawValue:)) ?? .real
        let userSelected = UserDefaults.standard.bool(forKey: "accountSessionModeUserSelected")
        if mode == .visualQA, userSelected == false {
            return .real
        }
        return mode
    }

    private func setRealAccountMode() {
        accountSessionMode = .real
        UserDefaults.standard.set(AccountSessionMode.real.rawValue, forKey: "accountSessionMode")
        UserDefaults.standard.set(true, forKey: "accountSessionModeUserSelected")
    }
}
