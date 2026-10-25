import SwiftUI

/// La mini ventana para corregir un apunte, junto a él: Debe o Haber, el número de la cuenta
/// (su nombre sale solo), el importe y ✓. Viene rellena con lo que se haya leído de la tinta.
///
/// Si no se sabe el número, se toca el nombre: se escribe una parte («mercad», «47») o se elige
/// del cuadro de cuentas del PGC.
struct EditorApunteMini: View {
    private enum Campo { case cuenta, importe, busqueda }

    let fila: FilaEditable
    let acciones: AccionesApunte
    let cerrar: () -> Void

    @State private var lado: Lado
    @State private var cuenta: String
    @State private var importe: String
    @State private var buscando = false
    @State private var busqueda = ""
    @FocusState private var campo: Campo?

    init(fila: FilaEditable, acciones: AccionesApunte, cerrar: @escaping () -> Void) {
        self.fila = fila
        self.acciones = acciones
        self.cerrar = cerrar
        _lado = State(initialValue: fila.lado)
        _cuenta = State(initialValue: fila.cuenta)
        _importe = State(initialValue: (fila.importe ?? EditorApunteMini.importeSuelto(en: fila)).map(Importe.formatear) ?? "")
    }

    /// El apunte, si la cuenta es un código del PGC y el importe es positivo.
    private var apunte: Apunte? {
        let codigo = LectorAsientos.numerico(cuenta).trimmingCharacters(in: .whitespaces)
        guard Cuenta(codigo) != nil, let valor = Importe.leer(LectorAsientos.numerico(importe)), valor > 0 else { return nil }
        return Apunte(lado, codigo, valor)
    }

    private var nombre: String? {
        PlanDeCuentas.nombre(de: LectorAsientos.numerico(cuenta).trimmingCharacters(in: .whitespaces))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(leido)
                .font(.caption)
                .foregroundStyle(fila.sinEntender == nil ? Color.secondary : Color.orange)
                .lineLimit(2)

            Picker("Lado", selection: $lado) {
                Text("Debe").tag(Lado.debe)
                Text("Haber").tag(Lado.haber)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                TextField("Cuenta", text: $cuenta)
                    .focused($campo, equals: .cuenta)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.title3.monospacedDigit())
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
                    .onSubmit { campo = .importe }
                Button {
                    buscando.toggle()
                    campo = buscando ? .busqueda : nil
                } label: {
                    HStack {
                        Text(nombre ?? "Elige la cuenta…")
                            .foregroundStyle(nombre == nil ? Color.secondary : Color.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: buscando ? "chevron.up" : "chevron.down").font(.caption)
                    }
                }
                .buttonStyle(.borderless)
            }

            if buscando { cuadroDeCuentas }

            TextField("Importe", text: $importe)
                .focused($campo, equals: .importe)
                .keyboardType(.decimalPad)
                .font(.title3.monospacedDigit())
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit(aceptar)

            HStack(spacing: 18) {
                if let actual = fila.apunte {
                    Button {
                        cerrar()
                        // El mayor se abre cuando la mini ventana ya se ha cerrado.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { acciones.verMayor(actual.cuenta) }
                    } label: {
                        Image(systemName: "book")
                    }
                    .accessibilityLabel("Mayor de la \(actual.cuenta)")
                }
                if fila.corregida {
                    Button { acciones.volver(fila); cerrar() } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .accessibilityLabel("Volver a lo leído en la tinta")
                }
                Button(role: .destructive) { acciones.corregir(fila, nil); cerrar() } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Descartar: no es un apunte")
                Spacer()
                Button(action: cerrar) {
                    Image(systemName: "xmark.circle.fill").font(.title)
                }
                .foregroundStyle(.secondary)
                Button(action: aceptar) {
                    Image(systemName: "checkmark.circle.fill").font(.title)
                }
                .disabled(apunte == nil)
                .accessibilityLabel("Aceptar")
            }
            .buttonStyle(.borderless)
        }
        .padding(18)
        .frame(width: 400)
        .onAppear {
            // El primer campo vacío, listo para escribir encima con el Pencil.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                campo = cuenta.isEmpty || nombre == nil ? .cuenta : .importe
            }
        }
    }

    /// El cuadro de cuentas, filtrado por lo que se escriba (número o nombre).
    private var cuadroDeCuentas: some View {
        VStack(spacing: 6) {
            TextField("Busca por número o nombre", text: $busqueda)
                .focused($campo, equals: .busqueda)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(PlanDeCuentas.buscar(busqueda).prefix(80)), id: \.codigo) { opcion in
                        Button {
                            cuenta = opcion.codigo
                            buscando = false
                            campo = .importe
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(opcion.codigo).monospacedDigit().frame(width: 50, alignment: .leading)
                                Text(opcion.nombre).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
            .frame(height: 220)
        }
    }

    private var leido: String {
        switch fila.leido {
        case .apunte(let leido):
            return "Leído: \(leido.lado == .debe ? "Debe" : "Haber") · \(leido.cuenta) · \(Importe.formatear(leido.importe))"
        case .fila(let texto):
            return "No lo entiendo: «\(texto)»"
        }
    }

    private func aceptar() {
        guard let apunte else { return }
        if apunte != fila.apunte { acciones.corregir(fila, apunte) }
        cerrar()
    }

    /// En una fila sin entender, el primer número que puede ser un importe (no la cuenta).
    private static func importeSuelto(en fila: FilaEditable) -> Decimal? {
        guard let texto = fila.sinEntender else { return nil }
        return LectorAsientos.trozosNumericos(LectorAsientos.numerico(texto))
            .filter { $0 != fila.cuenta }
            .compactMap { Importe.leer($0) }
            .first { $0 > 0 }
    }
}
