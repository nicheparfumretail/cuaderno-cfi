import SwiftUI

/// Panel lateral: lo reconocido de la hoja, en vivo. Cada asiento con su fecha (la eliges tú),
/// sus apuntes, si cuadra y recomendaciones. Nunca bloquea: puedes seguir escribiendo.
/// Lo mal leído se corrige donde está: se toca la cifra o la cuenta y se escribe encima.
struct PanelAsientosView: View {
    @ObservedObject var editor: EditorHoja
    @State var cuentaMayor: CuentaSeleccionada? = nil

    var body: some View {
        let resueltos = editor.resueltos
        let acciones = editor.acciones { cuentaMayor = CuentaSeleccionada(codigo: $0) }
        List {
            if resueltos.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Escribe el asiento en la hoja").font(.headline)
                    Text("Debe a la izquierda y Haber a la derecha. La cuenta va pegada al centro y el importe en el borde:")
                        .foregroundStyle(.secondary)
                    Text("1000  572   a   430  1000")
                        .font(.footnote.monospacedDigit())
                    Text("Una raya por debajo cierra el asiento. Al dejar de escribir, aparece aquí.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Text("Toca una cifra o una cuenta para corregirla escribiendo encima; mantén pulsado para más.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ForEach(resueltos) { resuelto in
                AsientoPanel(resuelto: resuelto, acciones: acciones,
                             cambiarFecha: { editor.ponerFecha($0, asiento: resuelto.numero - 1) },
                             recuperar: { editor.recuperarDescartadas(asiento: resuelto.numero - 1) })
            }
        }
        .listStyle(.plain)
        .sheet(item: $cuentaMayor) { cuenta in
            MayorView(mayor: Mayor(cuenta: cuenta.codigo, asientos: editor.asientos))
        }
    }
}

private struct AsientoPanel: View {
    let resuelto: AsientoResuelto
    let acciones: AccionesApunte
    let cambiarFecha: (Fecha) -> Void
    let recuperar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Nº \(resuelto.numero)").font(.subheadline.bold())
                DatePicker("Fecha", selection: Binding(get: { resuelto.fecha.date },
                                                       set: { cambiarFecha(Fecha($0)) }),
                           displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                if !resuelto.concepto.isEmpty {
                    Text(resuelto.concepto).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            ForEach(resuelto.filasEditables) { fila in
                ApunteEditable(fila: fila, estilo: .panel, acciones: acciones)
            }
            DescartadasView(cuantas: resuelto.descartadas, recuperar: recuperar)

            EstadoAsiento(resuelto: resuelto)
            ForEach(resuelto.avisos + resuelto.sugerencias, id: \.self) { texto in
                Label(texto, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Si el asiento cuadra (con su efecto en el EBITDA) o cuánto falta.
struct EstadoAsiento: View {
    let resuelto: AsientoResuelto

    var body: some View {
        switch resuelto.resultado {
        case .success(let asiento):
            let impacto = MapeoKPI.ebitda.impacto(de: asiento)
            Label("Cuadra · EBITDA \(impacto > 0 ? "+" : "")\(Importe.formatear(impacto))",
                  systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let error):
            if !resuelto.leido.apuntes.isEmpty {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
