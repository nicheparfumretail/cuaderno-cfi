import SwiftUI
import PencilKit
import UniformTypeIdentifiers

/// Las notas sobre el enunciado de una práctica: las páginas detrás y un lienzo de PencilKit
/// transparente delante. El dedo mueve y amplía (hasta ×4, para leer la letra pequeña); el
/// Pencil escribe encima de las páginas o en los márgenes. Manteniendo el dedo se pega una
/// captura o un PDF copiados.
struct LienzoNotasView: UIViewRepresentable {
    @ObservedObject var editor: EditorHoja
    let paleta: PKToolPicker
    /// Lo pegado con el menú de mantener pulsado.
    let pegar: ([NSItemProvider]) -> Void

    static let zoomMaximo: CGFloat = 4

    func makeCoordinator() -> Coordinador {
        Coordinador(editor: editor, paleta: paleta)
    }

    func makeUIView(context: Context) -> VistaEnunciado {
        let vista = VistaEnunciado()
        let canvas = vista.canvas
        let coordinador = context.coordinator
        canvas.alMaquetar = { coordinador.encajar($0) }
        canvas.drawing = editor.notas
        canvas.delegate = coordinador
        // El dedo mueve el enunciado; solo el Pencil escribe.
        canvas.drawingPolicy = .pencilOnly
        // Transparente, para que se vean las páginas de detrás. Siempre en claro: con el modo
        // oscuro, la tinta negra no se vuelve blanca sobre el papel blanco.
        canvas.overrideUserInterfaceStyle = .light
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = true
        canvas.contentInsetAdjustmentBehavior = .never
        paleta.setVisible(true, forFirstResponder: canvas)
        // La paleta sigue a la vista al pegar (el menú de pegar necesita el foco).
        paleta.setVisible(true, forFirstResponder: vista)
        paleta.addObserver(canvas)
        coordinador.version = editor.versionNotas
        vista.alPegar = pegar
        return vista
    }

    func updateUIView(_ vista: VistaEnunciado, context: Context) {
        let coordinador = context.coordinator
        vista.alPegar = pegar
        // Las notas se cambiaron desde fuera (al quitar un adjunto).
        if coordinador.version != editor.versionNotas {
            coordinador.version = editor.versionNotas
            vista.canvas.drawing = editor.notas
        }
        coordinador.ajustarContenido(vista.canvas)
        coordinador.colocarPaginas(vista.canvas)
    }

    static func dismantleUIView(_ vista: VistaEnunciado, coordinator: Coordinador) {
        coordinator.paleta?.removeObserver(vista.canvas)
    }

    @MainActor
    final class Coordinador: NSObject, PKCanvasViewDelegate {
        let editor: EditorHoja
        weak var paleta: PKToolPicker?
        var version = 0
        private var anchoEncajado: CGFloat = 0
        /// Una vista de imagen por página, detrás del lienzo.
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

        /// Pone cada página en su sitio según el zoom y el desplazamiento del lienzo, en el mismo
        /// instante en que se mueve, y carga solo las que están cerca de la pantalla (las demás
        /// sueltan la imagen para no llenar la memoria).
        func colocarPaginas(_ canvas: PKCanvasView) {
            guard let contenedor = canvas.superview as? VistaEnunciado else { return }
            let zoom = canvas.zoomScale
            // Las páginas van en coordenadas del contenido: el fondo se mueve como el lienzo.
            contenedor.paginas.bounds.origin = canvas.contentOffset
            let cerca = CGRect(origin: canvas.contentOffset, size: canvas.bounds.size)
                .insetBy(dx: 0, dy: -canvas.bounds.height)
            let colocadas = editor.paginasColocadas
            let presentes = Set(colocadas.map(\.pagina.id))
            for (id, vista) in vistas where !presentes.contains(id) {
                vista.removeFromSuperview()
                vistas[id] = nil
            }
            for colocada in colocadas {
                let marco = colocada.marco.applying(CGAffineTransform(scaleX: zoom, y: zoom))
                let vista = vistas[colocada.pagina.id] ?? nuevaVista(en: contenedor.paginas, para: colocada.pagina.id)
                if vista.frame != marco { vista.frame = marco }
                if marco.intersects(cerca) {
                    if vista.image == nil { vista.image = editor.imagen(de: colocada.pagina) }
                } else if vista.image != nil {
                    vista.image = nil
                }
            }
        }

        private func nuevaVista(en fondo: UIView, para id: UUID) -> UIImageView {
            let vista = UIImageView()
            vista.contentMode = .scaleToFill
            vista.backgroundColor = .white
            vista.layer.borderColor = UIColor(white: 0.7, alpha: 1).cgColor
            vista.layer.borderWidth = 0.5
            fondo.addSubview(vista)
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

/// El panel de notas por dentro: las páginas detrás y el lienzo delante, del mismo tamaño.
/// Manteniendo el dedo sale el menú del sistema con «Pegar» (sin el aviso de permiso de pegar).
final class VistaEnunciado: UIView, UIEditMenuInteractionDelegate {
    let paginas = UIView()
    let canvas = CanvasPagina()
    var alPegar: (([NSItemProvider]) -> Void)?
    private var menu: UIEditMenuInteraction?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.88, alpha: 1)
        paginas.isUserInteractionEnabled = false
        paginas.clipsToBounds = true
        addSubview(paginas)
        addSubview(canvas)
        let menu = UIEditMenuInteraction(delegate: self)
        addInteraction(menu)
        self.menu = menu
        let mantener = UILongPressGestureRecognizer(target: self, action: #selector(mantenido(_:)))
        // Solo el dedo: el Pencil escribe.
        mantener.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        addGestureRecognizer(mantener)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no se usa")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        paginas.frame = bounds
        canvas.frame = bounds
    }

    @objc private func mantenido(_ gesto: UILongPressGestureRecognizer) {
        guard gesto.state == .began else { return }
        becomeFirstResponder()
        menu?.presentEditMenu(with: UIEditMenuConfiguration(identifier: nil, sourcePoint: gesto.location(in: self)))
    }

    override var canBecomeFirstResponder: Bool { true }

    /// En este menú solo se pega, y solo si lo copiado es una imagen o un PDF.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UIResponderStandardEditActions.paste(_:)) {
            return UIPasteboard.general.hasImages || UIPasteboard.general.contains(pasteboardTypes: [UTType.pdf.identifier])
        }
        return false
    }

    override func paste(_ sender: Any?) {
        alPegar?(UIPasteboard.general.itemProviders)
    }

    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration,
                             suggestedActions: [UIMenuElement]) -> UIMenu? {
        if suggestedActions.isEmpty {
            // Nada que pegar: se dice cómo hacerlo en vez de no enseñar nada.
            return UIMenu(children: [UIAction(title: "Copia antes una captura o un PDF", attributes: .disabled) { _ in }])
        }
        return UIMenu(children: suggestedActions)
    }
}
