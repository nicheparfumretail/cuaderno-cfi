import SwiftUI
import PencilKit

/// El enunciado de una práctica: páginas de imagen una debajo de otra, centradas en la página
/// (1000 puntos de ancho, como el lienzo) con un margen a cada lado para apuntar, y las notas
/// escritas encima con el Pencil.
extension EditorHoja {
    /// Ancho de cada página del enunciado; lo que sobra hasta los 1000 puntos queda a los lados.
    static let anchoEnunciado: CGFloat = 800
    /// Hueco entre una página del enunciado y la siguiente.
    static let huecoEntrePaginas: CGFloat = 24

    /// Una página puesta en su sitio, en puntos de página.
    struct PaginaColocada {
        let pagina: PaginaEnunciado
        let marco: CGRect
    }

    var paginasColocadas: [PaginaColocada] {
        let x = (EditorHoja.anchoPagina - EditorHoja.anchoEnunciado) / 2
        var y = EditorHoja.huecoEntrePaginas
        var lista: [PaginaColocada] = []
        for pagina in hoja.enunciado {
            let alto = EditorHoja.anchoEnunciado * CGFloat(pagina.alto / max(pagina.ancho, 1))
            lista.append(PaginaColocada(pagina: pagina, marco: CGRect(x: x, y: y, width: EditorHoja.anchoEnunciado, height: alto)))
            y += alto + EditorHoja.huecoEntrePaginas
        }
        return lista
    }

    /// Hasta dónde llega el enunciado; por debajo queda sitio para apuntar.
    var altoEnunciado: CGFloat {
        paginasColocadas.last?.marco.maxY ?? 0
    }

    /// Los adjuntos, en orden, con su nombre y cuántas páginas tienen.
    var adjuntos: [(id: UUID, nombre: String, paginas: Int)] {
        var lista: [(id: UUID, nombre: String, paginas: Int)] = []
        for pagina in hoja.enunciado {
            if let i = lista.firstIndex(where: { $0.id == pagina.adjunto }) {
                lista[i].paginas += 1
            } else {
                lista.append((id: pagina.adjunto, nombre: pagina.nombre, paginas: 1))
            }
        }
        return lista
    }

    func imagen(de pagina: PaginaEnunciado) -> UIImage? {
        if let guardada = imagenes.object(forKey: pagina.id as NSUUID) { return guardada }
        guard let leida = archivo.imagen(pagina: pagina.id, hoja: hoja.id) else { return nil }
        imagenes.setObject(leida, forKey: pagina.id as NSUUID)
        return leida
    }

    /// Añade un adjunto (una captura, un PDF de varias páginas…) al final del enunciado.
    func añadirAdjunto(_ preparadas: [PaginaPreparada], nombre: String) {
        guard !preparadas.isEmpty else { return }
        let adjunto = UUID()
        var nuevas: [PaginaEnunciado] = []
        for preparada in preparadas {
            let pagina = PaginaEnunciado(id: UUID(), adjunto: adjunto, nombre: nombre,
                                         ancho: Double(preparada.ancho), alto: Double(preparada.alto))
            archivo.guardarImagen(preparada.jpeg, pagina: pagina.id, hoja: hoja.id)
            nuevas.append(pagina)
        }
        hoja.enunciado += nuevas
        guardar()
    }

    /// Quita un adjunto y sus páginas. Lo escrito encima se va con ellas y lo de debajo sube,
    /// para que cada nota siga junto a lo que comentaba.
    func quitarAdjunto(_ adjunto: UUID) {
        let colocadas = paginasColocadas.filter { $0.pagina.adjunto == adjunto }
        guard let primera = colocadas.first, let ultima = colocadas.last else { return }
        let desde = primera.marco.minY
        let hasta = ultima.marco.maxY + EditorHoja.huecoEntrePaginas
        var trazos: [PKStroke] = []
        for trazo in notas.strokes {
            let medio = trazo.renderBounds.midY
            if medio >= desde && medio < hasta { continue }
            var copia = trazo
            if medio >= hasta {
                copia.transform = trazo.transform.concatenating(CGAffineTransform(translationX: 0, y: desde - hasta))
            }
            trazos.append(copia)
        }
        notas = PKDrawing(strokes: trazos)
        for colocada in colocadas {
            archivo.borrarImagen(pagina: colocada.pagina.id, hoja: hoja.id)
            imagenes.removeObject(forKey: colocada.pagina.id as NSUUID)
        }
        hoja.enunciado.removeAll { $0.adjunto == adjunto }
        versionNotas += 1
        guardar()
    }

    func notasCambiadas(_ nuevas: PKDrawing) {
        notas = nuevas
        programarGuardado()
    }
}
