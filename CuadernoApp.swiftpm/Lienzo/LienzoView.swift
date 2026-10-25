import SwiftUI
import PencilKit

/// Dónde está la página en pantalla (zoom y desplazamiento): la plantilla y la cabecera
/// se dibujan con estos valores para seguir a la tinta.
@MainActor
final class VistaLienzo: ObservableObject {
    @Published var zoom: CGFloat = 1
    @Published var desplazamiento: CGPoint = .zero

    /// De coordenada de página (0–1 del ancho) a punto de pantalla.
    func xPantalla(_ fraccion: Double) -> CGFloat {
        CGFloat(fraccion) * EditorHoja.anchoPagina * zoom - desplazamiento.x
    }

    /// De punto de pantalla a coordenada de página (0–1 del ancho).
    func fraccion(xPantalla x: CGFloat) -> Double {
        Double((x + desplazamiento.x) / (EditorHoja.anchoPagina * zoom))
    }
}

/// PKCanvasView que avisa cuando cambia de tamaño, para volver a encajar la página.
final class CanvasPagina: PKCanvasView {
    var alMaquetar: ((PKCanvasView) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        alMaquetar?(self)
    }
}

/// El lienzo de Notas: PKCanvasView con la paleta del sistema (PKToolPicker), que trae el trazo,
/// la goma, el lazo y los gestos del Pencil. La página tiene ancho fijo y admite un poco de zoom.
struct LienzoView: UIViewRepresentable {
    @ObservedObject var editor: EditorHoja
    let vista: VistaLienzo
    /// Falso mientras hay una hoja abierta encima; al volver, el lienzo recupera la paleta.
    var activo: Bool

    /// Zoom máximo sobre el tamaño que encaja la página en pantalla: un poco, no mucho.
    static let zoomMaximo: CGFloat = 1.8

    func makeCoordinator() -> Coordinator {
        Coordinator(editor: editor, vista: vista)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = CanvasPagina()
        let coordinador = context.coordinator
        canvas.alMaquetar = { coordinador.encajar($0) }
        canvas.drawing = editor.dibujo
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .default
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = true
        canvas.contentInsetAdjustmentBehavior = .never

        let paleta = context.coordinator.paleta
        paleta.setVisible(true, forFirstResponder: canvas)
        paleta.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.encajar(canvas)
        if activo && !canvas.isFirstResponder {
            DispatchQueue.main.async { canvas.becomeFirstResponder() }
        }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let editor: EditorHoja
        let vista: VistaLienzo
        let paleta = PKToolPicker()
        private var anchoEncajado: CGFloat = 0

        init(editor: EditorHoja, vista: VistaLienzo) {
            self.editor = editor
            self.vista = vista
        }

        /// Cuando cambia el ancho en pantalla (panel plegado, giro), la página vuelve a encajar.
        func encajar(_ canvas: PKCanvasView) {
            let ancho = canvas.bounds.width
            guard ancho > 0, abs(ancho - anchoEncajado) > 0.5 else { return }
            anchoEncajado = ancho
            let base = ancho / EditorHoja.anchoPagina
            canvas.minimumZoomScale = base
            canvas.maximumZoomScale = base * LienzoView.zoomMaximo
            canvas.zoomScale = base
            ajustarContenido(canvas)
            publicar(canvas)
        }

        /// Siempre queda espacio libre por debajo de lo escrito, como en Notas.
        func ajustarContenido(_ canvas: PKCanvasView) {
            let zoom = canvas.zoomScale
            let finTinta = canvas.drawing.strokes.isEmpty ? 0 : canvas.drawing.bounds.maxY
            let alto = max(canvas.bounds.height * 1.5, (finTinta + 600) * zoom)
            canvas.contentSize = CGSize(width: EditorHoja.anchoPagina * zoom, height: alto)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            editor.dibujoCambiado(canvasView.drawing)
            ajustarContenido(canvasView)
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            if let canvas = scrollView as? PKCanvasView { ajustarContenido(canvas) }
            publicar(scrollView)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            publicar(scrollView)
        }

        /// Se publica fuera del ciclo de dibujo de SwiftUI para no tocar el estado a mitad de una actualización.
        private func publicar(_ scrollView: UIScrollView) {
            let zoom = scrollView.zoomScale
            let desplazamiento = scrollView.contentOffset
            let vista = self.vista
            DispatchQueue.main.async {
                if vista.zoom != zoom { vista.zoom = zoom }
                if vista.desplazamiento != desplazamiento { vista.desplazamiento = desplazamiento }
            }
        }
    }
}
