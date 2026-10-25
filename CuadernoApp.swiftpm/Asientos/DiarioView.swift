import SwiftUI

struct CuentaSeleccionada: Identifiable {
    let codigo: String
    var id: String { codigo }
}

/// El libro diario en limpio, en el formato de clase: Debe | Cuenta | Haber, con la «a» del Haber.
/// Mantener pulsada una cuenta abre su mayor; deslizar un asiento, editarlo o borrarlo.
struct DiarioView: View {
    @ObservedObject var cuaderno: Cuaderno
    var editar: (Asiento) -> Void
    @State var cuentaMayor: CuentaSeleccionada? = nil

    var body: some View {
        List {
            Section {
                if cuaderno.asientos.isEmpty {
                    ContentUnavailableView("Diario vacío", systemImage: "book.closed",
                                           description: Text("Escribe un asiento en el lienzo y pulsa «Pasar a limpio»."))
                }
                ForEach(cuaderno.asientos) { asiento in
                    AsientoFila(asiento: asiento) { cuentaMayor = CuentaSeleccionada(codigo: $0) }
                        .swipeActions {
                            Button(role: .destructive) {
                                cuaderno.eliminar(id: asiento.id)
                            } label: {
                                Label("Borrar", systemImage: "trash")
                            }
                            Button {
                                editar(asiento)
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.indigo)
                        }
                }
            } footer: {
                if !cuaderno.asientos.isEmpty {
                    Text("\(cuaderno.asientos.count) asientos · EBITDA \(Importe.formatear(MapeoKPI.ebitda.valor(cuaderno.asientos)))")
                }
            }
        }
        .listStyle(.plain)
        .sheet(item: $cuentaMayor) { cuenta in
            MayorView(mayor: Mayor(cuenta: cuenta.codigo, asientos: cuaderno.asientos))
        }
    }
}

struct AsientoFila: View {
    let asiento: Asiento
    let verMayor: (String) -> Void

    var body: some View {
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

            ForEach(Array(asiento.apuntesOrdenados.enumerated()), id: \.offset) { _, apunte in
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
        .padding(.vertical, 4)
    }

    private func textoCuenta(_ apunte: Apunte) -> String {
        var texto = Cuenta(apunte.cuenta)?.description ?? apunte.cuenta
        if let detalle = apunte.detalle { texto += " (\(detalle))" }
        return apunte.lado == .haber ? "a \(texto)" : texto
    }
}
