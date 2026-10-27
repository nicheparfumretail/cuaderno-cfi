import SwiftUI
import PencilKit

/// El enunciado de una práctica: páginas de imagen sobre una página de 1000 puntos de ancho (como
/// el lienzo) y las notas escritas encima con el Pencil. Cada página guarda su sitio y su tamaño:
/// se mueve, se agranda o se quita, y lo escrito encima de ella va con ella.
extension EditorHoja {
    /// Ancho con el que entra cada página; lo que sobra hasta los 1000 puntos queda a los lados.
    static let anchoEnunciado: CGFloat = 800
    /// Hueco entre una página del enunciado y la siguiente.
    static let huecoEntrePaginas: CGFloat = 24
    /// Lo más pequeña que se puede dejar una página al redimensionarla.
    static let anchoMinimoPagina: CGFloat = 150

    /// Una página puesta en su sitio, en puntos de página.
    struct PaginaColocada {
        let pagina: PaginaEnunciado
        let marco: CGRect
    }

    /// Cada página en su sitio, en orden (la última, delante). Las de hojas de antes, que no
    /// guardaban el sitio, van una debajo de otra.
    var paginasColocadas: [PaginaColocada] {
        let x = (EditorHoja.anchoPagina - EditorHoja.anchoEnunciado) / 2
        var y = EditorHoja.huecoEntrePaginas
        var lista: [PaginaColocada] = []
        for pagina in hoja.enunciado {
            let ancho = EditorHoja.anchoEnunciado
            let marco = pagina.marco ?? CGRect(x: x, y: y, width: ancho, height: ancho * pagina.proporcion)
            lista.append(PaginaColocada(pagina: pagina, marco: marco))
            y = max(y, marco.maxY + EditorHoja.huecoEntrePaginas)
        }
        return lista
    }

    /// Hasta dónde llega el enunciado; por debajo queda sitio para apuntar.
    var altoEnunciado: CGFloat {
        paginasColocadas.map(\.marco.maxY).max() ?? 0
    }

