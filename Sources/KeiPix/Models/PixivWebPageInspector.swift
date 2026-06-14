import Foundation

enum PixivWebPageInspector {
    static func looksSignedIn(_ html: String, userID: String) -> Bool {
        let signedInMarkers = [
            #"href="/settings/profile""#,
            #"href="/logout""#,
            #""/settings/profile""#,
            #""/logout""#
        ]
        if signedInMarkers.contains(where: html.contains) {
            return true
        }

        let trimmedID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedID.isEmpty == false else { return false }
        let accountContextMarkers = [
            "pixiv.context",
            "currentUser",
            "userData"
        ]
        let accountIDMarkers = [
            #""id":"\#(trimmedID)""#,
            #""id":\#(trimmedID)"#,
            #""userId":"\#(trimmedID)""#,
            #""userId":\#(trimmedID)"#,
            #""user_id":"\#(trimmedID)""#,
            #""user_id":\#(trimmedID)"#,
            trimmedID
        ]
        return accountContextMarkers.contains(where: html.contains)
            && accountIDMarkers.contains(where: html.contains)
    }

    static func looksLikeLegacyActivityPage(_ html: String) -> Bool {
        html.contains("stacc_center_area")
            || html.contains("stacc_status")
            || html.contains("stacc_timeline")
    }

    static func activityPageLooksAccessible(
        html: String,
        requestedURL: URL,
        finalURL: URL?,
        userID: String
    ) -> Bool {
        guard finalURLMatchesRequestedPath(requestedURL: requestedURL, finalURL: finalURL),
              looksLikeLoginPage(html, finalURL: finalURL) == false
        else {
            return false
        }

        return looksSignedIn(html, userID: userID) || looksLikeLegacyActivityPage(html)
    }

    static func finalURLMatchesRequestedPath(requestedURL: URL, finalURL: URL?) -> Bool {
        let finalURL = finalURL ?? requestedURL
        return requestedURL.host?.lowercased() == finalURL.host?.lowercased()
            && requestedURL.path == finalURL.path
    }

    static func looksLikeLoginPage(_ html: String, finalURL: URL?) -> Bool {
        if finalURL?.host?.lowercased().contains("accounts.pixiv.net") == true {
            return true
        }
        let lowercased = html.lowercased()
        return lowercased.contains("accounts.pixiv.net/login")
            || lowercased.contains(#"action="/login"#)
            || lowercased.contains(#"action='/login"#)
            || lowercased.contains("name=\"return_to\"")
    }
}
