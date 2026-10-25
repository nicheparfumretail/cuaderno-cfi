import SwiftUI

/// Fondo del lienzo con el formato de clase: Debe a la izquierda, Haber a la derecha y una franja
/// central para la fecha (que abre cada asiento) y la «a». No hay casillas: se escribe libre.
struct PlantillaView: View {
    var body: some View {
        GeometryReader { geo in
            let ancho = geo.size.width
            let margen = ancho * LectorAsientos.margenCentro
            ZStack(alignment: .topLeading) {
                Color(uiColor: .systemBackground)
                Rectangle()
                    .fill(Color.accentColor.opacity(0.05))
                    .frame(width: margen * 2)
                    .offset(x: ancho / 2 - margen)
                HStack(alignment: .top) {
                    Text("Debe").font(.title3.weight(.semibold))
                    Spacer()
                    Text("fecha\na").font(.caption).multilineTextAlignment(.center)
                    Spacer()
                    Text("Haber").font(.title3.weight(.semibold))
                }
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
