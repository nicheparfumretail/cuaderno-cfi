import SwiftUI

/// La hoja pasada a limpio, con letra de apuntes y el formato de clase:
///
///     Debe ———————————— 01/12/2024 ———————————— Haber
///     1.000,00  Proveedores  (400)   a   (572)  Bancos  1.000,00
///
/// Se amplía pellizcando (o con − y +). También se corrige aquí: la fecha, cada apunte
/// (tocándolo o manteniéndolo para la rueda) y su sitio (arrastrándolo por ≡ a otro asiento o al
/// otro lado). Se guarda en el mismo sitio que desde el panel del lienzo, así que lo cambiado
/// sale en las dos vistas.
///
/// En una práctica no dice si cuadra: lo dice «Solución», que es esta misma vista con la
/// corrección de cada asiento.
struct LimpioView: View {
    enum Uso { case diario, practica, solucion }

    @ObservedObject var editor: EditorHoja
    let uso: Uso
    @EnvironmentObject private var interaccion: InteraccionHoja

    @State private var escala: CGFloat = 1
    @State private var escalaAlEmpezar: CGFloat?
    @State private var alto: CGFloat = 0

    private static let escalaMinima: CGFloat = 0.6
    private static let escalaMaxima: CGFloat = 3

    var body: some View {
        let resueltos = editor.resueltos
        let acciones = editor.acciones(interaccion: interaccion)
        GeometryReader { geo in
            let ancho = min(geo.size.width, 1000)
            ScrollViewReader { lector in
                ScrollView([.vertical, .horizontal]) {
                    hoja(resueltos, acciones)
                        .frame(width: ancho)
                        .fixedSize(horizontal: false, vertical: true)
                        .background {
                            GeometryReader { medida in
                                Color.clear
                                    .onAppear { alto = medida.size.height }
                                    .onChange(of: medida.size.height) { _, nuevo in alto = nuevo }
                            }
                        }
                        // Ampliar es dibujar más grande la misma hoja: el hueco que ocupa en la
                        // vista crece igual, para poder recorrerla entera.
                        .scaleEffect(escala, anchor: .topLeading)
                        .frame(width: ancho * escala, height: alto * escala, alignment: .topLeading)
                        .frame(width: max(ancho * escala, geo.size.width))
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .simultaneousGesture(pellizco)
                .onChange(of: interaccion.salto) { _, salto in
                    guard let salto else { return }
                    // Para saltar, la hoja vuelve a su tamaño: así el asiento queda donde toca.
                    escala = 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.35)) { lector.scrollTo(salto.numero, anchor: .center) }
                    }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) { controlZoom }
        .background(Color(uiColor: .systemBackground))
    }

    private func hoja(_ resueltos: [AsientoResuelto], _ acciones: AccionesApunte) -> some View {
        VStack(spacing: 32) {
            if uso == .solucion {
                ResumenSolucion(resueltos: resueltos)
            }
            if resueltos.isEmpty {
                Text("Todavía no hay asientos en esta hoja.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)
            }
            ForEach(resueltos) { resuelto in
                let resaltado = interaccion.resaltado == resuelto.numero
                AsientoLimpio(resuelto: resuelto, uso: uso, interactivo: AsientoLimpio.Interactivo(
                    acciones: acciones,
                    cambiarFecha: { editor.ponerFecha($0, asiento: resuelto.numero - 1) },
                    recuperar: { editor.recuperarDescartadas(asiento: resuelto.numero - 1) }))
                    .modifier(ZonaParaSoltar(asiento: resuelto.numero - 1))
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(resaltado ? 0.4 : 0)))
                    .animation(.easeInOut(duration: 0.3), value: resaltado)
                    .id(resuelto.numero)
            }
        }
        .padding(32)
    }

    private var pellizco: some Gesture {
        MagnifyGesture()
            .onChanged { valor in
                let inicial = escalaAlEmpezar ?? escala
                escalaAlEmpezar = inicial
                escala = limitar(inicial * valor.magnification)
            }
            .onEnded { _ in escalaAlEmpezar = nil }
    }

    private var controlZoom: some View {
        HStack(spacing: 16) {
            Button { cambiar(-0.25) } label: { Image(systemName: "minus.magnifyingglass") }
                .accessibilityLabel("Reducir")
            Button { withAnimation(.easeInOut(duration: 0.2)) { escala = 1 } } label: {
                Text("\(Int((escala * 100).rounded())) %").monospacedDigit().frame(minWidth: 52)
            }
            .accessibilityLabel("Tamaño normal")
            Button { cambiar(0.25) } label: { Image(systemName: "plus.magnifyingglass") }
                .accessibilityLabel("Ampliar")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .padding(16)
    }

    private func cambiar(_ paso: CGFloat) {
        withAnimation(.easeInOut(duration: 0.2)) { escala = limitar(escala + paso) }
    }

    private func limitar(_ valor: CGFloat) -> CGFloat {
        min(max(valor, LimpioView.escalaMinima), LimpioView.escalaMaxima)
    }
}

