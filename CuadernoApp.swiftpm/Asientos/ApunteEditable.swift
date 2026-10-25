import SwiftUI

struct CuentaSeleccionada: Identifiable {
    let codigo: String
    var id: String { codigo }
}

/// Un apunte tal como se puede corregir: lo que vale ahora y de qué lectura de la tinta sale.
/// Las filas que no se entendieron también son editables, con lo que se haya podido leer.
struct FilaEditable: Identifiable, Hashable {
    /// Posición del asiento en la hoja (0 = el primero).
    let asiento: Int
    let leido: Correccion.Leido
    let lado: Lado
    let cuenta: String
    let importe: Decimal?
    let corregida: Bool

    var id: String { "\(asiento)|\(leido)" }
    var apunte: Apunte? { importe.map { Apunte(lado, cuenta, $0) } }
    /// Lo escrito en una fila que no se entendió, para enseñarlo debajo.
    var sinEntender: String? {
        if importe == nil, case .fila(let texto) = leido { return texto }
        return nil
    }
}

extension AsientoResuelto {
    var filasEditables: [FilaEditable] {
        let indice = numero - 1
        var filas = lineas.map {
            FilaEditable(asiento: indice, leido: $0.leido, lado: $0.apunte.lado, cuenta: $0.apunte.cuenta,
                         importe: $0.apunte.importe, corregida: $0.corregida)
        }
        // Una fila sin entender va al lado al que le falta dinero, con la cuenta si se leyó.
        let falta = leido.apuntes.map(\.haber).reduce(0, +) - leido.apuntes.map(\.debe).reduce(0, +)
        for texto in leido.noEntendido {
            filas.append(FilaEditable(asiento: indice, leido: .fila(texto), lado: falta >= 0 ? .debe : .haber,
                                      cuenta: LectorAsientos.cuentaSinImporte(LectorAsientos.numerico(texto)) ?? "",
                                      importe: nil, corregida: false))
        }
        return filas
    }
}

/// Lo que se puede hacer con un apunte desde el panel o desde En limpio. Las dos vistas guardan
/// en el mismo sitio (las correcciones de la hoja), así que lo que se corrige en una sale en la otra.
struct AccionesApunte {
    let corregir: (FilaEditable, Apunte?) -> Void
    let volver: (FilaEditable) -> Void
    let verMayor: (String) -> Void
}

/// Un apunte que se corrige donde está: se toca la cifra o la cuenta y se escribe encima con el
/// Pencil (o con el teclado). Al salir del campo se guarda; si lo escrito no vale, vuelve a lo que
/// había. Manteniendo pulsado: cambiar de lado, ver el mayor, volver a lo leído o descartar.
struct ApunteEditable: View {
    enum Estilo { case panel, limpio }
    private enum Campo { case cuenta, importe }

    let fila: FilaEditable
    let estilo: Estilo
    let acciones: AccionesApunte

