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

    /// Lo que viaja al arrastrar el apunte a otro asiento (en JSON).
    var arrastre: String? {
        guard let apunte,
              let datos = try? JSONEncoder().encode(ApunteArrastrado(origen: asiento, leido: leido, apunte: apunte))
        else { return nil }
        return String(decoding: datos, as: UTF8.self)
    }
}

/// Un apunte en vuelo: de qué asiento y lectura sale y cuánto vale.
struct ApunteArrastrado: Codable {
    let origen: Int
    let leido: Correccion.Leido
    let apunte: Apunte
}

extension AsientoResuelto {
    var filasEditables: [FilaEditable] {
        var filas = lineas.map {
            FilaEditable(asiento: $0.origen, leido: $0.leido, lado: $0.apunte.lado, cuenta: $0.apunte.cuenta,
                         importe: $0.apunte.importe, corregida: $0.corregida)
        }
        // Una fila sin entender va al lado al que le falta dinero, con la cuenta si se leyó.
        let falta = leido.apuntes.map(\.haber).reduce(0, +) - leido.apuntes.map(\.debe).reduce(0, +)
        for texto in leido.noEntendido {
            filas.append(FilaEditable(asiento: numero - 1, leido: .fila(texto), lado: falta >= 0 ? .debe : .haber,
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
    let verMayor: (String) -> Void
    /// Un apunte arrastrado que se suelta en un asiento y un lado. Devuelve si se ha podido.
    let soltar: (String, Int, Lado) -> Bool
}

/// Un apunte en el panel o en En limpio. Tocándolo o manteniéndolo pulsado se abre la mini
/// ventana para corregirlo; con el asa (≡) se arrastra a otro asiento o al otro lado.
struct ApunteFila: View {
    enum Estilo { case panel, limpio }

    let fila: FilaEditable
    let estilo: Estilo
    let acciones: AccionesApunte

    @State private var editando = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            asa
            contenido
                .contentShape(Rectangle())
                .onTapGesture { editando = true }
                .onLongPressGesture(minimumDuration: 0.3) { editando = true }
                .popover(isPresented: $editando) {
                    EditorApunteMini(fila: fila, acciones: acciones) { editando = false }
                }
        }
    }

    /// El asa para arrastrar. Solo un apunte completo se puede llevar a otro sitio.
    @ViewBuilder
    private var asa: some View {
        if let arrastre = fila.arrastre {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 18)
                .contentShape(Rectangle())
                .draggable(arrastre) {
                    Text("\(fila.cuenta) · \(fila.importe.map(Importe.formatear) ?? "")")
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
        } else {
            Color.clear.frame(width: 18, height: 1)
        }
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
            Text(fila.lado == .debe ? importe : "").frame(width: 72, alignment: .trailing)
            Text(fila.lado == .haber ? "a (\(codigo)) \(nombre)" : "(\(codigo)) \(nombre)")
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(fila.lado == .haber ? importe : "").frame(width: 72, alignment: .trailing)
        }
        .font(.footnote.monospacedDigit())
        .foregroundStyle(color)
    }

    /// En limpio, como en el cuaderno. Debe: importe · nombre · (nº). Haber: (nº) · nombre · importe.
    private var limpio: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if fila.lado == .debe {
                Text(importe).frame(width: 110, alignment: .leading)
                Text(nombre).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text("(\(codigo))").foregroundStyle(.secondary)
            } else {
                Text("(\(codigo))").foregroundStyle(.secondary)
                Text(nombre).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(importe).frame(width: 110, alignment: .trailing)
            }
        }
        .foregroundStyle(color)
    }

    private var codigo: String { fila.cuenta.isEmpty ? "?" : fila.cuenta }
    private var nombre: String { PlanDeCuentas.nombre(de: fila.cuenta) ?? "" }
    private var importe: String { fila.importe.map(Importe.formatear) ?? "?" }

    private var color: Color {
        if fila.sinEntender != nil { return .orange }
        return fila.corregida ? .blue : .primary
    }
}

/// Un asiento donde se puede soltar un apunte arrastrado: en la mitad izquierda va al Debe y
/// en la derecha al Haber.
struct ZonaParaSoltar: ViewModifier {
    let asiento: Int
    let soltar: (String, Int, Lado) -> Bool

    @State private var ancho: CGFloat = 0
    @State private var encima = false

    func body(content: Content) -> some View {
        content
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { ancho = geo.size.width }
                    .onChange(of: geo.size.width) { ancho = geo.size.width }
            })
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(encima ? 0.15 : 0)))
            .dropDestination(for: String.self) { textos, punto in
                guard let texto = textos.first else { return false }
                return soltar(texto, asiento, punto.x < ancho / 2 ? .debe : .haber)
            } isTargeted: { encima = $0 }
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
