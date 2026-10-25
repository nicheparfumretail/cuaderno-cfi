import SwiftUI

/// Balance de comprobación de sumas y saldos de la empresa activa.
struct BalanceView: View {
    let balance: BalanceComprobacion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(balance.lineas) { linea in
                        HStack {
                            Text(Cuenta(linea.cuenta)?.description ?? linea.cuenta)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            celda(linea.sumaDebe)
                            celda(linea.sumaHaber)
                            celda(linea.saldoDeudor)
                            celda(linea.saldoAcreedor)
                        }
                    }
                } header: {
                    HStack {
                        Text("Cuenta").frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(["Σ Debe", "Σ Haber", "S. deudor", "S. acreedor"], id: \.self) {
                            Text($0).frame(width: 100, alignment: .trailing)
                        }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Totales").frame(maxWidth: .infinity, alignment: .leading)
                            celda(balance.totalSumaDebe)
                            celda(balance.totalSumaHaber)
                            celda(balance.totalSaldoDeudor)
                            celda(balance.totalSaldoAcreedor)
                        }
                        .bold()
                        Label(balance.cuadra ? "Cuadra: sumas y saldos iguales en los dos lados"
                                             : "No cuadra: revisa los asientos",
                              systemImage: balance.cuadra ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(balance.cuadra ? Color.green : Color.red)
                    }
                }
            }
            .font(.footnote.monospacedDigit())
            .navigationTitle("Balance de comprobación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cerrar") { dismiss() }
            }
        }
        .hojaGrande()
    }

    private func celda(_ importe: Decimal) -> some View {
        Text(importe == 0 ? "" : Importe.formatear(importe))
            .frame(width: 100, alignment: .trailing)
    }
}
