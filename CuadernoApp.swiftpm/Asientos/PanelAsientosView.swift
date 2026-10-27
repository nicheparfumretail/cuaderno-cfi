import SwiftUI

/// Panel lateral: lo reconocido de la hoja, en vivo. Cada asiento con su fecha (la eliges tú),
/// sus apuntes, si cuadra y recomendaciones. Nunca bloquea: puedes seguir escribiendo.
/// Un apunte se corrige tocándolo (mini ventana), manteniéndolo se abre la rueda y por su asa
/// se arrastra a otro asiento.
struct PanelAsientosView: View {
    @ObservedObject var editor: EditorHoja
    @EnvironmentObject private var interaccion: InteraccionHoja

    var body: some View {
        let resueltos = editor.resueltos
        let acciones = editor.acciones(interaccion: interaccion)
        ScrollViewReader { lector in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ayuda(vacia: resueltos.isEmpty)
                        .padding(12)
                    ForEach(resueltos) { resuelto in
                        let resaltado = interaccion.resaltado == resuelto.numero
                        AsientoPanel(resuelto: resuelto, acciones: acciones,
                                     cambiarFecha: { editor.ponerFecha($0, asiento: resuelto.numero - 1) },
                                     recuperar: { editor.recuperarDescartadas(asiento: resuelto.numero - 1) })
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.yellow.opacity(resaltado ? 0.4 : 0)))
                            .animation(.easeInOut(duration: 0.3), value: resaltado)
                            .id(resuelto.numero)
                        Divider()
                    }
                }
            }
            .onChange(of: interaccion.salto) { _, salto in
                guard let salto else { return }
                withAnimation(.easeInOut(duration: 0.35)) { lector.scrollTo(salto.numero, anchor: .center) }
            }
        }
    }

    @ViewBuilder
    private func ayuda(vacia: Bool) -> some View {
        if vacia {
            VStack(alignment: .leading, spacing: 10) {
                Text("Escribe el asiento en la hoja").font(.headline)
                Text("Debe a la izquierda y Haber a la derecha. La cuenta va pegada al centro y el importe en el borde:")
                    .foregroundStyle(.secondary)
                Text("1000  572   a   430  1000")
                    .font(.footnote.monospacedDigit())
                Text("Una raya por debajo cierra el asiento. Al dejar de escribir, aparece aquí.")
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Toca un apunte para corregirlo; mantenlo para la rueda. Arrástralo por ≡ a otro asiento: a la izquierda va al Debe y a la derecha al Haber.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
                ApunteFila(fila: fila, estilo: .panel, acciones: acciones)
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
        .modifier(ZonaParaSoltar(asiento: resuelto.numero - 1))
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
