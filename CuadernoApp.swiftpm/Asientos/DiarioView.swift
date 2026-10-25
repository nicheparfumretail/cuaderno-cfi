import SwiftUI

struct CuentaSeleccionada: Identifiable {
    let codigo: String
    var id: String { codigo }
}

/// Un libro diario en limpio (solo lectura), en el formato de clase. Se usa para el caso Túria.
/// Mantener pulsada una cuenta abre su mayor.
struct DiarioView: View {
    let asientos: [Asiento]
    @State var cuentaMayor: CuentaSeleccionada? = nil

    var body: some View {
        List(asientos) { asiento in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Nº \(asiento.numero)").bold()
                    Text(asiento.fecha.description)
                    if !asiento.concepto.isEmpty {
                        Text("· \(asiento.concepto)").lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                ApuntesView(apuntes: asiento.apuntesOrdenados) { cuentaMayor = CuentaSeleccionada(codigo: $0) }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
        .sheet(item: $cuentaMayor) { cuenta in
            MayorView(mayor: Mayor(cuenta: cuenta.codigo, asientos: asientos))
        }
    }
}

/// Los apuntes como en el cuaderno: importe del Debe | cuenta (con «a» si es Haber) | importe del Haber.
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
