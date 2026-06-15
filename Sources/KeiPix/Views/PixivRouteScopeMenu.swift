import SwiftUI

struct PixivRouteScopeMenu: View {
    let family: PixivRouteScopeFamily
    let selectedRoute: PixivRoute
    let selectRoute: (PixivRoute) -> Void

    var body: some View {
        Menu {
            ForEach(family.routes) { route in
                Button {
                    selectRoute(route)
                } label: {
                    Label(
                        route.title,
                        systemImage: route == selectedRoute ? "checkmark" : route.systemImage
                    )
                }
            }
        } label: {
            Label(selectedRoute.title, systemImage: family.systemImage)
        }
        .menuOrder(.fixed)
        .help(family.title)
        .accessibilityLabel(family.title)
    }
}
