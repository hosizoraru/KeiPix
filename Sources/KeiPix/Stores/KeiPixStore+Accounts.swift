import Foundation

@MainActor
extension KeiPixStore {
    func bootstrap() async {
        do {
            storedAccounts = try await api.storedAccounts()
            session = try await api.loadSession()
            pixivWebSession = await api.currentWebSession()
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
            pixivWebSession = await api.currentWebSession()
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
            pixivWebSession = await api.currentWebSession()
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
            pixivWebSession = await api.currentWebSession()
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
            pixivWebSession = await api.currentWebSession()
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
            pixivWebSession = await api.currentWebSession()
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

    func connectPixivWebSession(cookies: [PixivWebSessionCookie]) async -> Bool {
        guard let userID = session?.user.id else {
            errorMessage = L10n.errorLoginRequired
            isLoginPresented = true
            return false
        }

        do {
            pixivWebSession = try await api.savePixivWebSession(cookies: cookies, userID: userID)
            isPixivWebSessionPresented = false
            if selectedRoute == .savedPixivCollections {
                await refreshPixivCollections(mode: .saved)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func disconnectPixivWebSession() async {
        guard let userID = session?.user.id else { return }
        do {
            try await api.clearPixivWebSession(userID: userID)
            pixivWebSession = nil
            if selectedRoute == .savedPixivCollections {
                await refreshPixivCollections(mode: .saved)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
