import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import WebKit

/// Una página del enunciado lista para guardar: un JPEG de 2000 píxeles de ancho como mucho.
struct PaginaPreparada: Sendable {
    let jpeg: Data
    let ancho: Int
    let alto: Int
}

/// Convierte lo que se adjunta a una práctica en páginas: una captura es una página, un PDF da
/// una por página y un Word se pasa antes a PDF (como lo enseña Safari).
///
/// El trabajo pesado (dibujar cada página y comprimirla) se hace en segundo plano y página a
/// página, para que un PDF largo no llene la memoria ni congele la pantalla.
enum ImportadorEnunciado {
    static let anchoMaximo = 2000

    static var tipos: [UTType] {
        let word = ["org.openxmlformats.wordprocessingml.document", "com.microsoft.word.doc"].compactMap { UTType($0) }
        return [UTType.pdf, UTType.image] + word
    }

    enum Fallo: LocalizedError {
        case noSeAbre(String)

        var errorDescription: String? {
            switch self {
            case .noSeAbre(let nombre):
                return "No he podido abrir «\(nombre)». Si es un Word, guárdalo como PDF y añádelo así."
            }
        }
    }

    /// Las páginas de un archivo elegido en Archivos: PDF, imagen o Word.
    @MainActor
    static func paginas(de url: URL) async throws -> [PaginaPreparada] {
        let acceso = url.startAccessingSecurityScopedResource()
        defer { if acceso { url.stopAccessingSecurityScopedResource() } }
        let nombre = url.lastPathComponent
        guard let datos = try? Data(contentsOf: url) else { throw Fallo.noSeAbre(nombre) }
        let tipo = UTType(filenameExtension: url.pathExtension.lowercased()) ?? .data

        let paginas: [PaginaPreparada]
        if tipo.conforms(to: .pdf) || tipo.conforms(to: .image) {
            paginas = await self.paginas(deDatos: datos, tipo: tipo)
        } else {
            let pdf = await ConversorWord().pdf(de: datos, sufijo: url.pathExtension)
            paginas = await enSegundoPlano { pdf.map(paginasPDF) ?? [] }
        }
        guard !paginas.isEmpty else { throw Fallo.noSeAbre(nombre) }
        return paginas
    }

    /// Las páginas de una imagen (una foto, una captura pegada) o de un PDF que llega en datos.
    static func paginas(deDatos datos: Data, tipo: UTType) async -> [PaginaPreparada] {
        if tipo.conforms(to: .pdf) {
            return await enSegundoPlano { paginasPDF(datos) }
        }
        return await enSegundoPlano { paginaImagen(datos).map { [$0] } ?? [] }
    }

    private static func enSegundoPlano(_ trabajo: @escaping @Sendable () -> [PaginaPreparada]) async -> [PaginaPreparada] {
        await Task.detached(priority: .userInitiated) { trabajo() }.value
    }

    // MARK: - PDF

    /// Cada página del PDF a 2000 píxeles de ancho. Una página muy larga (un Word pasado a PDF
    /// sale de una pieza) se corta en trozos del tamaño de un folio.
    static func paginasPDF(_ datos: Data) -> [PaginaPreparada] {
        guard let proveedor = CGDataProvider(data: datos as CFData),
              let documento = CGPDFDocument(proveedor), documento.numberOfPages > 0 else { return [] }
        var lista: [PaginaPreparada] = []
        for numero in 1...documento.numberOfPages {
            guard let pagina = documento.page(at: numero) else { continue }
            lista += trozos(de: pagina)
        }
        return lista
    }

    private static func trozos(de pagina: CGPDFPage) -> [PaginaPreparada] {
        let caja = pagina.getBoxRect(.cropBox)
        guard caja.width > 0, caja.height > 0 else { return [] }
        // El giro con el que se enseña la página (los escaneos suelen venir girados).
        let giro = ((Int(pagina.rotationAngle) % 360) + 360) % 360
        let tumbada = giro == 90 || giro == 270
        let anchoVisto = tumbada ? caja.height : caja.width
        let altoVisto = tumbada ? caja.width : caja.height
        let ancho = CGFloat(anchoMaximo)
        let escala = ancho / anchoVisto
        let altoTotal = (altoVisto * escala).rounded()
        let altoFolio = (ancho * 1.414).rounded()

        var lista: [PaginaPreparada] = []
        var desde: CGFloat = 0
        while desde < altoTotal - 1 {
            let alto = min(altoFolio, altoTotal - desde)
            let trozo: PaginaPreparada? = autoreleasepool {
                guard let contexto = contextoBlanco(ancho: Int(ancho), alto: Int(alto)) else { return nil }
                // CoreGraphics cuenta desde abajo: se baja la página para que se vea el trozo
                // que empieza `desde` puntos por debajo de su borde de arriba.
                contexto.translateBy(x: 0, y: -(altoTotal - desde - alto))
                contexto.scaleBy(x: escala, y: escala)
                switch giro {
                case 90:
                    contexto.translateBy(x: 0, y: caja.width)
                    contexto.rotate(by: -.pi / 2)
                case 180:
                    contexto.translateBy(x: caja.width, y: caja.height)
                    contexto.rotate(by: .pi)
                case 270:
                    contexto.translateBy(x: caja.height, y: 0)
                    contexto.rotate(by: .pi / 2)
                default:
                    break
                }
                contexto.translateBy(x: -caja.minX, y: -caja.minY)
                contexto.clip(to: caja)
                contexto.drawPDFPage(pagina)
                return contexto.makeImage().flatMap(jpeg)
            }
            if let trozo { lista.append(trozo) }
            desde += alto
        }
        return lista
    }

