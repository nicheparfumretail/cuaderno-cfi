import SwiftUI

/// La hoja pasada a limpio, con letra de apuntes y el formato de clase:
///
///     Debe ———————————— 01/12/2024 ———————————— Haber
///     1.000,00  Proveedores  (400)   a   (572)  Bancos  1.000,00
///
/// También se corrige aquí: se toca una cifra o una cuenta y se escribe encima. Se guarda en el
/// mismo sitio que desde el panel del lienzo, así que lo corregido sale en las dos vistas.
struct LimpioView: View {
    @ObservedObject var editor: EditorHoja
    @State private var cuentaMayor: CuentaSeleccionada? = nil

    var body: some View {
        let resueltos = editor.resueltos
        let acciones = editor.acciones { cuentaMayor = CuentaSeleccionada(codigo: $0) }
        ScrollView {
            LazyVStack(spacing: 32) {
                if resueltos.isEmpty {
                    Text("Todavía no hay asientos en esta hoja.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                }
                ForEach(resueltos) { resuelto in
                    AsientoLimpio(resuelto: resuelto, acciones: acciones,
                                  recuperar: { editor.recuperarDescartadas(asiento: resuelto.numero - 1) })
                }
            }
            .padding(32)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(item: $cuentaMayor) { cuenta in
            MayorView(mayor: Mayor(cuenta: cuenta.codigo, asientos: editor.asientos))
        }
    }
}

private struct AsientoLimpio: View {
    let resuelto: AsientoResuelto
    let acciones: AccionesApunte
    let recuperar: () -> Void

    var body: some View {
        let filas = resuelto.filasEditables
        let debe = filas.filter { $0.lado == .debe }
        let haber = filas.filter { $0.lado == .haber }
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("Debe").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                raya
                VStack(spacing: 2) {
                    Text(resuelto.fecha.description).font(.system(.body, design: .serif).weight(.semibold))
                    if !resuelto.concepto.isEmpty {
                        Text(resuelto.concepto).font(.caption).foregroundStyle(.secondary)
                    }
                }
                raya
                Text("Haber").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
            }

            ForEach(0..<max(debe.count, haber.count), id: \.self) { fila in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    lado(fila < debe.count ? debe[fila] : nil, esDebe: true)
                    Text(fila == 0 ? "a" : "")
                        .font(.system(.body, design: .serif).italic())
                        .frame(width: 32)
                    lado(fila < haber.count ? haber[fila] : nil, esDebe: false)
                }
            }

            DescartadasView(cuantas: resuelto.descartadas, recuperar: recuperar)
            pie
        }
        .font(.system(.body, design: .serif).monospacedDigit())
    }

    private var raya: some View {
        Rectangle().fill(Color.secondary.opacity(0.5)).frame(height: 1)
    }

    /// Debe: importe · nombre · (nº). Haber: (nº) · nombre · importe. Como en el cuaderno.
    @ViewBuilder
    private func lado(_ fila: FilaEditable?, esDebe: Bool) -> some View {
        if let fila {
            ApunteEditable(fila: fila, estilo: .limpio, acciones: acciones)
                .frame(maxWidth: .infinity)
        } else {
            Spacer().frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var pie: some View {
        if resuelto.asiento == nil, !resuelto.leido.apuntes.isEmpty, case .failure(let error) = resuelto.resultado {
            Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
