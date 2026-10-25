import SwiftUI

/// Una hoja abierta. Arriba se elige la vista: el lienzo (tinta + panel de lo reconocido) o la
/// hoja pasada a limpio. El panel se pliega y se redimensiona arrastrando la separación.
struct HojaView: View {
    enum Modo: String, CaseIterable, Identifiable {
        case lienzo = "Lienzo"
        case limpio = "En limpio"
        var id: String { rawValue }
    }

    @StateObject private var editor: EditorHoja
    @StateObject private var vista = VistaLienzo()
    @State private var modo = Modo.lienzo
    @State private var panelVisible = true
    @State private var anchoPanel: CGFloat = 340
    @State private var anchoAlEmpezar: CGFloat?
    @State private var mostrarBalance = false

    init(hoja: Hoja, archivo: Archivo) {
        _editor = StateObject(wrappedValue: EditorHoja(hoja: hoja, archivo: archivo))
    }

    var body: some View {
        Group {
            switch modo {
            case .lienzo: lienzo
            case .limpio: LimpioView(editor: editor)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { barra }
        .sheet(isPresented: $mostrarBalance) {
            BalanceView(balance: BalanceComprobacion(asientos: editor.asientos))
        }
        .onAppear { editor.programarLectura(espera: 0) }
        .onDisappear { editor.cerrar() }
    }

    private var lienzo: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    CabeceraZonas(vista: vista, zonas: editor.hoja.datos.zonas) { editor.cambiarZonas($0) }
                    ZStack {
                        PlantillaView(vista: vista, zonas: editor.hoja.datos.zonas)
                        LienzoView(editor: editor, vista: vista, activo: !mostrarBalance)
                    }
                }
                if panelVisible {
                    separador(anchoTotal: geo.size.width)
                    PanelAsientosView(editor: editor)
                        .frame(width: anchoPanel)
                        .transition(.move(edge: .trailing))
                }
            }
        }
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
                    let inicial = anchoAlEmpezar ?? anchoPanel
                    anchoAlEmpezar = inicial
                    anchoPanel = min(max(inicial - arrastre.translation.width, 240), anchoTotal * 0.6)
                }
                .onEnded { _ in anchoAlEmpezar = nil }
        )
        .accessibilityLabel("Cambiar el ancho del panel")
    }

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Vista", selection: $modo) {
                ForEach(Modo.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if editor.leyendo {
                ProgressView()
            }
            if modo == .lienzo {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { panelVisible.toggle() }
                } label: {
                    Label(panelVisible ? "Ocultar panel" : "Mostrar panel", systemImage: "sidebar.right")
                }
            }
            Menu {
                Button("Balance de comprobación") { mostrarBalance = true }
                ShareLink(item: editor.exportable, preview: SharePreview("diario.json")) {
                    Label("Exportar diario (JSON)", systemImage: "square.and.arrow.up")
                }
            } label: {
                Label("Más", systemImage: "ellipsis.circle")
            }
        }
    }
}
