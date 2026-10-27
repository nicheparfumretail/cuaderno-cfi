import SwiftUI

struct CuentaSeleccionada: Identifiable {
    let codigo: String
    var id: String { codigo }
}

/// Un apunte tal como se puede corregir: lo que vale ahora y de qué lectura de la tinta sale.
/// Las filas que no se entendieron también se pueden corregir, con lo que se haya podido leer.
struct FilaEditable: Identifiable, Hashable {
    /// El asiento donde se leyó (0 = el primero): ahí se guarda su corrección.
    let asiento: Int
    /// El asiento donde se enseña ahora (distinto si se arrastró a otro).
    let enAsiento: Int
    let leido: Correccion.Leido
    let lado: Lado
    let cuenta: String
    let importe: Decimal?
    let corregida: Bool

    var id: String { "\(asiento)|\(leido)" }
    var apunte: Apunte? { importe.map { Apunte(lado, cuenta, $0) } }
    /// Lo escrito en una fila que no se entendió.
    var sinEntender: String? {
        if importe == nil, case .fila(let texto) = leido { return texto }
        return nil
    }
}

extension AsientoResuelto {
    var filasEditables: [FilaEditable] {
        var filas = lineas.map {
            FilaEditable(asiento: $0.origen, enAsiento: numero - 1, leido: $0.leido, lado: $0.apunte.lado,
                         cuenta: $0.apunte.cuenta, importe: $0.apunte.importe, corregida: $0.corregida)
        }
        // Una fila sin entender va al lado al que le falta dinero, con la cuenta si se leyó.
        let falta = leido.apuntes.map(\.haber).reduce(0, +) - leido.apuntes.map(\.debe).reduce(0, +)
        for texto in leido.noEntendido {
            filas.append(FilaEditable(asiento: numero - 1, enAsiento: numero - 1, leido: .fila(texto),
                                      lado: falta >= 0 ? .debe : .haber,
                                      cuenta: LectorAsientos.cuentaSinImporte(LectorAsientos.numerico(texto)) ?? "",
                                      importe: nil, corregida: false))
        }
        return filas
    }
}

/// Lo que se puede hacer con un apunte desde el panel o desde En limpio. Las dos vistas guardan
/// en el mismo sitio (las correcciones de la hoja), así que lo que se cambia en una sale en la otra.
struct AccionesApunte {
    let corregir: (FilaEditable, Apunte?) -> Void
    let volver: (FilaEditable) -> Void
    /// Abre el libro mayor de una cuenta.
    let verMayor: (String) -> Void
    /// Lleva un apunte (ya corregido) a otro asiento.
    let mover: (FilaEditable, Apunte, Int) -> Void
    /// Un apunte arrastrado que se suelta en un asiento (0 = el primero) y un lado.
    let soltar: (FilaEditable, Int, Lado) -> Void
    /// Los asientos de la hoja, para elegir a cuál va un apunte: (posición, «Nº 3 · 10/01/2025»).
    let asientos: [(indice: Int, titulo: String)]
}

/// Un apunte en el panel o en En limpio. Tocándolo se abre la mini ventana para corregirlo;
/// manteniéndolo pulsado, la rueda (modificar, libro mayor, cambiar de lado…). Por el asa (≡)
/// se arrastra al momento a otro asiento o al otro lado.
struct ApunteFila: View {
    enum Estilo { case panel, limpio }

