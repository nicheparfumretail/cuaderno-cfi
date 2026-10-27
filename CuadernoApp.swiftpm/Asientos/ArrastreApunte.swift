import SwiftUI

/// Arrastrar un apunte a otro asiento (o al otro lado del mismo) con el dedo, sin esperas: se
/// coge por el asa ≡ y se mueve al momento. Debajo del dedo se ve en qué asiento y en qué lado
/// caerá: la mitad izquierda del asiento es el Debe y la derecha, el Haber.
///
/// Es un objeto aparte para que, mientras el dedo se mueve, solo se redibuje la ficha que lo
/// sigue y no la lista de asientos.
@MainActor
final class ArrastreApunte: ObservableObject {
    /// Dónde caería el apunte: en qué asiento (0 = el primero), en qué lado y el marco del asiento.
    struct Destino: Equatable {
        let asiento: Int
        let lado: Lado
        let marco: CGRect
    }

    @Published private(set) var fila: FilaEditable?
    @Published private(set) var punto: CGPoint = .zero

    /// Dónde está cada asiento en pantalla, en el espacio de la hoja. Cada zona tiene su clave
    /// para que una vista que se va no borre la de la vista que llega.
    var zonas: [UUID: (asiento: Int, marco: CGRect)] = [:]

    func mover(_ fila: FilaEditable, a punto: CGPoint) {
        if self.fila != fila { self.fila = fila }
        self.punto = punto
    }

    func terminar() {
        fila = nil
    }

    func destino(en punto: CGPoint) -> Destino? {
        guard let zona = zonas.values.first(where: { $0.marco.contains(punto) }) else { return nil }
        return Destino(asiento: zona.asiento, lado: punto.x < zona.marco.midX ? .debe : .haber, marco: zona.marco)
    }
}

/// Un asiento donde se puede soltar un apunte: avisa de dónde está en pantalla.
struct ZonaParaSoltar: ViewModifier {
    let asiento: Int
    @EnvironmentObject private var interaccion: InteraccionHoja
    @State private var clave = UUID()

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geo in
                let marco = geo.frame(in: .named(InteraccionHoja.espacio))
                Color.clear
                    .onAppear { interaccion.arrastre.zonas[clave] = (asiento: asiento, marco: marco) }
                    .onChange(of: marco) { _, nuevo in interaccion.arrastre.zonas[clave] = (asiento: asiento, marco: nuevo) }
                    .onDisappear { interaccion.arrastre.zonas[clave] = nil }
            }
        }
    }
}

/// Lo que se ve mientras se arrastra: el asiento de debajo partido en «Al Debe» | «Al Haber»
/// y una ficha con el apunte junto al dedo.
struct ArrastreView: View {
    @ObservedObject var arrastre: ArrastreApunte

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let fila = arrastre.fila {
                if let destino = arrastre.destino(en: arrastre.punto) {
                    HStack(spacing: 6) {
                        mitad("Al Debe", activa: destino.lado == .debe)
                        mitad("Al Haber", activa: destino.lado == .haber)
                    }
                    .frame(width: destino.marco.width, height: max(destino.marco.height, 44))
                    .position(x: destino.marco.midX, y: destino.marco.midY)
                }
                ficha(fila)
                    .position(x: arrastre.punto.x + 60, y: arrastre.punto.y - 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private func ficha(_ fila: FilaEditable) -> some View {
        Text("(\(fila.cuenta)) \(fila.importe.map(Importe.formatear) ?? "")")
            .font(.body.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
            .fixedSize()
    }

    private func mitad(_ texto: String, activa: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.accentColor.opacity(activa ? 0.22 : 0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.accentColor.opacity(activa ? 0.9 : 0.25), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
            .overlay(alignment: .bottom) {
                Text(texto)
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(6)
                    .opacity(activa ? 1 : 0.5)
            }
    }
}
