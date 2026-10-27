import SwiftUI
import PencilKit

/// La hoja de cálculos de una práctica: un lienzo de PencilKit transparente sobre papel
/// cuadriculado, como el de Notas. El dedo la desplaza y la amplía (hasta ×3); el Pencil escribe.
/// Lo escrito se guarda con la hoja pero no se lee: son cuentas, no asientos.
struct LienzoCalculosView: UIViewRepresentable {
    @ObservedObject var editor: EditorHoja
    let paleta: PKToolPicker
    let mando: MandoLienzo

    /// Ancho fijo en puntos de tinta: al cambiar el panel de ancho, lo escrito se escala y no se
    /// descoloca.
    static let anchoPagina: CGFloat = 600
    static let zoomMaximo: CGFloat = 3

    func makeCoordinator() -> Coordinador {
        Coordinador(editor: editor, paleta: paleta)
    }

    func makeUIView(context: Context) -> VistaCalculos {
        let vista = VistaCalculos()
        let canvas = vista.canvas
        let coordinador = context.coordinator
        canvas.alMaquetar = { coordinador.encajar($0) }
        canvas.drawing = editor.calculos
        canvas.delegate = coordinador
        // El dedo mueve la hoja; solo el Pencil escribe.
        canvas.drawingPolicy = .pencilOnly
        // En claro, como el papel: con el modo oscuro, la tinta negra no se vuelve blanca.
        canvas.overrideUserInterfaceStyle = .light
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.alwaysBounceVertical = true
        canvas.contentInsetAdjustmentBehavior = .never
        paleta.setVisible(true, forFirstResponder: canvas)
        paleta.addObserver(canvas)
        mando.canvas = canvas
        return vista
    }

    func updateUIView(_ vista: VistaCalculos, context: Context) {
        mando.canvas = vista.canvas
    }

    static func dismantleUIView(_ vista: VistaCalculos, coordinator: Coordinador) {
        coordinator.paleta?.removeObserver(vista.canvas)
    }

    @MainActor
    final class Coordinador: NSObject, PKCanvasViewDelegate {
        let editor: EditorHoja
        weak var paleta: PKToolPicker?
        private var anchoEncajado: CGFloat = 0

        init(editor: EditorHoja, paleta: PKToolPicker) {
            self.editor = editor
            self.paleta = paleta
        }

        /// Cuando cambia el ancho en pantalla (panel más ancho, giro), la hoja vuelve a encajar.
        func encajar(_ canvas: PKCanvasView) {
            let ancho = canvas.bounds.width
            guard ancho > 0, abs(ancho - anchoEncajado) > 0.5 else { return }
            anchoEncajado = ancho
            let base = ancho / LienzoCalculosView.anchoPagina
            canvas.minimumZoomScale = base
            canvas.maximumZoomScale = base * LienzoCalculosView.zoomMaximo
            canvas.zoomScale = base
            ajustarContenido(canvas)
            colocarCuadricula(canvas)
        }

        /// Siempre queda sitio libre por debajo de lo escrito, como en Notas.
        func ajustarContenido(_ canvas: PKCanvasView) {
            let zoom = canvas.zoomScale
            let finTinta = canvas.drawing.strokes.isEmpty ? 0 : canvas.drawing.bounds.maxY
            let alto = max(canvas.bounds.height * 1.5, (finTinta + 400) * zoom)
            canvas.contentSize = CGSize(width: LienzoCalculosView.anchoPagina * zoom, height: alto)
        }

        func colocarCuadricula(_ canvas: PKCanvasView) {
            guard let vista = canvas.superview as? VistaCalculos else { return }
            vista.cuadricula.mover(a: canvas.contentOffset, zoom: canvas.zoomScale)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            editor.calculosCambiados(canvasView.drawing)
            ajustarContenido(canvasView)
        }

        /// Al empezar a escribir aquí, la paleta del Pencil pasa a esta hoja.
        func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
            if !canvasView.isFirstResponder { canvasView.becomeFirstResponder() }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let canvas = scrollView as? PKCanvasView else { return }
            ajustarContenido(canvas)
            colocarCuadricula(canvas)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if let canvas = scrollView as? PKCanvasView { colocarCuadricula(canvas) }
        }
    }
}

/// La hoja de cálculos por dentro: la cuadrícula detrás y el lienzo delante, del mismo tamaño.
final class VistaCalculos: UIView {
    let cuadricula = Cuadricula()
    let canvas = CanvasPagina()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(cuadricula)
        addSubview(canvas)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no se usa")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cuadricula.frame = bounds
        canvas.frame = bounds
    }
}

/// Papel cuadriculado, como el de Notas. Solo se dibuja lo que se ve, desplazado y ampliado como
/// el lienzo de delante.
final class Cuadricula: UIView {
    /// Lado de cada cuadro, en puntos de tinta.
    static let lado: CGFloat = 25
    private var desplazamiento = CGPoint.zero
    private var zoom: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no se usa")
    }

    func mover(a desplazamiento: CGPoint, zoom: CGFloat) {
        guard desplazamiento != self.desplazamiento || zoom != self.zoom else { return }
        self.desplazamiento = desplazamiento
        self.zoom = zoom
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let contexto = UIGraphicsGetCurrentContext() else { return }
        let paso = Cuadricula.lado * zoom
        guard paso > 3 else { return }
        contexto.setStrokeColor(UIColor(red: 0.80, green: 0.85, blue: 0.92, alpha: 1).cgColor)
        contexto.setLineWidth(0.7)
        var x = -desplazamiento.x.truncatingRemainder(dividingBy: paso)
        if x > 0 { x -= paso }
        while x <= bounds.width {
            contexto.move(to: CGPoint(x: x, y: 0))
            contexto.addLine(to: CGPoint(x: x, y: bounds.height))
            x += paso
        }
        var y = -desplazamiento.y.truncatingRemainder(dividingBy: paso)
        if y > 0 { y -= paso }
        while y <= bounds.height {
            contexto.move(to: CGPoint(x: 0, y: y))
            contexto.addLine(to: CGPoint(x: bounds.width, y: y))
            y += paso
        }
        contexto.strokePath()
    }
}
