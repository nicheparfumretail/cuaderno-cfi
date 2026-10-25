import SwiftUI

/// Revisar y corregir un asiento antes de que entre en el diario. Mientras se escribe dice si
/// cuadra y, si no, cuánto falta y en qué lado. Con el Pencil se puede escribir en los campos (Scribble).
struct EditorAsientoView: View {
    @ObservedObject var cuaderno: Cuaderno
    @State var borrador: Borrador
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if !borrador.noEntendido.isEmpty {
                    Section("Esto no lo he entendido del lienzo") {
                        ForEach(borrador.noEntendido, id: \.self) { linea in
                            Text(linea).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    DatePicker("Fecha", selection: $borrador.fecha, displayedComponents: .date)
                    TextField("Concepto (p. ej. Op. 24 — Factura del alquiler)", text: $borrador.concepto)
                }
                Section("Apuntes") {
                    ForEach($borrador.filas) { $fila in
                        FilaEditor(fila: $fila)
                    }
                    .onDelete { borrador.filas.remove(atOffsets: $0) }
                    Button {
                        borrador.filas.append(FilaBorrador(lado: .haber))
                    } label: {
                        Label("Añadir apunte", systemImage: "plus")
                    }
                }
                Section { resumen }
            }
            .navigationTitle(borrador.original.map { "Asiento nº \($0.numero)" } ?? "Nuevo asiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Al diario") { guardar() }
                        .disabled(!esValido)
                }
            }
        }
    }

    private var esValido: Bool {
        if case .success = borrador.construir(empresa: cuaderno.empresa) { return true }
        return false
    }

    @ViewBuilder
    private var resumen: some View {
        let sumas = borrador.sumas
        HStack {
            Text("Σ Debe \(Importe.formatear(sumas.debe))")
            Spacer()
            Text("Σ Haber \(Importe.formatear(sumas.haber))")
        }
        .font(.body.monospacedDigit())
        switch borrador.construir(empresa: cuaderno.empresa) {
        case .success(let asiento):
            Label("Cuadra: Debe = Haber", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            let impacto = MapeoKPI.ebitda.impacto(de: asiento)
            Label("Mueve el EBITDA: \(impacto > 0 ? "+" : "")\(Importe.formatear(impacto))",
                  systemImage: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.secondary)
        case .failure(let error):
            Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func guardar() {
        guard case .success(let asiento) = borrador.construir(empresa: cuaderno.empresa) else { return }
        do {
            if borrador.original != nil {
                cuaderno.reemplazar(asiento)
            } else {
                try cuaderno.añadir(asiento)
            }
            if let hasta = borrador.trazosHasta {
                cuaderno.marcarProcesados(hasta: hasta)
            }
            dismiss()
        } catch {
            cuaderno.aviso = error.localizedDescription
        }
    }
}

private struct FilaEditor: View {
    @Binding var fila: FilaBorrador

    var body: some View {
        HStack(spacing: 12) {
            Picker("Lado", selection: $fila.lado) {
                Text("Debe").tag(Lado.debe)
                Text("Haber").tag(Lado.haber)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 140)

            TextField("Cuenta", text: $fila.cuenta)
                .keyboardType(.numbersAndPunctuation)
                .frame(width: 80)

            VStack(alignment: .leading, spacing: 2) {
                Text(PlanDeCuentas.nombre(de: fila.cuenta) ?? (fila.cuenta.isEmpty ? "" : "Cuenta sin nombre en la tabla"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                TextField("Detalle (tercero)", text: $fila.detalle)
                    .font(.caption)
            }

            TextField("Importe", text: $fila.importe)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(width: 110)
        }
    }
}
