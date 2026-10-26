import SwiftUI

/// Una hoja abierta. Arriba se elige la vista: el lienzo (tinta + panel de lo reconocido) o la
/// hoja pasada a limpio. El panel se pliega y se redimensiona arrastrando la separación.
///
/// En una práctica, el panel es el enunciado (con notas encima) y se puede ensanchar o dejar a
/// pantalla completa; la corrección no sale mientras se escribe, sino en «Solución».
///
/// De la hoja solo se sale con la flecha de arriba a la izquierda: deslizar hacia atrás está
/// apagado, porque saltaba al arrastrar la separación del panel o una página del enunciado.
struct HojaView: View {
    enum Modo: String, Identifiable {
        case lienzo = "Lienzo"
        case limpio = "En limpio"
        case solucion = "Solución"
        var id: String { rawValue }
    }

    @StateObject private var editor: EditorHoja
    @StateObject private var vista = VistaLienzo()
    @StateObject private var interaccion = InteraccionHoja()
    @State private var modo = Modo.lienzo
    @State private var panelVisible = true
    /// En una práctica: el lienzo plegado y el enunciado a toda la pantalla.
    @State private var lienzoPlegado = false
    /// Ancho del panel elegido arrastrando la separación (nil: el de partida).
    @State private var anchoPanel: CGFloat?
    @State private var anchoAlEmpezar: CGFloat?
    @State private var mostrarBalance = false
    /// Mientras se prepara el PDF (tarda un poco): se ve una rueda de espera.
    @State private var exportando = false
    @Environment(\.colorScheme) private var esquema
    @Environment(\.dismiss) private var volver

    init(hoja: Hoja, archivo: Archivo) {
        _editor = StateObject(wrappedValue: EditorHoja(hoja: hoja, archivo: archivo))
    }

    private var modos: [Modo] {
        editor.esPractica ? [.lienzo, .limpio, .solucion] : [.lienzo, .limpio]
    }

    var body: some View {
        Group {
            switch modo {
            case .lienzo: lienzo
            case .limpio: LimpioView(editor: editor, uso: editor.esPractica ? .practica : .diario)
            case .solucion: LimpioView(editor: editor, uso: .solucion)
            }
        }
        .overlay { ArrastreView(arrastre: interaccion.arrastre) }
        .coordinateSpace(name: InteraccionHoja.espacio)
        .overlay {
            if let rueda = interaccion.rueda {
                RuedaApunteView(rueda: rueda, acciones: editor.acciones(interaccion: interaccion), interaccion: interaccion)
            }
        }
        .overlay {
            if exportando {
                ProgressView("Preparando el PDF…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .environmentObject(interaccion)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background(SinGestoAtras())
        .toolbar { barra }
        .sheet(isPresented: $mostrarBalance) {
            BalanceView(balance: BalanceComprobacion(asientos: editor.asientos))
        }
        .sheet(item: $interaccion.cuentaMayor) { cuenta in
            MayorView(mayor: Mayor(cuenta: cuenta.codigo, asientos: editor.asientos),
                      sinCuadrar: asientosSinCuadrar,
                      irAAsiento: irA)
        }
        .onAppear { editor.programarLectura(espera: 0) }
        .onDisappear { editor.cerrar() }
    }

    // MARK: - Lienzo

    private var lienzo: some View {
        GeometryReader { geo in
            let practica = editor.esPractica
            let soloPanel = practica && lienzoPlegado && panelVisible
            let ancho = soloPanel ? geo.size.width : anchoDelPanel(total: geo.size.width)
            HStack(spacing: 0) {
                if !soloPanel {
                    VStack(spacing: 0) {
                        CabeceraZonas(vista: vista, zonas: editor.hoja.datos.zonas) { editor.cambiarZonas($0) }
                        ZStack {
                            PlantillaView(vista: vista, zonas: editor.hoja.datos.zonas)
                            LienzoView(editor: editor, vista: vista, paleta: interaccion.paleta, activo: lienzoActivo)
                        }
                    }
                }
                if panelVisible {
                    if !soloPanel {
                        separador(anchoTotal: geo.size.width)
                    }
                    Group {
                        if practica {
                            EnunciadoView(editor: editor)
                        } else {
                            PanelAsientosView(editor: editor)
                        }
                    }
                    .frame(width: ancho)
                    .transition(.move(edge: .trailing))
                }
            }
        }
    }

    /// El panel parte de 340 puntos (en una práctica, de casi la mitad: el enunciado se tiene
    /// que leer) y se puede ensanchar hasta el 60 % (el 85 % en una práctica).
    private func anchoDelPanel(total: CGFloat) -> CGFloat {
        let maximo = total * (editor.esPractica ? 0.85 : 0.6)
        let elegido = anchoPanel ?? (editor.esPractica ? total * 0.45 : 340)
        return min(max(elegido, 240), maximo)
    }

    /// El lienzo tiene la paleta del Pencil salvo que haya algo abierto encima.
    private var lienzoActivo: Bool {
        !mostrarBalance && interaccion.cuentaMayor == nil && interaccion.editando == nil
    }

    /// Separación arrastrable entre la hoja y el panel.
    private func separador(anchoTotal: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(Color(uiColor: .separator)).frame(width: 1)
            Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 5, height: 44)
        }
        .frame(width: 16)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { arrastre in
                    let inicial = anchoAlEmpezar ?? anchoDelPanel(total: anchoTotal)
                    anchoAlEmpezar = inicial
                    anchoPanel = inicial - arrastre.translation.width
                }
                .onEnded { _ in
                    anchoPanel = anchoDelPanel(total: anchoTotal)
                    anchoAlEmpezar = nil
                }
        )
        .accessibilityLabel("Cambiar el ancho del panel")
    }

