import SwiftUI
import UIKit

@main
struct CuadernoCFIApp: App {
    var body: some Scene {
        WindowGroup {
            InicioView()
                // Fechas en español («10 ene 2025»), aunque el iPad esté en otro idioma.
                .environment(\.locale, Locale(identifier: "es_ES"))
                // Al tocar una cifra o una cuenta para corregirla queda seleccionada entera:
                // lo que se escriba encima con el Pencil la sustituye.
                .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { aviso in
                    DispatchQueue.main.async { (aviso.object as? UITextField)?.selectAll(nil) }
                }
        }
    }
}
