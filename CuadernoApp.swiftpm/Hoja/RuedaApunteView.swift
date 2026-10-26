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
            ZStack {
                Color.black.opacity(abierta ? 0.25 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: cerrar)
                ruedaCompleta
                    .scaleEffect(abierta ? 1 : 0.4)
                    .opacity(abierta ? 1 : 0)
                    .position(centro(en: geo))
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { abierta = true }
        }
    }

    /// Donde se pone la rueda: sobre el apunte, pero entera dentro de la pantalla aunque el
    /// apunte esté en un borde.
    private func centro(en geo: GeometryProxy) -> CGPoint {
        let origen: CGPoint = geo.frame(in: .global).origin
        let margen: CGFloat = radio + 50
        let x: CGFloat = min(max(rueda.centro.x - origen.x, margen), geo.size.width - margen)
        let y: CGFloat = min(max(rueda.centro.y - origen.y, margen), geo.size.height - margen)
        return CGPoint(x: x, y: y)
    }

    /// La rueda es un disco esmerilado entero: lo que hay detrás (el nombre de la cuenta, otros
    /// apuntes) se difumina y no se mezcla con las letras de la rueda. El centro, casi opaco,
    /// deja la cuenta bien a la vista.
    private var ruedaCompleta: some View {
        let lista = opciones
        let exterior: CGFloat = (radio + 34) * 2
        let interior: CGFloat = (radio - 30) * 2
        return ZStack {
            Circle()
                .fill(.regularMaterial)
                .frame(width: exterior, height: exterior)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 5)
            Circle()
                .fill(.ultraThickMaterial)
                .frame(width: interior, height: interior)
                .overlay { Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1) }
            rotulo
            ForEach(Array(lista.enumerated()), id: \.element.id) { indice, opcion in
                boton(opcion)
                    .offset(desplazamiento(indice, de: lista.count))
            }
        }
    }

    /// En el centro, el apunte: su cuenta y su importe.
    private var rotulo: some View {
        VStack(spacing: 0) {
            Text(rueda.fila.cuenta.isEmpty ? "?" : rueda.fila.cuenta)
                .font(.title3.monospacedDigit().bold())
            if let importe = rueda.fila.importe {
                Text(Importe.formatear(importe)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    private func boton(_ opcion: Opcion) -> some View {
        Button(action: opcion.accion) {
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
    }

    /// Las opciones, repartidas por igual alrededor del círculo y empezando arriba.
    private func desplazamiento(_ indice: Int, de total: Int) -> CGSize {
        let grados: Double = -90 + 360 / Double(max(total, 1)) * Double(indice)
        let angulo: Double = grados * Double.pi / 180
        return CGSize(width: radio * CGFloat(cos(angulo)), height: radio * CGFloat(sin(angulo)))
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
