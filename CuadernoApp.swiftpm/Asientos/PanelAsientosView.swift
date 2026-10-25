import SwiftUI

/// Panel lateral: lo reconocido de la hoja, en vivo. Cada asiento con su fecha (la eliges tú),
/// sus apuntes, si cuadra y recomendaciones. Nunca bloquea: puedes seguir escribiendo.
struct PanelAsientosView: View {
    @ObservedObject var editor: EditorHoja
    @State var cuentaMayor: CuentaSeleccionada? = nil

    var body: some View {
        let resueltos = editor.resueltos
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
            }
            ForEach(resueltos) { resuelto in
                AsientoPanel(resuelto: resuelto,
                             cambiarFecha: { editor.ponerFecha($0, asiento: resuelto.numero - 1) },
                             verMayor: { cuentaMayor = CuentaSeleccionada(codigo: $0) })
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
    let cambiarFecha: (Fecha) -> Void
    let verMayor: (String) -> Void

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

            ApuntesView(apuntes: resuelto.leido.apuntes, verMayor: verMayor)

            estado
            ForEach(resuelto.avisos + resuelto.sugerencias, id: \.self) { texto in
                Label(texto, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var estado: some View {
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
