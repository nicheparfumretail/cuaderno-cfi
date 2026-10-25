import SwiftUI

/// El diario en limpio de la hoja, en vivo: cada asiento escrito a mano aparece aquí ordenado,
/// con su cuadre. Lo que no se ha podido leer sale en rojo para corregirlo en la tinta.
struct HojaView: View {
    @ObservedObject var cuaderno: Cuaderno
    @State var cuentaMayor: CuentaSeleccionada? = nil

    var body: some View {
        List {
            if cuaderno.hoja.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Escribe un asiento en el lienzo").font(.headline)
                    Text("La fecha en el centro abre el asiento. Debajo, el Debe a la izquierda y el Haber a la derecha, con el número de cuenta entre paréntesis:")
                        .foregroundStyle(.secondary)
                    Text("01/12/24\n1.000,00 Proveedores (400)  a  (572) Bancos 1.000,00")
                        .font(.footnote.monospacedDigit())
                    Text("Al dejar de escribir, aparece aquí en limpio.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            ForEach(Array(cuaderno.hoja.enumerated()), id: \.offset) { indice, leido in
                AsientoLeidoView(numero: indice + 1, leido: leido) { cuentaMayor = CuentaSeleccionada(codigo: $0) }
            }
        }
        .listStyle(.plain)
        .sheet(item: $cuentaMayor) { cuenta in
            MayorView(mayor: Mayor(cuenta: cuenta.codigo, asientos: cuaderno.asientos))
        }
    }
}

private struct AsientoLeidoView: View {
    let numero: Int
    let leido: AsientoLeido
    let verMayor: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Nº \(numero)").bold()
                Text(leido.fecha?.description ?? "sin fecha")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ApuntesView(apuntes: leido.apuntes, verMayor: verMayor)

            ForEach(leido.noEntendido, id: \.self) { linea in
                Label("No leo: «\(linea)». Escribe importe y (nº de cuenta).", systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            estado
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var estado: some View {
        switch leido.asiento(empresa: Cuaderno.empresa, numero: numero) {
        case .success(let asiento):
            let impacto = MapeoKPI.ebitda.impacto(de: asiento)
            Label("Cuadra · EBITDA \(impacto > 0 ? "+" : "")\(Importe.formatear(impacto))",
                  systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let error):
            if !leido.apuntes.isEmpty {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}
