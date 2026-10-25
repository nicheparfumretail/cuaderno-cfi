import SwiftUI
import PencilKit

/// El lienzo de Notas: PKCanvasView con la paleta de herramientas del sistema (PKToolPicker),
/// que trae el trazo, la goma, el lazo y los gestos del Pencil (doble toque, apretón).
struct LienzoView: UIViewRepresentable {
    @ObservedObject var cuaderno: Cuaderno
    /// Falso mientras hay una hoja abierta encima; al volver, el lienzo recupera la paleta.
    var activo: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(cuaderno: cuaderno)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = cuaderno.dibujo
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .default
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = true
        // Sin zoom: las columnas Debe | Cuenta | Haber tienen que quedar donde se dibujan.
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1

        let paleta = context.coordinator.paleta
        paleta.setVisible(true, forFirstResponder: canvas)
        paleta.addObserver(canvas)
        context.coordinator.version = cuaderno.versionLienzo
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let coordinador = context.coordinator
        if coordinador.version != cuaderno.versionLienzo {
            coordinador.version = cuaderno.versionLienzo
            coordinador.aplicando = true
            canvas.drawing = cuaderno.dibujo
            coordinador.aplicando = false
        }
        if canvas.bounds.width > 0 {
            cuaderno.anchoLienzo = canvas.bounds.width
        }
        Coordinator.ajustarAltura(canvas)
        if activo && !canvas.isFirstResponder {
            DispatchQueue.main.async { canvas.becomeFirstResponder() }
        }
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let cuaderno: Cuaderno
        let paleta = PKToolPicker()
        var version = 0
        var aplicando = false

        init(cuaderno: Cuaderno) {
            self.cuaderno = cuaderno
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !aplicando else { return }
            cuaderno.anchoLienzo = canvasView.bounds.width
            cuaderno.dibujoCambiado(canvasView.drawing)
            Coordinator.ajustarAltura(canvasView)
        }

        /// Siempre queda una pantalla libre por debajo de lo escrito, como en Notas.
        static func ajustarAltura(_ canvas: PKCanvasView) {
            let alto = canvas.bounds.height
            guard alto > 0 else { return }
            let finTinta = canvas.drawing.strokes.isEmpty ? 0 : canvas.drawing.bounds.maxY
            let tamaño = CGSize(width: canvas.bounds.width, height: max(alto * 2, finTinta + alto))
            if canvas.contentSize != tamaño {
                canvas.contentSize = tamaño
            }
        }
    }
}