    let fila: FilaEditable
    let estilo: Estilo
    let acciones: AccionesApunte
    @EnvironmentObject private var interaccion: InteraccionHoja
    /// Verdadero mientras el dedo lleva el apunte; si el gesto se corta, se recoge la ficha.
    @GestureState private var llevando = false

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            asa
            contenido
                .overlay {
                    // Encima de todo el apunte, para saber dónde está al mantenerlo pulsado.
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { interaccion.editando = fila.id }
                            .onLongPressGesture(minimumDuration: 0.35) {
                                let marco = geo.frame(in: .global)
                                interaccion.rueda = InteraccionHoja.Rueda(fila: fila, centro: CGPoint(x: marco.midX, y: marco.midY))
                            }
                    }
                }
                .popover(isPresented: Binding(get: { interaccion.editando == fila.id },
                                              set: { if !$0, interaccion.editando == fila.id { interaccion.editando = nil } })) {
                    EditorApunteMini(fila: fila, acciones: acciones) { interaccion.editando = nil }
                }
        }
    }

    /// El asa para arrastrar, grande para cogerla bien con el dedo. Se coge y se mueve al
    /// momento, sin mantenerla pulsada. Solo un apunte completo se puede llevar a otro sitio.
    @ViewBuilder
    private var asa: some View {
        if fila.apunte != nil {
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.secondary.opacity(llevando ? 0.3 : 0.12)))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 3, coordinateSpace: .named(InteraccionHoja.espacio))
                        .updating($llevando) { _, llevando, _ in llevando = true }
                        .onChanged { valor in interaccion.arrastre.mover(fila, a: valor.location) }
                        .onEnded { valor in soltar(en: valor.location) }
                )
                .onChange(of: llevando) { _, sigue in
                    if !sigue { interaccion.arrastre.terminar() }
                }
                .accessibilityLabel("Arrastrar el apunte a otro asiento")
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }

    /// Al soltar: si cae en un asiento, va a ese asiento y al lado de debajo del dedo.
    private func soltar(en punto: CGPoint) {
        let destino = interaccion.arrastre.destino(en: punto)
        interaccion.arrastre.terminar()
        guard let destino, destino.asiento != fila.enAsiento || destino.lado != fila.lado else { return }
        acciones.soltar(fila, destino.asiento, destino.lado)
    }

    @ViewBuilder
    private var contenido: some View {
        VStack(alignment: .leading, spacing: 2) {
            switch estilo {
            case .panel: panel
            case .limpio: limpio
            }
            if let texto = fila.sinEntender {
                Text("No lo entiendo: «\(texto)». Tócalo para completarlo.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// Panel: importe del Debe | (cuenta) nombre | importe del Haber.
    private var panel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(fila.lado == .debe ? fila.textoImporte : "").frame(width: 72, alignment: .trailing)
            Text(fila.lado == .haber ? "a (\(fila.textoCodigo)) \(fila.textoNombre)" : "(\(fila.textoCodigo)) \(fila.textoNombre)")
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(fila.lado == .haber ? fila.textoImporte : "").frame(width: 72, alignment: .trailing)
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(fila.colorTexto)
    }

    private var limpio: some View {
        FilaLimpia(fila: fila)
    }
}

extension FilaEditable {
    var textoCodigo: String { cuenta.isEmpty ? "?" : cuenta }
    var textoNombre: String { PlanDeCuentas.nombre(de: cuenta) ?? "" }
    var textoImporte: String { importe.map(Importe.formatear) ?? "?" }

    /// Naranja lo que no se entiende, azul lo corregido a mano.
    var colorTexto: Color {
        if sinEntender != nil { return .orange }
        return corregida ? .blue : .primary
    }
}

/// Un apunte en limpio, como en el cuaderno. Debe: importe · nombre · (nº). Haber: (nº) · nombre ·
/// importe. Lo usan la pantalla de En limpio y su PDF, para que se vean igual.
struct FilaLimpia: View {
    let fila: FilaEditable

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if fila.lado == .debe {
                Text(fila.textoImporte).frame(width: 110, alignment: .leading)
                Text(fila.textoNombre).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text("(\(fila.textoCodigo))").foregroundStyle(.secondary)
            } else {
                Text("(\(fila.textoCodigo))").foregroundStyle(.secondary)
                Text(fila.textoNombre).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(fila.textoImporte).frame(width: 110, alignment: .trailing)
            }
        }
        .foregroundStyle(fila.colorTexto)
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
