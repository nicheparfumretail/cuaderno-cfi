import SwiftUI

/// Las hojas guardadas, la más reciente primero. Tocar una la abre; deslizar, la borra.
struct HistoricoView: View {
    @ObservedObject var archivo: Archivo
    @State private var paraBorrar: UUID?

    var body: some View {
        List {
            if archivo.hojas.isEmpty {
                ContentUnavailableView("Todavía no hay hojas", systemImage: "book.closed",
                                       description: Text("Vuelve al inicio y pulsa + → Añadir asiento."))
            }
            ForEach(archivo.hojas) { hoja in
                NavigationLink(value: hoja.id) {
                    FilaHoja(hoja: hoja)
                }
                .swipeActions {
                    Button("Borrar", role: .destructive) { paraBorrar = hoja.id }
                }
            }
        }
        .navigationTitle("Histórico")
        .confirmationDialog("¿Borrar esta hoja? Se pierden su tinta y sus asientos.",
                            isPresented: Binding(get: { paraBorrar != nil }, set: { if !$0 { paraBorrar = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                if let id = paraBorrar { archivo.borrar(id) }
                paraBorrar = nil
            }
        }
    }
}

private struct FilaHoja: View {
    let hoja: Hoja

    var body: some View {
        let resueltos = hoja.resueltos
        let descuadrados = resueltos.filter { $0.asiento == nil }.count
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Hoja del \(Fecha(hoja.creada).description)").font(.headline)
                if hoja.datos.esApertura {
                    Text("Apertura")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                }
            }
            Group {
                if resueltos.isEmpty {
                    Text("Sin asientos todavía")
                } else if descuadrados == 0 {
                    Text("\(resueltos.count) asientos · todos cuadran").foregroundStyle(.green)
                } else {
                    Text("\(resueltos.count) asientos · \(descuadrados) sin cuadrar").foregroundStyle(.orange)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}
