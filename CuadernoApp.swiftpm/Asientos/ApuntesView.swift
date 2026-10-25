import SwiftUI

struct CuentaSeleccionada: Identifiable {
    let codigo: String
    var id: String { codigo }
}

/// Los apuntes como en el cuaderno: importe del Debe | cuenta (con «a» si es Haber) | importe del Haber.
/// Mantener pulsada una cuenta abre su mayor.
struct ApuntesView: View {
    let apuntes: [Apunte]
    let verMayor: (String) -> Void

    var body: some View {
        ForEach(Array(apuntes.enumerated()), id: \.offset) { _, apunte in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(apunte.lado == .debe ? Importe.formatear(apunte.importe) : "")
                    .frame(width: 72, alignment: .trailing)
                Text(textoCuenta(apunte))
                    .lineLimit(1)
                    .padding(.leading, apunte.lado == .haber ? 14 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onLongPressGesture { verMayor(apunte.cuenta) }
                Text(apunte.lado == .haber ? Importe.formatear(apunte.importe) : "")
                    .frame(width: 72, alignment: .trailing)
            }
            .font(.footnote.monospacedDigit())
        }
    }

    private func textoCuenta(_ apunte: Apunte) -> String {
        var texto = Cuenta(apunte.cuenta)?.description ?? apunte.cuenta
        if let detalle = apunte.detalle { texto += " (\(detalle))" }
        return apunte.lado == .haber ? "a \(texto)" : texto
    }
}
