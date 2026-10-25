import SwiftUI

/// Panel lateral: lo reconocido de la hoja, en vivo. Cada asiento con su fecha (la eliges tú),
/// sus apuntes, si cuadra y recomendaciones. Nunca bloquea: puedes seguir escribiendo.
/// Lo mal leído se corrige tocándolo, sin reescribir la tinta.
struct PanelAsientosView: View {
    @ObservedObject var editor: EditorHoja
    @State var cuentaMayor: CuentaSeleccionada? = nil
    @State var edicion: EdicionApunte? = nil

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
                             verMayor: { cuentaMayor = CuentaSeleccionada(codigo: $0) },
                             corregir: { edicion = $0 },
                             recuperar: { editor.recuperarDescartadas(asiento: resuelto.numero - 1) })
            }
        }
        .listStyle(.plain)
        .sheet(item: $cuentaMayor) { cuenta in
            MayorView(mayor: Mayor(cuenta: cuenta.codigo, asientos: editor.asientos))
        }
        .sheet(item: $edicion) { edicion in
            CorregirApunteView(edicion: edicion,
                               guardar: { editor.corregir(asiento: edicion.asiento, leido: edicion.leido, por: $0) },
                               volverALoLeido: { editor.quitarCorreccion(asiento: edicion.asiento, leido: edicion.leido) })
        }
    }
}

private struct AsientoPanel: View {
    let resuelto: AsientoResuelto
    let cambiarFecha: (Fecha) -> Void
    let verMayor: (String) -> Void
    let corregir: (EdicionApunte) -> Void
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

            ApuntesView(lineas: resuelto.lineas, corregir: { corregir(edicion(de: $0)) }, verMayor: verMayor)

            // Filas con números que no son un apunte: se tocan para decir qué pone.
            ForEach(resuelto.leido.noEntendido, id: \.self) { fila in
                Button { corregir(edicion(deFila: fila)) } label: {
                    Label("«\(fila)» · toca para corregir", systemImage: "questionmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            if resuelto.descartadas > 0 {
                Button("\(resuelto.descartadas) descartado\(resuelto.descartadas == 1 ? "" : "s") a mano · Recuperar",
                       action: recuperar)
                    .font(.caption)
                    .buttonStyle(.borderless)
            }

            estado
            ForEach(resuelto.avisos + resuelto.sugerencias, id: \.self) { texto in
                Label(texto, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func edicion(de linea: LineaAsiento) -> EdicionApunte {
        EdicionApunte(asiento: resuelto.numero - 1, leido: linea.leido, lado: linea.apunte.lado,
                      cuenta: linea.apunte.cuenta, importe: Importe.formatear(linea.apunte.importe),
                      corregida: linea.corregida)
    }

    /// Para una fila sin entender: la cuenta, si se lee, y el lado al que le falta dinero.
    private func edicion(deFila fila: String) -> EdicionApunte {
        let apuntes = resuelto.leido.apuntes
        let falta = apuntes.map(\.haber).reduce(0, +) - apuntes.map(\.debe).reduce(0, +)
        return EdicionApunte(asiento: resuelto.numero - 1, leido: .fila(fila), lado: falta >= 0 ? .debe : .haber,
                             cuenta: LectorAsientos.cuentaSinImporte(LectorAsientos.numerico(fila)) ?? "",
                             importe: "", corregida: false)
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
