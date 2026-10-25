import SwiftUI

/// La rueda que sale al mantener pulsado un apunte, como la paleta del Apple Pencil Pro:
/// modificar, ver su libro mayor, cambiarlo de lado, volver a lo leído o descartarlo.
struct RuedaApunteView: View {
    let rueda: InteraccionHoja.Rueda
    let acciones: AccionesApunte
    @ObservedObject var interaccion: InteraccionHoja

    @State private var abierta = false

    private struct Opcion: Identifiable {
        let titulo: String
        let icono: String
        var destructiva = false
        let accion: () -> Void
        var id: String { titulo }
    }

    private let radio: CGFloat = 74

    var body: some View {
        GeometryReader { geo in
            let origen = geo.frame(in: .global).origin
            // Que la rueda entera quepa en pantalla aunque el apunte esté en un borde.
            let x = min(max(rueda.centro.x - origen.x, radio + 50), geo.size.width - radio - 50)
            let y = min(max(rueda.centro.y - origen.y, radio + 50), geo.size.height - radio - 50)
            ZStack {
                Color.black.opacity(abierta ? 0.12 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: cerrar)
                ZStack {
                    Circle()
                        .stroke(.regularMaterial, style: StrokeStyle(lineWidth: 66))
                        .frame(width: radio * 2, height: radio * 2)
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    VStack(spacing: 0) {
                        Text(rueda.fila.cuenta.isEmpty ? "?" : rueda.fila.cuenta)
                            .font(.headline.monospacedDigit())
                        if let importe = rueda.fila.importe {
                            Text(Importe.formatear(importe)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(Array(opciones.enumerated()), id: \.element.id) { indice, opcion in
                        let angulo = (-90 + 360 / Double(opciones.count) * Double(indice)) * .pi / 180
                        Button {
                            opcion.accion()
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: opcion.icono).font(.title3)
                                Text(opcion.titulo).font(.system(size: 9, weight: .semibold)).fixedSize()
                            }
                            .foregroundStyle(opcion.destructiva ? Color.red : Color.primary)
                            .frame(width: 60, height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(opcion.titulo)
                        .offset(x: radio * cos(angulo), y: radio * sin(angulo))
                    }
                }
                .scaleEffect(abierta ? 1 : 0.4)
                .opacity(abierta ? 1 : 0)
                .position(x: x, y: y)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { abierta = true }
        }
    }

    private var opciones: [Opcion] {
        let fila = rueda.fila
        var lista = [Opcion(titulo: "Modificar", icono: "pencil") {
            interaccion.rueda = nil
            interaccion.editando = fila.id
        }]
        if let apunte = fila.apunte {
            lista.append(Opcion(titulo: "Libro mayor", icono: "book") {
                interaccion.rueda = nil
                interaccion.cuentaMayor = CuentaSeleccionada(codigo: apunte.cuenta)
            })
            let otro: Lado = apunte.lado == .debe ? .haber : .debe
            lista.append(Opcion(titulo: otro == .debe ? "Al Debe" : "Al Haber", icono: "arrow.left.arrow.right") {
                interaccion.rueda = nil
                acciones.corregir(fila, Apunte(otro, apunte.cuenta, apunte.importe))
            })
        }
        if fila.corregida {
            lista.append(Opcion(titulo: "Lo leído", icono: "arrow.uturn.backward") {
                interaccion.rueda = nil
                acciones.volver(fila)
            })
        }
        lista.append(Opcion(titulo: "Descartar", icono: "trash", destructiva: true) {
            interaccion.rueda = nil
            acciones.corregir(fila, nil)
        })
        return lista
    }

    private func cerrar() {
        withAnimation(.easeOut(duration: 0.15)) { abierta = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { interaccion.rueda = nil }
    }
}