    @State private var cuenta = ""
    @State private var importe = ""
    @FocusState private var campo: Campo?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch estilo {
            case .panel: panel
            case .limpio: limpio
            }
            if let texto = fila.sinEntender {
                Text("No lo entiendo: «\(texto)». Escribe la cuenta y el importe.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .contentShape(Rectangle())
        .contextMenu { menu }
        .onAppear(perform: reiniciar)
        .onChange(of: fila) { if campo == nil { reiniciar() } }
        .onChange(of: campo) { confirmar() }
    }

    // MARK: - Las dos formas de enseñarlo

    /// Panel: importe del Debe | (cuenta) nombre | importe del Haber.
    private var panel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Group { if fila.lado == .debe { campoImporte } else { Color.clear } }
                .frame(width: 76)
            if fila.lado == .haber { Text("a").italic().foregroundStyle(.secondary) }
            campoCuenta.frame(width: 52)
            Text(nombre).lineLimit(1).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group { if fila.lado == .haber { campoImporte } else { Color.clear } }
                .frame(width: 76)
        }
        .font(.footnote.monospacedDigit())
    }

    /// En limpio, como en el cuaderno. Debe: importe · nombre · (nº). Haber: (nº) · nombre · importe.
    private var limpio: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if fila.lado == .debe {
                campoImporte.frame(width: 110)
                Text(nombre).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                codigoEntreParentesis
            } else {
                codigoEntreParentesis
                Text(nombre).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                campoImporte.frame(width: 110)
            }
        }
    }

    private var codigoEntreParentesis: some View {
        HStack(spacing: 0) {
            Text("(").foregroundStyle(.secondary)
            campoCuenta.fixedSize()
            Text(")").foregroundStyle(.secondary)
        }
    }

    private var nombre: String {
        PlanDeCuentas.nombre(de: cuenta.trimmingCharacters(in: .whitespaces)) ?? ""
    }

    // MARK: - Campos

    private var campoImporte: some View {
        TextField("importe", text: $importe)
            .focused($campo, equals: .importe)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(fila.lado == .debe && estilo == .limpio ? .leading : .trailing)
            .foregroundStyle(color)
            .submitLabel(.done)
            .onSubmit { campo = nil }
    }

    private var campoCuenta: some View {
        TextField("cuenta", text: $cuenta)
            .focused($campo, equals: .cuenta)
            .keyboardType(.numbersAndPunctuation)
            .foregroundStyle(color)
            .submitLabel(.next)
            .onSubmit { campo = fila.importe == nil ? .importe : nil }
    }

    private var color: Color {
        if fila.sinEntender != nil { return .orange }
        return fila.corregida ? .blue : .primary
    }

    // MARK: - Menú

    @ViewBuilder
    private var menu: some View {
        if let apunte = fila.apunte {
            Button {
                acciones.corregir(fila, Apunte(apunte.lado == .debe ? .haber : .debe, apunte.cuenta, apunte.importe))
            } label: {
                Label(apunte.lado == .debe ? "Pasar al Haber" : "Pasar al Debe", systemImage: "arrow.left.arrow.right")
            }
            Button { acciones.verMayor(apunte.cuenta) } label: {
                Label("Mayor de la \(apunte.cuenta)", systemImage: "book")
            }
        }
        if fila.corregida {
            Button { acciones.volver(fila) } label: {
                Label("Volver a lo leído en la tinta", systemImage: "arrow.uturn.backward")
            }
        }
        Button(role: .destructive) { acciones.corregir(fila, nil) } label: {
            Label("Descartar: no es un apunte", systemImage: "trash")
        }
    }

    // MARK: - Guardar

    private func reiniciar() {
        cuenta = fila.cuenta
        importe = fila.importe.map(Importe.formatear) ?? ""
    }

    /// Al salir de un campo: si cuenta e importe valen y cambian algo, se guarda la corrección.
    /// Si no valen, vuelve lo que había (en una fila sin entender se deja, para seguir escribiendo).
    private func confirmar() {
        let codigo = LectorAsientos.numerico(cuenta).trimmingCharacters(in: .whitespaces)
        guard Cuenta(codigo) != nil, let valor = Importe.leer(LectorAsientos.numerico(importe)), valor > 0 else {
            if fila.sinEntender == nil, campo == nil { reiniciar() }
            return
        }
        let nuevo = Apunte(fila.lado, codigo, valor)
        if nuevo != fila.apunte { acciones.corregir(fila, nuevo) }
    }
}

/// Las líneas descartadas a mano de un asiento, con la forma de recuperarlas.
struct DescartadasView: View {
    let cuantas: Int
    let recuperar: () -> Void

    var body: some View {
        if cuantas > 0 {
            Button("\(cuantas) descartado\(cuantas == 1 ? "" : "s") a mano · Recuperar", action: recuperar)
                .font(.caption)
                .buttonStyle(.borderless)
        }
    }
}
