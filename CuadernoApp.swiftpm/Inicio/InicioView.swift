import SwiftUI

enum Pantalla: Hashable {
    case historico
}

/// Pantalla de inicio: un círculo con «+». Al tocarlo se abre un arco con las opciones,
/// como la paleta del Apple Pencil Pro.
struct InicioView: View {
    @StateObject private var archivo = Archivo()
    @State private var ruta = NavigationPath()
    @State private var menuAbierto = false
    @State private var preguntarApertura = false

    var body: some View {
        NavigationStack(path: $ruta) {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                    .onTapGesture { abrirMenu(false) }
                MenuCircular(abierto: menuAbierto,
                             alPulsarMas: { abrirMenu(!menuAbierto) },
                             opciones: [
                                 OpcionMenu(titulo: "Añadir asiento", icono: "square.and.pencil") {
                                     abrirMenu(false)
                                     preguntarApertura = true
                                 },
                                 OpcionMenu(titulo: "Practicar ejercicio", icono: "doc.text.image") {
                                     abrirMenu(false)
                                     ruta.append(archivo.crear(apertura: false, practica: true).id)
                                 },
                                 OpcionMenu(titulo: "Ver histórico", icono: "clock.arrow.circlepath") {
                                     abrirMenu(false)
                                     ruta.append(Pantalla.historico)
                                 },
                             ])
            }
            .navigationTitle("Cuaderno CFI")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("¿Deseas añadir el asiento inicial de apertura?",
                                isPresented: $preguntarApertura, titleVisibility: .visible) {
                Button("Sí, empezar con la apertura") { abrirHojaNueva(apertura: true) }
                Button("No") { abrirHojaNueva(apertura: false) }
                Button("Cancelar", role: .cancel) {}
            }
            .navigationDestination(for: UUID.self) { id in
                if let hoja = archivo.hoja(id) {
                    HojaView(hoja: hoja, archivo: archivo)
                }
            }
            .navigationDestination(for: Pantalla.self) { _ in
                HistoricoView(archivo: archivo)
            }
        }
    }

    private func abrirMenu(_ abierto: Bool) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { menuAbierto = abierto }
    }

    private func abrirHojaNueva(apertura: Bool) {
        ruta.append(archivo.crear(apertura: apertura).id)
    }
}

struct OpcionMenu: Identifiable {
    let titulo: String
    let icono: String
    let accion: () -> Void
    var id: String { titulo }
}

/// Botón «+» con las opciones repartidas en un arco por encima, sobre una franja translúcida.
struct MenuCircular: View {
    let abierto: Bool
    let alPulsarMas: () -> Void
    let opciones: [OpcionMenu]

    private let radio: CGFloat = 130
    private let inicioArco = 205.0
    private let finArco = 335.0

    var body: some View {
        ZStack {
            Circle()
                .trim(from: inicioArco / 360, to: finArco / 360)
                .stroke(.ultraThinMaterial, style: StrokeStyle(lineWidth: 96, lineCap: .round))
                .frame(width: radio * 2, height: radio * 2)
                .opacity(abierto ? 1 : 0)
                .scaleEffect(abierto ? 1 : 0.4)

            ForEach(Array(opciones.enumerated()), id: \.element.id) { indice, opcion in
                let angulo = anguloDe(indice) * .pi / 180
                Button(action: opcion.accion) {
                    VStack(spacing: 4) {
                        Image(systemName: opcion.icono).font(.title2)
                        Text(opcion.titulo).font(.caption2.weight(.medium)).fixedSize()
                    }
                    .frame(width: 84, height: 72)
                }
                .buttonStyle(.plain)
                .offset(x: abierto ? radio * cos(angulo) : 0, y: abierto ? radio * sin(angulo) : 0)
                .opacity(abierto ? 1 : 0)
                .scaleEffect(abierto ? 1 : 0.3)
                .allowsHitTesting(abierto)
            }

            Button(action: alPulsarMas) {
                Image(systemName: "plus")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
                    .rotationEffect(.degrees(abierto ? 45 : 0))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(abierto ? "Cerrar menú" : "Abrir menú")
        }
    }

    /// Ángulo de cada opción, repartidas por igual dentro del arco (grados; 270 = arriba).
    private func anguloDe(_ indice: Int) -> Double {
        let hueco = (finArco - inicioArco) / Double(opciones.count)
        return inicioArco + hueco * (Double(indice) + 0.5)
    }
}
