import SwiftUI

/// La calculadora flotante. Va en la raíz de la app, por encima de todo: se abre desde la barra de
/// la hoja y sigue a la vista aunque se cambie de hoja o se vuelva al inicio. Se mueve arrastrando
/// su barra de arriba, se minimiza a una píldora con el número de la pantalla (para que no tape el
/// lienzo) y recuerda dónde se dejó.
///
/// No es la Calculadora de Apple: iPadOS no deja que otra app se quede flotando encima de esta.
struct CapaCalculadora: View {
    @AppStorage("calculadora.abierta") private var abierta = false
    @AppStorage("calculadora.minimizada") private var minimizada = false
    @AppStorage("calculadora.cientifica") private var cientifica = true
    @AppStorage("calculadora.x") private var centroX = -1.0
    @AppStorage("calculadora.y") private var centroY = -1.0
    @State private var calculadora = Calculadora()
    @GestureState private var arrastre = CGSize.zero

    var body: some View {
        GeometryReader { geo in
            if abierta {
                if minimizada {
                    pildora(en: geo.size)
                } else {
                    ventana(en: geo.size)
                }
            }
        }
    }

    private func ventana(en espacio: CGSize) -> some View {
        let tamaño = TecladoCalculadora.tamaño(cientifica: cientifica)
        let centro = colocar(tamaño, en: espacio)
        return VStack(spacing: 0) {
            cabecera
                .gesture(mover(tamaño, en: espacio))
            TecladoCalculadora(calculadora: $calculadora, cientifica: $cientifica)
        }
        .padding(TecladoCalculadora.margen)
        .frame(width: tamaño.width, height: tamaño.height)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color.black))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        .environment(\.colorScheme, .dark)
        .position(centro)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    /// La barra de arriba: de aquí se arrastra. A la izquierda, minimizar; a la derecha, cerrar.
    private var cabecera: some View {
        ZStack {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
            HStack {
                Button {
                    cambiar { minimizada = true }
                } label: {
                    Image(systemName: "minus").frame(width: 32, height: 28)
                }
                .accessibilityLabel("Minimizar la calculadora")
                Spacer()
                Button {
                    cambiar { abierta = false }
                } label: {
                    Image(systemName: "xmark").frame(width: 32, height: 28)
                }
                .accessibilityLabel("Cerrar la calculadora")
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(Color(white: 0.6))
        .frame(height: TecladoCalculadora.altoCabecera)
        .contentShape(Rectangle())
    }

    /// Minimizada: una píldora con el número de la pantalla. Se toca para abrirla y se arrastra.
    private func pildora(en espacio: CGSize) -> some View {
        let tamaño = CGSize(width: 200, height: 48)
        let centro = colocar(tamaño, en: espacio)
        return HStack(spacing: 10) {
            Image(systemName: "plus.forwardslash.minus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(TecladoCalculadora.naranja)
            Text(calculadora.pantalla)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(width: tamaño.width, height: tamaño.height)
        .background(Capsule().fill(Color.black))
        .overlay(Capsule().stroke(Color.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .contentShape(Capsule())
        .onTapGesture { cambiar { minimizada = false } }
        .gesture(mover(tamaño, en: espacio))
        .accessibilityLabel("Abrir la calculadora")
        .position(centro)
        .transition(.scale(scale: 0.8).combined(with: .opacity))
    }

    private func cambiar(_ cambio: () -> Void) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { cambio() }
    }

    // MARK: - Dónde va

    private func mover(_ tamaño: CGSize, en espacio: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .updating($arrastre) { valor, estado, _ in
                estado = valor.translation
            }
            .onEnded { valor in
                let base = centroGuardado(tamaño, en: espacio)
                let destino = CGPoint(x: base.x + valor.translation.width, y: base.y + valor.translation.height)
                let final = limitar(destino, tamaño, en: espacio)
                centroX = Double(final.x)
                centroY = Double(final.y)
            }
    }

    private func colocar(_ tamaño: CGSize, en espacio: CGSize) -> CGPoint {
        let base = centroGuardado(tamaño, en: espacio)
        let punto = CGPoint(x: base.x + arrastre.width, y: base.y + arrastre.height)
        return limitar(punto, tamaño, en: espacio)
    }

    /// Donde se dejó o, la primera vez, abajo a la derecha: encima del panel, lejos del lienzo.
    private func centroGuardado(_ tamaño: CGSize, en espacio: CGSize) -> CGPoint {
        let porDefecto = CGPoint(x: espacio.width - tamaño.width / 2 - 20,
                                 y: espacio.height - tamaño.height / 2 - 20)
        let guardado = centroX < 0 ? porDefecto : CGPoint(x: centroX, y: centroY)
        return limitar(guardado, tamaño, en: espacio)
    }

    /// Siempre entera dentro de la pantalla, también al girar el iPad.
    private func limitar(_ punto: CGPoint, _ tamaño: CGSize, en espacio: CGSize) -> CGPoint {
        let margen: CGFloat = 8
        let minX = tamaño.width / 2 + margen
        let maxX = espacio.width - tamaño.width / 2 - margen
        let minY = tamaño.height / 2 + margen
        let maxY = espacio.height - tamaño.height / 2 - margen
        let x = minX <= maxX ? min(max(punto.x, minX), maxX) : espacio.width / 2
        let y = minY <= maxY ? min(max(punto.y, minY), maxY) : espacio.height / 2
        return CGPoint(x: x, y: y)
    }
}
