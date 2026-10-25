import SwiftUI

/// Dónde acaba cada columna de la plantilla, en proporción al ancho del lienzo.
/// La posición dice el lado: lo escrito a la izquierda es Debe y a la derecha, Haber.
enum Columnas {
    static let finDebe: CGFloat = 0.25
    static let inicioHaber: CGFloat = 0.75
}

/// Fondo del lienzo con el formato de Gema: Debe | Cuenta | Haber.
struct PlantillaView: View {
    var body: some View {
        GeometryReader { geo in
            let ancho = geo.size.width
            ZStack(alignment: .topLeading) {
                Color(uiColor: .systemBackground)
                Path { linea in
                    for x in [ancho * Columnas.finDebe, ancho * Columnas.inicioHaber] {
                        linea.move(to: CGPoint(x: x, y: 0))
                        linea.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                }
                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 6]))

                HStack(spacing: 0) {
                    Text("Debe").frame(width: ancho * Columnas.finDebe)
                    Text("Cuenta").frame(width: ancho * (Columnas.inicioHaber - Columnas.finDebe))
                    Text("Haber").frame(width: ancho * (1 - Columnas.inicioHaber))
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
