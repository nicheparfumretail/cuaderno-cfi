import SwiftUI

/// Mayor de una cuenta dibujado en T: Debe a la izquierda, Haber a la derecha, y el saldo debajo.
struct MayorView: View {
    let mayor: Mayor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Debe").bold().frame(maxWidth: .infinity)
                        Text("Haber").bold().frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 6)
                    Rectangle().frame(height: 2)
                    HStack(alignment: .top, spacing: 0) {
                        columna(.debe)
                        columna(.haber)
                    }
                    .overlay { Rectangle().frame(width: 2) }
                    Divider()
                    HStack(spacing: 0) {
                        Text(Importe.formatear(mayor.sumaDebe)).frame(maxWidth: .infinity, alignment: .trailing)
                        Text(Importe.formatear(mayor.sumaHaber)).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .bold()
                    .padding(8)
                    Text(textoSaldo)
                        .font(.headline)
                        .padding(.top, 12)
                }
                .font(.body.monospacedDigit())
                .padding()
            }
            .navigationTitle(Cuenta(mayor.cuenta)?.description ?? mayor.cuenta)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cerrar") { dismiss() }
            }
        }
    }

    private var textoSaldo: String {
        let saldo = mayor.saldo < 0 ? -mayor.saldo : mayor.saldo
        switch mayor.tipoSaldo {
        case .deudor: return "Saldo deudor: \(Importe.formatear(saldo))"
        case .acreedor: return "Saldo acreedor: \(Importe.formatear(saldo))"
        case .saldado: return "Cuenta saldada (saldo 0)"
        }
    }

    private func columna(_ lado: Lado) -> some View {
        VStack(spacing: 6) {
            ForEach(mayor.movimientos.filter { lado == .debe ? $0.debe > 0 : $0.haber > 0 }) { movimiento in
                HStack {
                    Text("(\(movimiento.numero))").foregroundStyle(.secondary)
                    if let detalle = movimiento.detalle {
                        Text(detalle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(Importe.formatear(lado == .debe ? movimiento.debe : movimiento.haber))
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

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
    }

    private func celda(_ importe: Decimal) -> some View {
        Text(importe == 0 ? "" : Importe.formatear(importe))
            .frame(width: 100, alignment: .trailing)
    }
}