    func marco(de id: UUID) -> CGRect? {
        paginasColocadas.first { $0.pagina.id == id }?.marco
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

    /// Lo escrito sobre una página: los trazos cuyo centro cae dentro de ella.
    static func estaSobre(_ trazo: PKStroke, _ marco: CGRect) -> Bool {
        marco.contains(CGPoint(x: trazo.renderBounds.midX, y: trazo.renderBounds.midY))
    }

    /// Lleva el rectángulo `inicial` al `nuevo` (misma proporción): desplaza y escala.
    static func transformacion(de inicial: CGRect, a nuevo: CGRect) -> CGAffineTransform {
        let escala = nuevo.width / max(inicial.width, 1)
        return CGAffineTransform(translationX: -inicial.minX, y: -inicial.minY)
            .concatenating(CGAffineTransform(scaleX: escala, y: escala))
            .concatenating(CGAffineTransform(translationX: nuevo.minX, y: nuevo.minY))
    }

    /// Añade un adjunto (una captura, un PDF de varias páginas…) debajo de todo lo que hay.
    func añadirAdjunto(_ preparadas: [PaginaPreparada], nombre: String) {
        guard !preparadas.isEmpty else { return }
        let adjunto = UUID()
        let ancho = EditorHoja.anchoEnunciado
        let x = (EditorHoja.anchoPagina - ancho) / 2
        var y = altoEnunciado + EditorHoja.huecoEntrePaginas
        var nuevas: [PaginaEnunciado] = []
        for preparada in preparadas {
            var pagina = PaginaEnunciado(id: UUID(), adjunto: adjunto, nombre: nombre,
                                         ancho: Double(preparada.ancho), alto: Double(preparada.alto))
            let alto = ancho * pagina.proporcion
            pagina.colocar(en: CGRect(x: x, y: y, width: ancho, height: alto))
            archivo.guardarImagen(preparada.jpeg, pagina: pagina.id, hoja: hoja.id)
            nuevas.append(pagina)
            y += alto + EditorHoja.huecoEntrePaginas
        }
        hoja.enunciado += nuevas
        guardar()
    }

    /// Las hojas de antes no guardaban el sitio de cada página: antes de tocar ninguna se fija el
    /// que tenían a la vista, para que las demás no se recoloquen solas.
    private func fijarMarcos() {
        guard hoja.enunciado.contains(where: { $0.marco == nil }) else { return }
        hoja.enunciado = paginasColocadas.map { (colocada: PaginaColocada) -> PaginaEnunciado in
            var pagina = colocada.pagina
            pagina.colocar(en: colocada.marco)
            return pagina
        }
    }

    /// Mueve o redimensiona una página (de `inicial` a `nuevo`). Lo escrito encima va con ella,
    /// agrandado o achicado igual, y la página queda delante de las demás.
    func colocarPagina(_ id: UUID, en nuevo: CGRect, desde inicial: CGRect) {
        fijarMarcos()
        guard var pagina = hoja.enunciado.first(where: { $0.id == id }) else { return }
        let cambio = EditorHoja.transformacion(de: inicial, a: nuevo)
        notas = PKDrawing(strokes: notas.strokes.map { (trazo: PKStroke) -> PKStroke in
            guard EditorHoja.estaSobre(trazo, inicial) else { return trazo }
            var copia = trazo
            copia.transform = trazo.transform.concatenating(cambio)
            return copia
        })
        pagina.colocar(en: nuevo)
        var enunciado = hoja.enunciado
        enunciado.removeAll { $0.id == id }
        enunciado.append(pagina)
        hoja.enunciado = enunciado
        versionNotas += 1
        guardar()
    }

    /// La página vuelve al ancho con el que entró, centrada y a la misma altura.
    func ajustarAlAncho(_ id: UUID) {
        guard let actual = self.marco(de: id) else { return }
        let ancho = EditorHoja.anchoEnunciado
        let alto = ancho * actual.height / max(actual.width, 1)
        let nuevo = CGRect(x: (EditorHoja.anchoPagina - ancho) / 2, y: actual.minY, width: ancho, height: alto)
        colocarPagina(id, en: nuevo, desde: actual)
    }

    /// Quita una página y lo escrito encima de ella.
    func quitarPagina(_ id: UUID) {
        quitar { $0.id == id }
    }

    /// Quita un adjunto entero (todas las páginas de un PDF) y lo escrito encima.
    func quitarAdjunto(_ adjunto: UUID) {
        quitar { $0.adjunto == adjunto }
    }

    /// Lo demás se queda donde está: con las páginas sueltas, cada una se mueve a mano.
    private func quitar(_ cuales: (PaginaEnunciado) -> Bool) {
        let fuera = paginasColocadas.filter { cuales($0.pagina) }
        guard !fuera.isEmpty else { return }
        fijarMarcos()
        notas = PKDrawing(strokes: notas.strokes.filter { trazo in
            !fuera.contains { EditorHoja.estaSobre(trazo, $0.marco) }
        })
        for colocada in fuera {
            archivo.borrarImagen(pagina: colocada.pagina.id, hoja: hoja.id)
            imagenes.removeObject(forKey: colocada.pagina.id as NSUUID)
        }
        hoja.enunciado.removeAll { cuales($0) }
        versionNotas += 1
        guardar()
    }

    func notasCambiadas(_ nuevas: PKDrawing) {
        notas = nuevas
        programarGuardado()
    }

    func calculosCambiados(_ nuevos: PKDrawing) {
        calculos = nuevos
        programarGuardado()
    }
}

extension PaginaEnunciado {
    /// Alto entre ancho de la imagen: la página se agranda o se achica sin deformarse.
    var proporcion: CGFloat {
        CGFloat(alto / max(ancho, 1))
    }

    /// Dónde está en el enunciado, en puntos de página (nil en hojas de antes).
    var marco: CGRect? {
        guard let x = x, let y = y, let anchoMostrado = anchoMostrado else { return nil }
        let ancho = CGFloat(anchoMostrado)
        return CGRect(x: CGFloat(x), y: CGFloat(y), width: ancho, height: ancho * proporcion)
    }

    mutating func colocar(en marco: CGRect) {
        x = Double(marco.minX)
        y = Double(marco.minY)
        anchoMostrado = Double(marco.width)
    }
}
