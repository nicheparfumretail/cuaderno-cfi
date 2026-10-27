import SwiftUI

/// El panel de una práctica, partido en dos: el enunciado (con notas encima) y la hoja de cálculos.
/// Se cambia cuál va arriba, cada mitad se minimiza a su barra (la otra ocupa todo) y la separación
/// se arrastra. Cómo se deja se recuerda para la próxima práctica.
struct PanelPracticaView: View {
    @ObservedObject var editor: EditorHoja
    @AppStorage("practica.calculosArriba") private var calculosArriba = false
    @AppStorage("practica.enunciadoPlegado") private var enunciadoPlegado = false
    @AppStorage("practica.calculosPlegado") private var calculosPlegado = false
    /// Parte del alto para el enunciado cuando se ven los dos.
    @AppStorage("practica.parteEnunciado") private var parteEnunciado = 0.6
    @State private var parteAlEmpezar: Double?

    private static let altoSeparador: CGFloat = 14

    private var ambasAbiertas: Bool {
        !enunciadoPlegado && !calculosPlegado
    }

    var body: some View {
        GeometryReader { geo in
            let disponible = max(geo.size.height - PanelPracticaView.altoSeparador, 1)
            VStack(spacing: 0) {
                if calculosArriba {
                    calculos
                    separacion(disponible)
                    enunciado(disponible)
                } else {
                    enunciado(disponible)
                    separacion(disponible)
                    calculos
                }
            }
        }
    }

    @ViewBuilder
    private func enunciado(_ disponible: CGFloat) -> some View {
        let vista = EnunciadoView(editor: editor, plegado: enunciadoPlegado) { plegar(enunciado: true) }
        if enunciadoPlegado {
            vista.fixedSize(horizontal: false, vertical: true)
        } else if ambasAbiertas {
            vista.frame(height: disponible * CGFloat(parteEnunciado))
        } else {
            vista.frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var calculos: some View {
        let vista = CalculosView(editor: editor, plegado: calculosPlegado,
                                 alPlegar: { plegar(enunciado: false) },
                                 alIntercambiar: intercambiar)
        if calculosPlegado {
            vista.fixedSize(horizontal: false, vertical: true)
        } else {
            vista.frame(maxHeight: .infinity)
        }
    }

    /// Con las dos mitades abiertas, una separación que se arrastra; si no, una raya.
    @ViewBuilder
    private func separacion(_ disponible: CGFloat) -> some View {
        if ambasAbiertas {
            ZStack {
                Rectangle().fill(Color(uiColor: .separator)).frame(height: 1)
                Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 44, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: PanelPracticaView.altoSeparador)
            .contentShape(Rectangle())
            .gesture(repartir(disponible))
            .accessibilityLabel("Cambiar el reparto entre el enunciado y los cálculos")
        } else {
            Divider()
        }
    }

    /// Bajar la separación agranda la mitad de arriba.
    private func repartir(_ disponible: CGFloat) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { arrastre in
                let inicial = parteAlEmpezar ?? parteEnunciado
                parteAlEmpezar = inicial
                let cambio = Double(arrastre.translation.height / disponible)
                let nueva = calculosArriba ? inicial - cambio : inicial + cambio
                parteEnunciado = min(max(nueva, 0.15), 0.85)
            }
            .onEnded { _ in
                parteAlEmpezar = nil
            }
    }

    /// Minimizar una mitad abre la otra: siempre se ve una entera.
    private func plegar(enunciado: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if enunciado {
                enunciadoPlegado.toggle()
                if enunciadoPlegado { calculosPlegado = false }
            } else {
                calculosPlegado.toggle()
                if calculosPlegado { enunciadoPlegado = false }
            }
        }
    }

    private func intercambiar() {
        withAnimation(.easeInOut(duration: 0.25)) { calculosArriba.toggle() }
    }
}
