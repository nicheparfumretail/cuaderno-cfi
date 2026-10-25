import UIKit
import PencilKit
import Vision

/// Lo que sale de la tinta antes de interpretarla: palabras con posición y rayas.
struct LecturaTinta {
    var palabras: [PalabraLeida] = []
    var separadores: [Double] = []
}

/// Tinta → palabras con su posición (Vision, en el propio iPad y sin conexión) y rayas que
/// separan asientos. Qué significa cada cosa lo decide `LectorAsientos` en el motor.
enum Reconocedor {
    @MainActor
    static func leer(_ dibujo: PKDrawing, anchoPagina: CGFloat) async -> LecturaTinta {
        var lectura = LecturaTinta()
        var texto: [PKStroke] = []
        for trazo in dibujo.strokes {
            let caja = trazo.renderBounds
            if LectorAsientos.esSeparador(ancho: Double(caja.width), alto: Double(caja.height),
                                          anchoPagina: Double(anchoPagina)) {
                lectura.separadores.append(Double(caja.midY))
            } else {
                texto.append(trazo)
            }
        }
        // Las rayas no se pasan a Vision: solo estorbarían al leer los números.
        let soloTexto = PKDrawing(strokes: texto)
        guard !soloTexto.strokes.isEmpty else { return lectura }
        let marco = soloTexto.bounds.insetBy(dx: -24, dy: -24)
        guard let imagen = imagenParaLeer(soloTexto, marco: marco) else { return lectura }
        let leidas = await leer(imagen)
        // Vision da cajas normalizadas (0–1) con el origen abajo a la izquierda; se pasan a la página.
        lectura.palabras = leidas.map { palabra, caja in
            PalabraLeida(palabra,
                         x: Double((marco.minX + caja.midX * marco.width) / anchoPagina),
                         y: Double(marco.minY + (1 - caja.midY) * marco.height),
                         alto: Double(caja.height * marco.height))
        }
        return lectura
    }

    @MainActor
    private static func imagenParaLeer(_ dibujo: PKDrawing, marco: CGRect) -> CGImage? {
        var tinta = UIImage()
        // En modo oscuro PencilKit pinta la tinta en blanco; Vision lee mejor negro sobre blanco.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            tinta = dibujo.image(from: marco, scale: 1.5)
        }
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1.5
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
                    // Palabra a palabra con su propia caja: una línea que cruza el centro se reparte bien.
                    for trozo in texto.split(separator: " ") {
                        let caja = (try? candidato.boundingBox(for: trozo.startIndex..<trozo.endIndex))?.boundingBox
                        resultado.append((String(trozo), caja ?? observacion.boundingBox))
                    }
                }
                continuacion.resume(returning: resultado)
            }
        }
    }
}
