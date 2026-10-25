import SwiftUI
import PencilKit

/// Las notas sobre el enunciado de una práctica: un lienzo de PencilKit con las páginas debajo
/// de la tinta. El dedo mueve y amplía (hasta ×4, para leer la letra pequeña); el Pencil escribe
/// encima de las páginas o en los márgenes.
///
/// Las páginas van dentro del propio lienzo, detrás de la tinta: así se mueven con ella sin
/// retraso. Solo se cargan las que están cerca de la pantalla.
struct LienzoNotasView: UIViewRepresentable {
    @ObservedObject var editor: EditorHoja
    let paleta: PKToolPicker

    static let zoomMaximo: CGFloat = 4

    func makeCoordinator() -> Coordinador {
        Coordinador(editor: editor, paleta: paleta)
    }

    func makeUIView(context: Context) -> CanvasPagina {
        let canvas = CanvasPagina()
        let coordinador = context.coordinator
        canvas.alMaquetar = { coordinador.encajar($0) }
        canvas.drawing = editor.notas
        canvas.delegate = coordinador
        // El dedo mueve el enunciado; solo el Pencil escribe.
        canvas.drawingPolicy = .pencilOnly
        // Papel blanco siempre: con el modo oscuro, la tinta negra no se vuelve blanca.
        canvas.overrideUserInterfaceStyle = .light
        canvas.backgroundColor = UIColor(white: 0.9, alpha: 1)
        canvas.alwaysBounceVertical = true
        canvas.contentInsetAdjustmentBehavior = .never
        paleta.setVisible(true, forFirstResponder: canvas)
        paleta.addObserver(canvas)
        coordinador.version = editor.versionNotas
        return canvas
    }

    func updateUIView(_ canvas: CanvasPagina, context: Context) {
        let coordinador = context.coordinator
        // Las notas se cambiaron desde fuera (al quitar un adjunto).
        if coordinador.version != editor.versionNotas {
            coordinador.version = editor.versionNotas
            canvas.drawing = editor.notas
        }
        coordinador.ajustarContenido(canvas)
        coordinador.colocarPaginas(canvas)
    }

    static func dismantleUIView(_ canvas: CanvasPagina, coordinator: Coordinador) {
        coordinator.paleta?.removeObserver(canvas)
    }

    @MainActor
    final class Coordinador: NSObject, PKCanvasViewDelegate {
        let editor: EditorHoja
        weak var paleta: PKToolPicker?
        var version = 0
        private var anchoEncajado: CGFloat = 0
        /// Una vista de imagen por página, dentro del lienzo y detrás de la tinta.
        private var vistas: [UUID: UIImageView] = [:]

        init(editor: EditorHoja, paleta: PKToolPicker) {
            self.editor = editor
            self.paleta = paleta
        }

        /// Cuando cambia el ancho en pantalla (panel más ancho, giro), la página vuelve a encajar.
        func encajar(_ canvas: PKCanvasView) {
            let ancho = canvas.bounds.width
            guard ancho > 0, abs(ancho - anchoEncajado) > 0.5 else { return }
            anchoEncajado = ancho
            let base = ancho / EditorHoja.anchoPagina
            canvas.minimumZoomScale = base
            canvas.maximumZoomScale = base * LienzoNotasView.zoomMaximo
            canvas.zoomScale = base
            ajustarContenido(canvas)
            colocarPaginas(canvas)
        }

        /// Siempre queda espacio libre por debajo del enunciado y de lo escrito.
        func ajustarContenido(_ canvas: PKCanvasView) {
            let zoom = canvas.zoomScale
            let finTinta = canvas.drawing.strokes.isEmpty ? 0 : canvas.drawing.bounds.maxY
            let fin = max(editor.altoEnunciado, finTinta) + 600
            canvas.contentSize = CGSize(width: EditorHoja.anchoPagina * zoom, height: max(canvas.bounds.height, fin * zoom))
        }

        /// Pone cada página en su sitio según el zoom y carga solo las que están cerca de la
        /// pantalla (las demás sueltan la imagen para no llenar la memoria).
        func colocarPaginas(_ canvas: PKCanvasView) {
            let zoom = canvas.zoomScale
            let cerca = canvas.bounds.insetBy(dx: 0, dy: -canvas.bounds.height)
            let colocadas = editor.paginasColocadas
            let presentes = Set(colocadas.map(\.pagina.id))
            for (id, vista) in vistas where !presentes.contains(id) {
                vista.removeFromSuperview()
                vistas[id] = nil
            }
            for colocada in colocadas {
                let marco = colocada.marco.applying(CGAffineTransform(scaleX: zoom, y: zoom))
                let vista = vistas[colocada.pagina.id] ?? nuevaVista(en: canvas, para: colocada.pagina.id)
                if vista.frame != marco { vista.frame = marco }
                if marco.intersects(cerca) {
                    if vista.image == nil { vista.image = editor.imagen(de: colocada.pagina) }
                } else if vista.image != nil {
                    vista.image = nil
                }
            }
        }

        private func nuevaVista(en canvas: PKCanvasView, para id: UUID) -> UIImageView {
            let vista = UIImageView()
            vista.contentMode = .scaleToFill
            vista.backgroundColor = .white
            vista.isUserInteractionEnabled = false
            vista.layer.borderColor = UIColor(white: 0.7, alpha: 1).cgColor
            vista.layer.borderWidth = 0.5
            // Detrás de todo: la tinta queda encima de la página.
            canvas.insertSubview(vista, at: 0)
            vistas[id] = vista
            return vista
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            editor.notasCambiadas(canvasView.drawing)
            ajustarContenido(canvasView)
        }

        /// Al empezar a escribir aquí, la paleta del Pencil pasa a este lienzo.
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            if !canvasView.isFirstResponder { canvasView.becomeFirstResponder() }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let canvas = scrollView as? PKCanvasView else { return }
            ajustarContenido(canvas)
            colocarPaginas(canvas)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if let canvas = scrollView as? PKCanvasView { colocarPaginas(canvas) }
        }
    }
}