/// Un asiento en limpio. En la pantalla se corrige (fecha, apuntes, arrastre); en el PDF se
/// dibuja igual pero quieto: la fecha como texto y sin asas ni botones.
struct AsientoLimpio: View {
    struct Interactivo {
        let acciones: AccionesApunte
        let cambiarFecha: (Fecha) -> Void
        let recuperar: () -> Void
    }

    let resuelto: AsientoResuelto
    let uso: LimpioView.Uso
    /// nil en el PDF.
    var interactivo: Interactivo?

    var body: some View {
        let filas = resuelto.filasEditables
        let debe = filas.filter { $0.lado == .debe }
        let haber = filas.filter { $0.lado == .haber }
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Text("Debe").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                raya
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Nº \(resuelto.numero)").font(.callout.weight(.semibold))
                        fecha
                    }
                    if !resuelto.concepto.isEmpty {
                        Text(resuelto.concepto).font(.caption).foregroundStyle(.secondary)
                    }
                }
                raya
                Text("Haber").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
            }

            ForEach(0..<max(debe.count, haber.count), id: \.self) { fila in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    lado(fila < debe.count ? debe[fila] : nil)
                    Text(fila == 0 ? "a" : "")
                        .font(.system(.body, design: .serif).italic())
                        .frame(width: 32)
                    lado(fila < haber.count ? haber[fila] : nil)
                }
            }

            if let interactivo {
                DescartadasView(cuantas: resuelto.descartadas, recuperar: interactivo.recuperar)
            }
            pie
        }
        .font(.system(.body, design: .serif).monospacedDigit())
        .padding(8)
    }

    private var raya: some View {
        Rectangle().fill(Color.secondary.opacity(0.5)).frame(height: 1)
    }

    /// En la pantalla, el selector de fecha; en el PDF, la fecha con el mismo aspecto.
    @ViewBuilder
    private var fecha: some View {
        if let interactivo {
            DatePicker("Fecha", selection: Binding(get: { resuelto.fecha.date },
                                                   set: { interactivo.cambiarFecha(Fecha($0)) }),
                       displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        } else {
            Text(resuelto.fecha.date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted,
                                                                 locale: Locale(identifier: "es_ES"))))
                .font(.body)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    /// Debe: importe · nombre · (nº). Haber: (nº) · nombre · importe. Como en el cuaderno.
    @ViewBuilder
    private func lado(_ fila: FilaEditable?) -> some View {
        if let fila {
            if let interactivo {
                ApunteFila(fila: fila, estilo: .limpio, acciones: interactivo.acciones)
                    .frame(maxWidth: .infinity)
            } else {
                // Igual que en la pantalla, con el sitio del asa vacío.
                HStack(alignment: .center, spacing: 6) {
                    Color.clear.frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        FilaLimpia(fila: fila)
                        if let texto = fila.sinEntender {
                            Text("No lo entiendo: «\(texto)»").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            Spacer().frame(maxWidth: .infinity)
        }
    }

    /// Debajo del asiento: en el diario, si no cuadra; en la solución, todo lo que hay que
    /// revisar. Mientras se practica, nada.
    @ViewBuilder
    private var pie: some View {
        switch uso {
        case .diario:
            if resuelto.asiento == nil, !resuelto.leido.apuntes.isEmpty, case .failure(let error) = resuelto.resultado {
                Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        case .practica:
            EmptyView()
        case .solucion:
            RevisionAsiento(revision: resuelto.revision)
        }
    }
}
