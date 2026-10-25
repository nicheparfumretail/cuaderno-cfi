import SwiftUI

@main
struct CuadernoCFIApp: App {
    var body: some Scene {
        WindowGroup {
            InicioView()
                // Fechas en español («10 ene 2025»), aunque el iPad esté en otro idioma.
                .environment(\.locale, Locale(identifier: "es_ES"))
        }
    }
}
