import SwiftUI

/// Fondo de la página: la franja central (fecha y «a») entre el Debe y el Haber.
/// Sigue al zoom y al desplazamiento de la tinta.
struct PlantillaView: View {
    @ObservedObject var vista: VistaLienzo
    let zonas: Zonas

    var body: some View {
        GeometryReader { geo in
            let finDebe = vista.xPantalla(zonas.finDebe)
            let inicioHaber = vista.xPantalla(zonas.inicioHaber)
            ZStack(alignment: .topLeading) {
                Color(uiColor: .systemBackground)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.05))
                    .frame(width: max(0, inicioHaber - finDebe), height: geo.size.height)
                    .offset(x: finDebe)
                Path { linea in
                    for x in [finDebe, inicioHaber] {
                        linea.move(to: CGPoint(x: x, y: 0))
                        linea.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                }
                .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))
            }
        }
        .allowsHitTesting(false)
    }
}

/// Cabecera de la página: «Debe | fecha · a | Haber» con dos asas para ensanchar cada zona
/// (para que quepa «Hacienda Pública, acreedora…»).
struct CabeceraZonas: View {
    @ObservedObject var vista: VistaLienzo
    let zonas: Zonas
    let cambiar: (Zonas) -> Void

    var body: some View {
        GeometryReader { geo in
            let inicioPagina = vista.xPantalla(0)
            let finDebe = vista.xPantalla(zonas.finDebe)
            let inicioHaber = vista.xPantalla(zonas.inicioHaber)
            let finPagina = vista.xPantalla(1)
            let alto = geo.size.height
            ZStack(alignment: .topLeading) {
                Color(uiColor: .secondarySystemBackground)
                titulo("Debe", entre: inicioPagina, y: finDebe, alto: alto)
                titulo("fecha · a", entre: finDebe, y: inicioHaber, alto: alto)
                titulo("Haber", entre: inicioHaber, y: finPagina, alto: alto)
                asa(en: finDebe, alto: alto) { cambiar(zonas.moviendo(finDebe: vista.fraccion(xPantalla: $0))) }
                asa(en: inicioHaber, alto: alto) { cambiar(zonas.moviendo(inicioHaber: vista.fraccion(xPantalla: $0))) }
            }
            .coordinateSpace(name: "cabecera")
        }
        .frame(height: 40)
    }

    private func titulo(_ texto: String, entre desde: CGFloat, y hasta: CGFloat, alto: CGFloat) -> some View {
        Text(texto)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .position(x: (desde + hasta) / 2, y: alto / 2)
    }

    /// Asa que se arrastra en horizontal para mover un borde de zona.
    private func asa(en x: CGFloat, alto: CGFloat, mover: @escaping (CGFloat) -> Void) -> some View {
        Capsule()
            .fill(Color.accentColor)
            .frame(width: 6, height: 26)
            .frame(width: 44, height: alto)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("cabecera"))
                    .onChanged { mover($0.location.x) }
            )
            .accessibilityLabel("Mover el borde de la zona")
            .position(x: x, y: alto / 2)
    }
}
