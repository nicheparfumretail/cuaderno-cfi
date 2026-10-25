import SwiftUI

/// Pantalla principal: el lienzo con la plantilla a la izquierda y el diario en limpio a la derecha.
struct ContentView: View {
    @StateObject private var cuaderno = Cuaderno()
    @State private var borrador: Borrador?
    @State private var reconociendo = false
    @State private var mostrarBalance = false
    @State private var confirmarHojaNueva = false
    @State private var pidiendoEmpresa = false
    @State private var nombreEmpresa = ""

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                ZStack {
                    PlantillaView()
                    LienzoView(cuaderno: cuaderno, activo: borrador == nil && !mostrarBalance)
                }
                Divider()
                DiarioView(cuaderno: cuaderno) { borrador = Borrador(asiento: $0) }
                    .frame(width: 400)
            }
            .navigationTitle(cuaderno.empresa)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barra }
            .sheet(item: $borrador) { borrador in
                EditorAsientoView(cuaderno: cuaderno, borrador: borrador)
            }
            .sheet(isPresented: $mostrarBalance) {
                BalanceView(balance: BalanceComprobacion(asientos: cuaderno.asientos))
            }
            .confirmationDialog("¿Empezar una hoja nueva? Se borra la tinta; el diario no se toca.",
                                isPresented: $confirmarHojaNueva, titleVisibility: .visible) {
                Button("Hoja nueva", role: .destructive) { cuaderno.hojaNueva() }
            }
            .alert("Nueva empresa", isPresented: $pidiendoEmpresa) {
                TextField("Nombre", text: $nombreEmpresa)
                Button("Crear") {
                    let nombre = nombreEmpresa.trimmingCharacters(in: .whitespaces)
                    if !nombre.isEmpty { cuaderno.empresa = nombre }
                    nombreEmpresa = ""
                }
                Button("Cancelar", role: .cancel) { nombreEmpresa = "" }
            }
            .alert("Aviso", isPresented: Binding(get: { cuaderno.aviso != nil },
                                                 set: { if !$0 { cuaderno.aviso = nil } })) {
                Button("Vale") {}
            } message: {
                Text(cuaderno.aviso ?? "")
            }
        }
    }

    @ToolbarContentBuilder
    private var barra: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                pasarALimpio()
            } label: {
                if reconociendo {
                    ProgressView()
                } else {
                    Label("Pasar a limpio", systemImage: "text.viewfinder")
                }
            }
            .disabled(reconociendo)

            Button {
                borrador = Borrador()
            } label: {
                Label("Asiento con teclado", systemImage: "plus")
            }

            Menu {
                Picker("Empresa", selection: $cuaderno.empresa) {
                    ForEach(cuaderno.empresas, id: \.self) { Text($0).tag($0) }
                }
                Button("Nueva empresa…") { pidiendoEmpresa = true }
                Divider()
                Button("Balance de comprobación") { mostrarBalance = true }
                ShareLink(item: cuaderno.urlDiario) {
                    Label("Exportar diario (JSON)", systemImage: "square.and.arrow.up")
                }
                Button("Cargar el caso Túria") { cuaderno.cargarCasoTuria() }
                Divider()
                Button("Hoja nueva…", role: .destructive) { confirmarHojaNueva = true }
            } label: {
                Label("Más", systemImage: "ellipsis.circle")
            }
        }
    }

    /// Lee lo escrito desde el último asiento y abre el borrador para revisarlo.
    @MainActor
    private func pasarALimpio() {
        let nuevos = cuaderno.trazosSinPasar
        guard !nuevos.strokes.isEmpty else {
            cuaderno.aviso = "No hay nada escrito desde el último asiento que pasaste a limpio."
            return
        }
        let hasta = cuaderno.totalTrazos
        reconociendo = true
        Task {
            let resultado = await Reconocedor.reconocer(nuevos, anchoLienzo: cuaderno.anchoLienzo)
            reconociendo = false
            borrador = Borrador(reconocido: resultado, trazosHasta: hasta)
        }
    }
}
