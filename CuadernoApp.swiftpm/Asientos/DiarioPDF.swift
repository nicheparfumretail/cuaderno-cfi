import SwiftUI
import UIKit

/// La hoja en limpio en PDF, con el mismo aspecto que En limpio en la pantalla del iPad (también
/// con el fondo negro del modo oscuro): se dibujan las mismas vistas, quietas. Cada asiento va
/// entero en una página; si no cabe en la que va, empieza en la siguiente. Las páginas tienen la
/// proporción de un A4, así que también se imprime bien.
struct DiarioPDF {
    let resueltos: [AsientoResuelto]
    let creada: Date
    let practica: Bool
    let solucion: Bool
    /// Fondo negro y letra clara, como el iPad en modo oscuro.
    let oscuro: Bool

    /// El ancho de En limpio en la pantalla (como mucho 1000 puntos, con 32 de margen).
    private static let ancho: CGFloat = 1000
    private static let alto: CGFloat = 1414
    private static let margen: CGFloat = 32

    var nombreArchivo: String {
        let dia = Fecha(creada).description.replacingOccurrences(of: "/", with: "-")
        return solucion ? "Solución \(dia).pdf" : (practica ? "Práctica \(dia).pdf" : "Diario \(dia).pdf")
    }

    private var uso: LimpioView.Uso {
        solucion ? .solucion : (practica ? .practica : .diario)
    }

    /// Escribe el PDF en un archivo temporal y dice dónde (nil si no se ha podido). Un archivo, y
    /// no solo los datos, para que al compartir salgan las apps que abren PDF (Freenotes, Notas…).
    @MainActor
    func archivo() async -> URL? {
        let datos = await self.datos()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(nombreArchivo)
        do {
            try datos.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @MainActor
    func datos() async -> Data {
        let pagina = CGRect(x: 0, y: 0, width: DiarioPDF.ancho, height: DiarioPDF.alto)
        let margen = DiarioPDF.margen
        let anchoContenido = pagina.width - margen * 2
        let esquema: ColorScheme = oscuro ? .dark : .light
        let fondo = UIColor.systemBackground
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: oscuro ? .dark : .light)).cgColor
        let datos = NSMutableData()
        var caja = pagina
        guard let consumidor = CGDataConsumer(data: datos as CFMutableData),
              let pdf = CGContext(consumer: consumidor, mediaBox: &caja, nil) else { return Data() }

        var y = margen
        var abierta = false
        func nuevaPagina() {
            if abierta { pdf.endPDFPage() }
            pdf.beginPDFPage(nil)
            pdf.setFillColor(fondo)
            pdf.fill(pagina)
            abierta = true
            y = margen
        }
        func colocar<V: View>(_ vista: V, separacion: CGFloat) {
            let renderer = ImageRenderer(content: vista
                .frame(width: anchoContenido)
                .environment(\.colorScheme, esquema)
                .environment(\.locale, Locale(identifier: "es_ES")))
            renderer.proposedSize = ProposedViewSize(width: anchoContenido, height: nil)
            renderer.render { tamaño, dibujar in
                if !abierta || (y + tamaño.height > pagina.height - margen && y > margen) {
                    nuevaPagina()
                }
                // El PDF cuenta desde abajo: el bloque va `y` puntos por debajo del borde de arriba.
                pdf.saveGState()
                pdf.translateBy(x: margen, y: pagina.height - y - tamaño.height)
                dibujar(pdf)
                pdf.restoreGState()
                y += tamaño.height + separacion
            }
        }

        colocar(cabecera, separacion: 24)
        for (indice, resuelto) in resueltos.enumerated() {
            colocar(AsientoLimpio(resuelto: resuelto, uso: uso), separacion: 32)
            // Un respiro de vez en cuando, para que la pantalla siga viva mientras se prepara.
            if indice % 4 == 3 { await Task.yield() }
        }
        if !abierta { nuevaPagina() }
        pdf.endPDFPage()
        pdf.closePDF()
        return datos as Data
    }

    /// Arriba: en la solución, el resumen de la corrección (como en la pantalla); si no, de qué
    /// hoja es.
    @ViewBuilder
    private var cabecera: some View {
        if solucion {
            ResumenSolucion(resueltos: resueltos)
        } else {
            Text("Cuaderno CFI · \(practica ? "práctica" : "hoja") del \(Fecha(creada).description) · \(resueltos.count) asiento\(resueltos.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// La hoja de compartir del sistema con un archivo: salen Guardar en Archivos y las apps que
/// abren ese tipo de archivo.
@MainActor
enum Compartir {
    static func presentar(_ url: URL) {
        let escenas = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let ventanas = escenas.flatMap(\.windows)
        guard let ventana = ventanas.first(where: \.isKeyWindow) ?? ventanas.first,
              var arriba = ventana.rootViewController else { return }
        while let encima = arriba.presentedViewController { arriba = encima }
        let hoja = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // En el iPad sale como globo junto al botón de compartir (arriba a la derecha).
        if let globo = hoja.popoverPresentationController {
            globo.sourceView = arriba.view
            globo.sourceRect = CGRect(x: arriba.view.bounds.width - 110, y: arriba.view.safeAreaInsets.top, width: 1, height: 1)
            globo.permittedArrowDirections = [.up]
        }
        arriba.present(hoja, animated: true)
    }
}
