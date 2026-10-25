import UIKit
import PencilKit
import Vision

/// Lo que el reconocedor saca de un trozo de lienzo: apuntes para revisar y las líneas que no
/// ha sabido interpretar (se enseñan tal cual, para corregirlas a mano).
struct Reconocimiento {
    var fecha: Fecha?
    var apuntes: [Apunte] = []
    var noEntendido: [String] = []
}

/// Escritura a mano → apuntes, con Vision en el propio iPad (sin conexión).
/// Cada palabra se coloca en su columna según dónde se escribió; cada fila es un apunte:
/// un código de cuenta en el centro y un importe a la izquierda (Debe) o a la derecha (Haber).
enum Reconocedor {
    private struct Palabra {
        var texto: String
        var x: CGFloat
        var y: CGFloat
        var alto: CGFloat
    }

    @MainActor
    static func reconocer(_ dibujo: PKDrawing, anchoLienzo: CGFloat) async -> Reconocimiento {
        guard !dibujo.strokes.isEmpty, anchoLienzo > 0 else { return Reconocimiento() }
        let marco = dibujo.bounds.insetBy(dx: -24, dy: -24)
        guard let imagen = imagenParaLeer(dibujo, marco: marco) else { return Reconocimiento() }
        let leidas = await leer(imagen)
        // Vision da cajas normalizadas (0–1) con el origen abajo a la izquierda; se pasan al lienzo.
        let palabras = leidas.map { texto, caja in
            Palabra(texto: texto,
                    x: marco.minX + caja.midX * marco.width,
                    y: marco.minY + (1 - caja.midY) * marco.height,
                    alto: caja.height * marco.height)
        }
        return interpretar(palabras, anchoLienzo: anchoLienzo)
    }

    @MainActor
    private static func imagenParaLeer(_ dibujo: PKDrawing, marco: CGRect) -> CGImage? {
        var tinta = UIImage()
        // En modo oscuro PencilKit pinta la tinta negra en blanco; Vision lee mejor negro sobre blanco.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            tinta = dibujo.image(from: marco, scale: 2)
        }
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 2
        let imagen = UIGraphicsImageRenderer(size: marco.size, format: formato).image { contexto in
            UIColor.white.setFill()
            contexto.fill(CGRect(origin: .zero, size: marco.size))
            tinta.draw(in: CGRect(origin: .zero, size: marco.size))
        }
        return imagen.cgImage
    }

    private static func leer(_ imagen: CGImage) async -> [(String, CGRect)] {
        await withCheckedContinuation { continuacion in
            DispatchQueue.global(qos: .userInitiated).async {
                let peticion = VNRecognizeTextRequest()
                peticion.recognitionLevel = .accurate
                peticion.usesLanguageCorrection = false  // códigos e importes no son palabras
                peticion.recognitionLanguages = ["es-ES"]
                let handler = VNImageRequestHandler(cgImage: imagen, options: [:])
                try? handler.perform([peticion])

                var resultado: [(String, CGRect)] = []
                for observacion in peticion.results ?? [] {
                    guard let candidato = observacion.topCandidates(1).first else { continue }
                    let texto = candidato.string
                    // Palabra a palabra con su propia caja: una línea que cruza columnas se reparte bien.
                    for trozo in texto.split(separator: " ") {
                        let caja = (try? candidato.boundingBox(for: trozo.startIndex..<trozo.endIndex))?.boundingBox
                        resultado.append((String(trozo), caja ?? observacion.boundingBox))
                    }
                }
                continuacion.resume(returning: resultado)
            }
        }
    }

    private static func interpretar(_ palabras: [Palabra], anchoLienzo: CGFloat) -> Reconocimiento {
        var resultado = Reconocimiento()
        for fila in agruparEnFilas(palabras) {
            var debe: [String] = []
            var cuenta: [String] = []
            var haber: [String] = []
            for palabra in fila.sorted(by: { $0.x < $1.x }) {
                if let fecha = Fecha(texto: numerico(palabra.texto)), palabra.texto.contains("/") {
                    if resultado.fecha == nil { resultado.fecha = fecha }
                    continue
                }
                let posicion = palabra.x / anchoLienzo
                if posicion < Columnas.finDebe {
                    debe.append(palabra.texto)
                } else if posicion > Columnas.inicioHaber {
                    haber.append(palabra.texto)
                } else {
                    cuenta.append(palabra.texto)
                }
            }
            let textoFila = (debe + cuenta + haber).joined(separator: " ")
            guard !textoFila.isEmpty else { continue }

            let codigo = cuenta.lazy.compactMap(codigoDeCuenta).first
            let importeDebe = Importe.leer(numerico(debe.joined()))
            let importeHaber = Importe.leer(numerico(haber.joined()))
            switch (codigo, importeDebe, importeHaber) {
            case let (codigo?, importe?, .none):
                resultado.apuntes.append(Apunte(.debe, codigo, importe))
            case let (codigo?, .none, importe?):
                resultado.apuntes.append(Apunte(.haber, codigo, importe))
            default:
                resultado.noEntendido.append(textoFila)
            }
        }
        return resultado
    }

    /// Agrupa en filas las palabras cuya altura se solapa.
    private static func agruparEnFilas(_ palabras: [Palabra]) -> [[Palabra]] {
        var filas: [[Palabra]] = []
        for palabra in palabras.sorted(by: { $0.y < $1.y }) {
            if let ultima = filas.last {
                let centro = ultima.map(\.y).reduce(0, +) / CGFloat(ultima.count)
                let tolerancia = max(ultima.map(\.alto).max() ?? 0, palabra.alto) * 0.6
                if abs(palabra.y - centro) < tolerancia {
                    filas[filas.count - 1].append(palabra)
                    continue
                }
            }
            filas.append([palabra])
        }
        return filas
    }

    /// «(572)», «572», «4751.1» → código; la «a» del Haber y el nombre de la cuenta se ignoran.
    private static func codigoDeCuenta(_ texto: String) -> String? {
        let limpio = numerico(texto)
        guard let rango = limpio.range(of: #"\d{3,}(\.\d+)?"#, options: .regularExpression) else { return nil }
        let codigo = String(limpio[rango])
        return Cuenta(codigo) != nil ? codigo : nil
    }

    /// Confusiones típicas de la letra a mano en números: O → 0, l/I/| → 1.
    private static func numerico(_ texto: String) -> String {
        guard texto.contains(where: \.isNumber) else { return texto }
        return String(texto.map { letra -> Character in
            switch letra {
            case "O", "o": return "0"
            case "l", "I", "|": return "1"
            default: return letra
            }
        })
    }
}
