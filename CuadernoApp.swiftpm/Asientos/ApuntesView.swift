import SwiftUI

struct CuentaSeleccionada: Identifiable {
    let codigo: String
    var id: String { codigo }
}

/// Los apuntes como en el cuaderno: importe del Debe | cuenta (con «a» si es Haber) | importe del Haber.
/// Tocar un apunte lo corrige; mantener pulsada la cuenta abre su mayor. Los corregidos a mano
/// llevan un lápiz.
struct ApuntesView: View {
    let lineas: [LineaAsiento]
    let corregir: (LineaAsiento) -> Void
    let verMayor: (String) -> Void

    var body: some View {
        ForEach(Array(lineas.enumerated()), id: \.offset) { _, linea in
            let apunte = linea.apunte
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(apunte.lado == .debe ? Importe.formatear(apunte.importe) : "")
                    .frame(width: 72, alignment: .trailing)
                Text(textoCuenta(apunte))
                    .lineLimit(1)
                    .padding(.leading, apunte.lado == .haber ? 14 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onLongPressGesture { verMayor(apunte.cuenta) }
                Text(apunte.lado == .haber ? Importe.formatear(apunte.importe) : "")
                    .frame(width: 72, alignment: .trailing)
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .opacity(linea.corregida ? 1 : 0)
            }
            .font(.footnote.monospacedDigit())
            .contentShape(Rectangle())
            .onTapGesture { corregir(linea) }
        }
    }

    private func textoCuenta(_ apunte: Apunte) -> String {
        var texto = Cuenta(apunte.cuenta)?.description ?? apunte.cuenta
        if let detalle = apunte.detalle { texto += " (\(detalle))" }
        return apunte.lado == .haber ? "a \(texto)" : texto
    }
}
