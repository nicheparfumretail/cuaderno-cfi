import SwiftUI

/// El libro mayor de una cuenta. Arriba, su recorrido asiento a asiento como un diagrama: cada
/// parada es un asiento, lo cargado (Debe) va encima de la línea y lo abonado (Haber) debajo, con
/// las cuentas con las que se conecta y el saldo que queda entre parada y parada. Debajo, la tabla
/// entera (o la cuenta en T). Tocando un asiento se va a él en la hoja.
struct MayorView: View {
    enum Forma: String, CaseIterable, Identifiable {
        case tabla = "Tabla"
        case enT = "En T"
        var id: String { rawValue }
    }

    let mayor: Mayor
    /// Asientos de la hoja que no cuadran: no entran en el mayor hasta que cuadren.
    var sinCuadrar = 0
    var irAAsiento: ((Int) -> Void)?

    @State private var forma = Forma.tabla
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if mayor.movimientos.isEmpty {
                        ContentUnavailableView("Sin movimientos", systemImage: "book",
                                               description: Text("Esta cuenta no sale en ningún asiento que cuadre."))
                    } else {
                        if irAAsiento != nil {
                            Text("Toca un asiento para ir a él.").font(.caption).foregroundStyle(.secondary)
                        }
                        DiagramaMayor(movimientos: mayor.movimientos, ir: ir)
                        Picker("Forma", selection: $forma) {
                            ForEach(Forma.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                        switch forma {
                        case .tabla: TablaMayor(mayor: mayor, ir: ir)
                        case .enT: CuentaEnT(mayor: mayor)
                        }
                        Text(textoSaldo).font(.headline)
                    }
                    if sinCuadrar > 0 {
                        Label("\(sinCuadrar) asiento\(sinCuadrar == 1 ? "" : "s") de la hoja no cuadra\(sinCuadrar == 1 ? "" : "n"): no entra\(sinCuadrar == 1 ? "" : "n") en el mayor hasta que cuadre\(sinCuadrar == 1 ? "" : "n").",
                              systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle(Cuenta(mayor.cuenta)?.description ?? mayor.cuenta)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Cerrar") { dismiss() }
            }
        }
        .hojaGrande()
    }

    private var textoSaldo: String {
        switch Mayor.tipo(de: mayor.saldo) {
        case .deudor: return "Saldo deudor: \(Importe.formatear(abs(mayor.saldo)))"
        case .acreedor: return "Saldo acreedor: \(Importe.formatear(abs(mayor.saldo)))"
        case .saldado: return "Cuenta saldada (saldo 0)"
        }
    }

    private func ir(_ numero: Int) {
        guard let irAAsiento else { return }
        dismiss()
        irAAsiento(numero)
    }

    /// «1.000,00 D» (deudor) o «500,00 A» (acreedor).
    static func saldo(_ valor: Decimal) -> String {
        switch Mayor.tipo(de: valor) {
        case .deudor: return "\(Importe.formatear(valor)) D"
        case .acreedor: return "\(Importe.formatear(-valor)) A"
        case .saldado: return "0,00"
        }
    }
}

/// El recorrido de la cuenta: una parada por asiento, unidas por una línea con el saldo.
private struct DiagramaMayor: View {
    let movimientos: [Mayor.Movimiento]
    let ir: (Int) -> Void

