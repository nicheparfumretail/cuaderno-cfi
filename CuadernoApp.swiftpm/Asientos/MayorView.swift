import SwiftUI

/// El libro mayor de una cuenta. Arriba, su recorrido asiento a asiento como un diagrama: cada
/// parada es un asiento, lo cargado (Debe) va encima de la línea y lo abonado (Haber) debajo, con
/// las cuentas con las que se conecta y el saldo que queda entre parada y parada. Debajo, la
/// cuenta en T con su saldo o, en «Contrapartida», cada movimiento con sus contrapartidas.
/// Tocando un asiento se va a él en la hoja.
struct MayorView: View {
    enum Forma: String, CaseIterable, Identifiable {
        case enT = "En T"
        case contrapartida = "Contrapartida"
        var id: String { rawValue }
    }

    let mayor: Mayor
    /// Asientos de la hoja que no cuadran: no entran en el mayor hasta que cuadren.
    var sinCuadrar = 0
    var irAAsiento: ((Int) -> Void)?

    @State private var forma = Forma.enT
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
                        case .enT: CuentaEnT(mayor: mayor, ir: ir)
                        case .contrapartida: TablaMayor(mayor: mayor, ir: ir)
                        }
                        Text(textoSaldo).font(.headline)
                    }
                    if sinCuadrar > 0 {
                        Label(avisoSinCuadrar, systemImage: "info.circle")
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

    private var avisoSinCuadrar: String {
        sinCuadrar == 1
            ? "1 asiento de la hoja no cuadra: no entra en el mayor hasta que cuadre."
            : "\(sinCuadrar) asientos de la hoja no cuadran: no entran en el mayor hasta que cuadren."
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

    /// Una contrapartida con su nombre: «472 HP, IVA soportado», para no tener que recordarla.
    static func contrapartida(_ codigo: String) -> String {
        guard let nombre = PlanDeCuentas.nombre(de: codigo) else { return codigo }
        return "\(codigo) \(nombre)"
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
                ForEach(movimiento.contrapartidas.prefix(2), id: \.self) { codigo in
                    Text(MayorView.contrapartida(codigo))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if movimiento.contrapartidas.count > 2 {
                    Text("y \(movimiento.contrapartidas.count - 2) más").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
            .padding(.horizontal, 4)
        }
        .frame(width: 156)
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

/// Las contrapartidas: cada movimiento con las cuentas del otro lado del asiento (con su nombre)
/// y el saldo después de él.
private struct TablaMayor: View {
    let mayor: Mayor
    let ir: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            fila(fecha: "Fecha", numero: "Nº", contrapartidas: ["Contrapartida"], debe: "Debe", haber: "Haber", saldo: "Saldo")
                .bold()
            Divider()
            ForEach(mayor.movimientos) { movimiento in
                Button { ir(movimiento.numero) } label: {
                    fila(fecha: movimiento.fecha.description,
                         numero: "\(movimiento.numero)",
                         contrapartidas: contrapartidas(movimiento),
                         debe: movimiento.debe > 0 ? Importe.formatear(movimiento.debe) : "",
                         haber: movimiento.haber > 0 ? Importe.formatear(movimiento.haber) : "",
                         saldo: MayorView.saldo(movimiento.saldo))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider()
            }
            fila(fecha: "", numero: "", contrapartidas: ["Sumas"],
                 debe: Importe.formatear(mayor.sumaDebe), haber: Importe.formatear(mayor.sumaHaber),
                 saldo: MayorView.saldo(mayor.saldo))
                .bold()
        }
        .font(.footnote.monospacedDigit())
    }

    private func contrapartidas(_ movimiento: Mayor.Movimiento) -> [String] {
        movimiento.contrapartidas.isEmpty ? [movimiento.concepto] : movimiento.contrapartidas.map(MayorView.contrapartida)
    }

    private func fila(fecha: String, numero: String, contrapartidas: [String], debe: String, haber: String, saldo: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(fecha).frame(width: 78, alignment: .leading)
            Text(numero).frame(width: 30, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(contrapartidas, id: \.self) { Text($0).lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(debe).frame(width: 86, alignment: .trailing)
            Text(haber).frame(width: 86, alignment: .trailing)
            Text(saldo).frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

/// La cuenta en T: Debe a la izquierda, Haber a la derecha, las sumas debajo y el saldo en el
/// lado que pesa más (deudor si el Debe suma más; acreedor si suma más el Haber). Cada movimiento
/// lleva su número de asiento y su contrapartida.
private struct CuentaEnT: View {
    let mayor: Mayor
    let ir: (Int) -> Void

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
                celda("Suma \(Importe.formatear(mayor.sumaDebe))")
                celda("Suma \(Importe.formatear(mayor.sumaHaber))")
            }
            .bold()
            HStack(spacing: 0) {
                celda(textoSaldo(.deudor))
                celda(textoSaldo(.acreedor))
            }
            .bold()
            .foregroundStyle(Color.accentColor)
        }
        .font(.body.monospacedDigit())
    }

    private func celda(_ texto: String) -> some View {
        Text(texto)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
    }

    /// El saldo va bajo el lado que suma más; en el otro lado, nada.
    private func textoSaldo(_ tipo: TipoSaldo) -> String {
        guard Mayor.tipo(de: mayor.saldo) == tipo else { return "" }
        let importe = Importe.formatear(abs(mayor.saldo))
        return tipo == .deudor ? "Saldo deudor \(importe)" : "Saldo acreedor \(importe)"
    }

    private func columna(_ lado: Lado) -> some View {
        VStack(spacing: 8) {
            ForEach(mayor.movimientos.filter { lado == .debe ? $0.debe > 0 : $0.haber > 0 }) { movimiento in
                Button { ir(movimiento.numero) } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text("(\(movimiento.numero))").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            ForEach(movimiento.contrapartidas, id: \.self) { codigo in
                                Text(MayorView.contrapartida(codigo)).lineLimit(1)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Text(Importe.formatear(lado == .debe ? movimiento.debe : movimiento.haber))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