    // MARK: - Saltos

    /// Del mayor a un asiento: se enseña donde se ven los asientos y se resalta en amarillo.
    private func irA(_ numero: Int) {
        if editor.esPractica {
            if modo == .lienzo { modo = .limpio }
        } else if modo == .lienzo && !panelVisible {
            withAnimation(.easeInOut(duration: 0.25)) { panelVisible = true }
        }
        // Cuando la hoja del mayor ya se ha ido y la vista está puesta.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            interaccion.saltar(a: numero)
        }
    }

    /// Para el aviso del mayor; en una práctica no se dice (eso es de «Solución»).
    private var asientosSinCuadrar: Int {
        guard !editor.esPractica else { return 0 }
        return editor.resueltos.filter { $0.asiento == nil && !$0.leido.apuntes.isEmpty }.count
    }

    // MARK: - Exportar

    /// Prepara el PDF (con la rueda de espera a la vista) y abre la hoja de compartir del sistema.
    private func exportar(solucion: Bool) {
        guard !exportando else { return }
        exportando = true
        let pdf = editor.pdf(solucion: solucion, oscuro: esquema == .dark)
        Task {
            // Un momento para que la rueda de espera salga antes de ponerse a dibujar.
            try? await Task.sleep(nanoseconds: 150_000_000)
            let url = await pdf.archivo()
            exportando = false
            if let url { Compartir.presentar(url) }
        }
    }

    // MARK: - Barra

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { volver() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").fontWeight(.semibold)
                    Text("Inicio")
                }
            }
            .accessibilityLabel("Volver al inicio")
        }
        ToolbarItem(placement: .principal) {
            Picker("Vista", selection: $modo) {
                ForEach(modos) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: editor.esPractica ? 330 : 240)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if editor.leyendo {
                ProgressView()
            }
            if modo == .lienzo {
                if editor.esPractica && panelVisible {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { lienzoPlegado.toggle() }
                    } label: {
                        Label(lienzoPlegado ? "Volver al lienzo" : "Enunciado a pantalla completa",
                              systemImage: lienzoPlegado ? "rectangle.split.2x1" : "arrow.up.left.and.arrow.down.right")
                    }
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        panelVisible.toggle()
                        if !panelVisible { lienzoPlegado = false }
                    }
                } label: {
                    Label(panelVisible ? "Ocultar panel" : "Mostrar panel", systemImage: "sidebar.right")
                }
            } else {
                Button {
                    exportar(solucion: modo == .solucion)
                } label: {
                    Label("Exportar en PDF", systemImage: "square.and.arrow.up")
                }
                .disabled(exportando)
            }
            Menu {
                if !editor.esPractica {
                    Button {
                        mostrarBalance = true
                    } label: {
                        Label("Balance de comprobación", systemImage: "scalemass")
                    }
                }
                Button {
                    exportar(solucion: false)
                } label: {
                    Label("Exportar en limpio (PDF)", systemImage: "doc.richtext")
                }
                if editor.esPractica {
                    Button {
                        exportar(solucion: true)
                    } label: {
                        Label("Exportar la solución (PDF)", systemImage: "checkmark.seal")
                    }
                }
                ShareLink(item: editor.exportable, preview: SharePreview("diario.json")) {
                    Label("Exportar diario (JSON)", systemImage: "curlybraces")
                }
            } label: {
                Label("Más", systemImage: "ellipsis.circle")
            }
        }
    }
}

/// Apaga los gestos de volver deslizando mientras la hoja está a la vista: el de siempre (desde el
/// borde) y el de iPadOS 26 (desde cualquier punto de la pantalla), si lo hay. Al salir de la
/// hoja vuelven a estar encendidos.
private struct SinGestoAtras: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controlador {
        Controlador()
    }

    func updateUIViewController(_ controlador: Controlador, context: Context) {}

    final class Controlador: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            for gesto in gestos { gesto.isEnabled = false }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            for gesto in gestos { gesto.isEnabled = true }
        }

        private var gestos: [UIGestureRecognizer] {
            guard let navegacion = navigationController else { return [] }
            var lista: [UIGestureRecognizer] = []
            if let borde = navegacion.interactivePopGestureRecognizer { lista.append(borde) }
            // El de iPadOS 26 se busca por su nombre: así compila también con el SDK de iOS 18.
            let nombre = "interactiveContentPopGestureRecognizer"
            if navegacion.responds(to: NSSelectorFromString(nombre)),
               let contenido = navegacion.value(forKey: nombre) as? UIGestureRecognizer {
                lista.append(contenido)
            }
            return lista
        }
    }
}