    private let altoEtiqueta: CGFloat = 20
    private let altoLinea: CGFloat = 26

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(movimientos.enumerated()), id: \.element.id) { indice, movimiento in
                    if indice > 0 {
                        tramo(saldo: movimientos[indice - 1].saldo)
                    }
                    Button { ir(movimiento.numero) } label: {
                        parada(movimiento)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Asiento \(movimiento.numero)")
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.07)))
    }

    private func parada(_ movimiento: Mayor.Movimiento) -> some View {
        VStack(spacing: 0) {
            Text(movimiento.debe > 0 ? "D \(Importe.formatear(movimiento.debe))" : "")
                .font(.caption.monospacedDigit().bold())
                .frame(height: altoEtiqueta)
            ZStack {
                Rectangle().fill(Color.secondary.opacity(0.45)).frame(height: 2)
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 18, height: 18)
                    .overlay { Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 3) }
            }
            .frame(height: altoLinea)
            Text(movimiento.haber > 0 ? "H \(Importe.formatear(movimiento.haber))" : "")
                .font(.caption.monospacedDigit().bold())
                .frame(height: altoEtiqueta)
            VStack(spacing: 2) {
                Text("Nº \(movimiento.numero)").font(.subheadline.bold())
                Text(movimiento.fecha.description).font(.caption2).foregroundStyle(.secondary)
                Text(movimiento.contrapartidas.isEmpty ? " " : "con " + movimiento.contrapartidas.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 4)
        }
        .frame(width: 118)
        .contentShape(Rectangle())
    }

    /// El trozo de línea entre dos asientos, con el saldo que deja el primero.
    private func tramo(saldo: Decimal) -> some View {
        VStack(spacing: 0) {
            Text(MayorView.saldo(saldo))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(height: altoEtiqueta)
            Rectangle().fill(Color.secondary.opacity(0.45)).frame(height: 2).frame(height: altoLinea)
        }
        .frame(width: 92)
    }
}

/// La tabla del mayor: cada movimiento con su contrapartida y el saldo después de él.
private struct TablaMayor: View {
    let mayor: Mayor
    let ir: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            fila(fecha: "Fecha", numero: "Nº", contrapartida: "Contrapartida", debe: "Debe", haber: "Haber", saldo: "Saldo")
                .bold()
            Divider()
            ForEach(mayor.movimientos) { movimiento in
                Button { ir(movimiento.numero) } label: {
                    fila(fecha: movimiento.fecha.description,
                         numero: "\(movimiento.numero)",
                         contrapartida: contrapartida(movimiento),
                         debe: movimiento.debe > 0 ? Importe.formatear(movimiento.debe) : "",
                         haber: movimiento.haber > 0 ? Importe.formatear(movimiento.haber) : "",
                         saldo: MayorView.saldo(movimiento.saldo))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
            }
            fila(fecha: "", numero: "", contrapartida: "Sumas",
                 debe: Importe.formatear(mayor.sumaDebe), haber: Importe.formatear(mayor.sumaHaber),
                 saldo: MayorView.saldo(mayor.saldo))
                .bold()
        }
        .font(.footnote.monospacedDigit())
    }

    private func contrapartida(_ movimiento: Mayor.Movimiento) -> String {
        guard let primera = movimiento.contrapartidas.first else { return movimiento.concepto }
        if movimiento.contrapartidas.count > 1 {
            return movimiento.contrapartidas.joined(separator: ", ")
        }
        return "(\(primera)) \(PlanDeCuentas.nombre(de: primera) ?? "")"
    }

    private func fila(fecha: String, numero: String, contrapartida: String, debe: String, haber: String, saldo: String) -> some View {
        HStack(spacing: 6) {
            Text(fecha).frame(width: 78, alignment: .leading)
            Text(numero).frame(width: 30, alignment: .trailing)
            Text(contrapartida).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text(debe).frame(width: 86, alignment: .trailing)
            Text(haber).frame(width: 86, alignment: .trailing)
            Text(saldo).frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

/// La cuenta en T: Debe a la izquierda, Haber a la derecha y las sumas debajo.
private struct CuentaEnT: View {
    let mayor: Mayor

    var body: some View {
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
        }
        .font(.body.monospacedDigit())
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

extension View {
    /// En el iPad, la hoja que se abre encima ocupa casi toda la pantalla (cabe la tabla entera).
    @ViewBuilder
    func hojaGrande() -> some View {
        if #available(iOS 18.0, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}
