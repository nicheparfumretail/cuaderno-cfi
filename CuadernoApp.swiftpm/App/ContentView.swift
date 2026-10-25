import SwiftUI

/// Pantalla principal: la hoja de tinta a la izquierda y su diario en limpio, en vivo, a la derecha.
struct ContentView: View {
    @StateObject private var cuaderno = Cuaderno()
    @State private var mostrarBalance = false
    @State private var mostrarTuria = false
    @State private var confirmarHojaNueva = false

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                ZStack {
                    PlantillaView()
                    LienzoView(cuaderno: cuaderno, activo: !mostrarBalance && !mostrarTuria)
                }
                Divider()
                HojaView(cuaderno: cuaderno)
                    .frame(width: 400)
            }
            .navigationTitle("Cuaderno CFI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { barra }
            .sheet(isPresented: $mostrarBalance) {
                BalanceView(balance: BalanceComprobacion(asientos: cuaderno.asientos))
            }
            .sheet(isPresented: $mostrarTuria) {
                NavigationStack {
                    DiarioView(asientos: CasoTuria.asientos())
                        .navigationTitle("Ejemplo: caso Túria")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            Button("Cerrar") { mostrarTuria = false }
                        }
                }
            }
            .confirmationDialog("¿Empezar una hoja nueva? Se borra la tinta y su diario.",
                                isPresented: $confirmarHojaNueva, titleVisibility: .visible) {
                Button("Hoja nueva", role: .destructive) { cuaderno.hojaNueva() }
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
            if cuaderno.leyendo {
                ProgressView()
            }
            Menu {
                Button("Balance de comprobación") { mostrarBalance = true }
                ShareLink(item: cuaderno.urlDiario) {
                    Label("Exportar diario (JSON)", systemImage: "square.and.arrow.up")
                }
                Button("Ver ejemplo: caso Túria") { mostrarTuria = true }
                Divider()
                Button("Hoja nueva…", role: .destructive) { confirmarHojaNueva = true }
            } label: {
                Label("Más", systemImage: "ellipsis.circle")
            }
        }
    }
}