    // MARK: - Imágenes

    /// La imagen derecha (las fotos traen el giro aparte), sobre blanco y como mucho de 2000
    /// píxeles de ancho.
    static func paginaImagen(_ datos: Data) -> PaginaPreparada? {
        autoreleasepool {
            guard let fuente = CGImageSourceCreateWithData(datos as CFData, nil),
                  let propiedades = CGImageSourceCopyPropertiesAtIndex(fuente, 0, nil) as? [CFString: Any],
                  let anchoPixeles = propiedades[kCGImagePropertyPixelWidth] as? Int,
                  let altoPixeles = propiedades[kCGImagePropertyPixelHeight] as? Int,
                  anchoPixeles > 0, altoPixeles > 0 else { return nil }
            // Orientaciones 5 a 8: la foto está tumbada y el ancho que se ve es el alto guardado.
            let orientacion = propiedades[kCGImagePropertyOrientation] as? Int ?? 1
            let anchoVisto = orientacion >= 5 ? altoPixeles : anchoPixeles
            let factor = min(1, Double(anchoMaximo) / Double(anchoVisto))
            let lado = Int((Double(max(anchoPixeles, altoPixeles)) * factor).rounded())
            let opciones: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: lado,
            ]
            guard let imagen = CGImageSourceCreateThumbnailAtIndex(fuente, 0, opciones as CFDictionary),
                  let contexto = contextoBlanco(ancho: imagen.width, alto: imagen.height) else { return nil }
            // Sobre blanco: una captura con transparencia no se queda negra en el JPEG.
            contexto.draw(imagen, in: CGRect(x: 0, y: 0, width: imagen.width, height: imagen.height))
            return contexto.makeImage().flatMap(jpeg)
        }
    }

    // MARK: - Utilidades

    private static func contextoBlanco(ancho: Int, alto: Int) -> CGContext? {
        guard ancho > 0, alto > 0, let color = CGColorSpace(name: CGColorSpace.sRGB),
              let contexto = CGContext(data: nil, width: ancho, height: alto, bitsPerComponent: 8, bytesPerRow: 0,
                                       space: color, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        contexto.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        contexto.fill(CGRect(x: 0, y: 0, width: ancho, height: alto))
        contexto.interpolationQuality = .high
        return contexto
    }

    private static func jpeg(_ imagen: CGImage) -> PaginaPreparada? {
        let datos = NSMutableData()
        guard let destino = CGImageDestinationCreateWithData(datos as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destino, imagen, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destino) else { return nil }
        return PaginaPreparada(jpeg: datos as Data, ancho: imagen.width, alto: imagen.height)
    }
}

/// Pasa un Word a PDF con WebKit: lo abre como haría Safari y lo imprime a PDF (de una pieza).
@MainActor
private final class ConversorWord: NSObject, WKNavigationDelegate {
    private var web: WKWebView?
    private var continuacion: CheckedContinuation<Data?, Never>?

    func pdf(de datos: Data, sufijo: String) async -> Data? {
        // WebKit lee el Word desde un archivo de la app.
        let copia = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sufijo)
        guard (try? datos.write(to: copia)) != nil else { return nil }
        defer { try? FileManager.default.removeItem(at: copia) }
        return await withCheckedContinuation { continuacion in
            self.continuacion = continuacion
            let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 820, height: 1160))
            web.navigationDelegate = self
            self.web = web
            web.loadFileURL(copia, allowingReadAccessTo: copia.deletingLastPathComponent())
            // Si no termina en un rato, se da por imposible.
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in self?.terminar(nil) }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Un momento para que acabe de maquetar.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            webView.createPDF { resultado in
                let datos = try? resultado.get()
                DispatchQueue.main.async { self?.terminar(datos) }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        terminar(nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        terminar(nil)
    }

    private func terminar(_ datos: Data?) {
        continuacion?.resume(returning: datos)
        continuacion = nil
        web = nil
    }
}
