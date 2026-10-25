import UIKit
import PencilKit
import Vision

/// Lo que sale de la tinta antes de interpretarla: palabras con posición y rayas.
struct LecturaTinta {
    var palabras: [PalabraLeida] = []
    var separadores: [Double] = []
}

/// Tinta → renglones → texto (Vision, en el propio iPad y sin conexión). Qué significa cada
/// cosa lo decide `LectorAsientos` en el motor.
///
/// Los trazos se agrupan primero en renglones por su geometría (`AgrupadorTrazos`) y cada
/// renglón se recorta y se lee por separado, dos veces (tinta normal y engordada) y con varias
/// lecturas candidatas: el motor elige la que hace cuadrar el asiento. Lo leído se guarda por
/// renglón, así que retocar una cifra solo vuelve a leer ese renglón y el resto no se mueve.
enum Reconocedor {
    /// Lecturas por huella de los trazos de cada renglón.
    @MainActor private static var memoria: [Int: [String]] = [:]

    @MainActor
    static func leer(_ dibujo: PKDrawing, anchoPagina: CGFloat, zonas: Zonas) async -> LecturaTinta {
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
        let cajas = texto.map {
            CajaTrazo(minX: Double($0.renderBounds.minX), minY: Double($0.renderBounds.minY),
                      maxX: Double($0.renderBounds.maxX), maxY: Double($0.renderBounds.maxY))
        }
        let renglones = AgrupadorTrazos.renglones(cajas, anchoPagina: Double(anchoPagina), zonas: zonas)
        let huellas = renglones.map { huella($0.indices.map { texto[$0] }) }

        // Solo se leen los renglones nuevos o retocados; las imágenes se pintan aquí y Vision
        // trabaja fuera del hilo principal, todos los renglones a la vez.
        var pendientes: [(Int, [CGImage])] = []
        for (renglon, huella) in zip(renglones, huellas) where memoria[huella] == nil {
            if !pendientes.contains(where: { $0.0 == huella }) {
                pendientes.append((huella, imagenes(renglon.indices.map { texto[$0] })))
            }
        }
        let nuevas = await withTaskGroup(of: (Int, [String]).self) { grupo -> [Int: [String]] in
            for (huella, imagenes) in pendientes {
                grupo.addTask { (huella, await lecturas(de: imagenes)) }
            }
            var resultado: [Int: [String]] = [:]
            for await (huella, lecturas) in grupo { resultado[huella] = lecturas }
            return resultado
        }
        if memoria.count > 500 { memoria = [:] }
        memoria.merge(nuevas) { _, nueva in nueva }

        for (numero, (renglon, huella)) in zip(renglones, huellas).enumerated() {
            guard let lecturas = memoria[huella], let primera = lecturas.first else { continue }
            lectura.palabras.append(PalabraLeida(primera, x: renglon.x, y: renglon.y, alto: renglon.caja.alto,
                                                 alternativas: Array(lecturas.dropFirst()), renglon: numero))
        }
        return lectura
    }

    /// Identifica un renglón por sus trazos: si no se toca, la huella no cambia.
    private static func huella(_ trazos: [PKStroke]) -> Int {
        var hasher = Hasher()
        for trazo in trazos {
            let caja = trazo.renderBounds
            hasher.combine(trazo.path.creationDate.timeIntervalSinceReferenceDate)
            hasher.combine(trazo.path.count)
            for valor in [caja.minX, caja.minY, caja.width, caja.height] { hasher.combine(Int(valor * 2)) }
        }
        return hasher.finalize()
    }

    /// El renglón en negro sobre blanco, dos veces: con su grosor y engordado. Un lápiz fino o una
    /// cifra apretada se leen mejor gruesos; una cifra cerrada (un 9, un 6), mejor fina.
    @MainActor
    private static func imagenes(_ trazos: [PKStroke]) -> [CGImage] {
        [1.0, 1.8].compactMap { grosor in
            let negros = trazos.map { trazo -> PKStroke in
                let puntos = trazo.path.map { punto in
                    PKStrokePoint(location: punto.location, timeOffset: punto.timeOffset,
                                  size: CGSize(width: punto.size.width * grosor, height: punto.size.height * grosor),
                                  opacity: 1, force: punto.force, azimuth: punto.azimuth, altitude: punto.altitude)
                }
                return PKStroke(ink: PKInk(.pen, color: .black),
                                path: PKStrokePath(controlPoints: puntos, creationDate: trazo.path.creationDate),
                                transform: trazo.transform, mask: trazo.mask)
            }
            let dibujo = PKDrawing(strokes: negros)
            let margen = max(16, dibujo.bounds.height * 0.4)
            return imagen(dibujo, marco: dibujo.bounds.insetBy(dx: -margen, dy: -margen))
        }
    }

    @MainActor
    private static func imagen(_ dibujo: PKDrawing, marco: CGRect) -> CGImage? {
        let escala: CGFloat = 2
        var tinta = UIImage()
        // En modo oscuro PencilKit pinta la tinta en blanco; Vision lee mejor negro sobre blanco.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            tinta = dibujo.image(from: marco, scale: escala)
        }
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = escala
        let imagen = UIGraphicsImageRenderer(size: marco.size, format: formato).image { contexto in
            UIColor.white.setFill()
            contexto.fill(CGRect(origin: .zero, size: marco.size))
            tinta.draw(in: CGRect(origin: .zero, size: marco.size))
        }
        return imagen.cgImage
    }

    /// Todas las lecturas de un renglón, de más a menos probable y sin repetir: primero la mejor
    /// de cada imagen y después las alternativas.
    private static func lecturas(de imagenes: [CGImage]) async -> [String] {
        var primeras: [String] = []
        var resto: [String] = []
        for imagen in imagenes {
            let leidas = await leer(imagen)
            if let primera = leidas.first {
                primeras.append(primera)
                resto += leidas.dropFirst()
            }
        }
        var lista: [String] = []
        for lectura in primeras + resto where !lista.contains(lectura) {
            lista.append(lectura)
        }
        return Array(lista.prefix(10))
    }

    /// Las lecturas de una imagen: la mejor y, después, cambiando un trozo cada vez por la
    /// siguiente candidata de Vision («814,00» → «819,00»).
    private static func leer(_ imagen: CGImage) async -> [String] {
        await withCheckedContinuation { continuacion in
            DispatchQueue.global(qos: .userInitiated).async {
                let peticion = VNRecognizeTextRequest()
                peticion.recognitionLevel = .accurate
                peticion.usesLanguageCorrection = false  // códigos e importes no son palabras
                peticion.recognitionLanguages = ["es-ES"]
                let handler = VNImageRequestHandler(cgImage: imagen, options: [:])
                try? handler.perform([peticion])

                let trozos = (peticion.results ?? [])
                    .sorted { $0.boundingBox.minX < $1.boundingBox.minX }
                    .map { $0.topCandidates(5).map(\.string) }
                    .filter { !$0.isEmpty }
                guard !trozos.isEmpty else { return continuacion.resume(returning: []) }
                let mejores = trozos.map { $0[0] }
                var lecturas = [mejores.joined(separator: " ")]
                for (i, candidatas) in trozos.enumerated() {
                    for candidata in candidatas.dropFirst() {
                        var cambiadas = mejores
                        cambiadas[i] = candidata
                        lecturas.append(cambiadas.joined(separator: " "))
                    }
                }
                continuacion.resume(returning: lecturas)
            }
        }
    }
}
