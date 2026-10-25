import SwiftUI

/// La hoja pasada a limpio, con letra de apuntes y el formato de clase:
///
///     Debe ———————————— 01/12/2024 ———————————— Haber
///     1.000,00  Proveedores  (400)   a   (572)  Bancos  1.000,00
struct LimpioView: View {
    let resueltos: [AsientoResuelto]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 32) {
                if resueltos.isEmpty {
                    Text("Todavía no hay asientos en esta hoja.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 60)
                }
                ForEach(resueltos) { AsientoLimpio(resuelto: $0) }
            }
            .padding(32)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

private struct AsientoLimpio: View {
    let resuelto: AsientoResuelto

    var body: some View {
        let debe = resuelto.leido.apuntes.filter { $0.lado == .debe }
        let haber = resuelto.leido.apuntes.filter { $0.lado == .haber }
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

            pie
        }
        .font(.system(.body, design: .serif).monospacedDigit())
    }

    private var raya: some View {
        Rectangle().fill(Color.secondary.opacity(0.5)).frame(height: 1)
    }

    /// Debe: importe · nombre · (nº). Haber: (nº) · nombre · importe. Como en el cuaderno.
    @ViewBuilder
    private func lado(_ apunte: Apunte?, esDebe: Bool) -> some View {
        if let apunte {
            let importe = Text(Importe.formatear(apunte.importe)).frame(width: 110, alignment: esDebe ? .leading : .trailing)
            let nombre = Text(PlanDeCuentas.nombre(de: apunte.cuenta) ?? "").lineLimit(1).minimumScaleFactor(0.7)
            let codigo = Text("(\(apunte.cuenta))").foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if esDebe {
                    importe
                    nombre
                    Spacer(minLength: 4)
                    codigo
                } else {
                    codigo
                    nombre
                    Spacer(minLength: 4)
                    importe
                }
            }
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
