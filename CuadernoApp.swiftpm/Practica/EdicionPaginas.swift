import UIKit
import PencilKit

/// Un arrastre del dedo sobre la página elegida: moverla entera o tirar de una esquina para
/// agrandarla o achicarla sin deformarla (la esquina de enfrente se queda quieta).
@MainActor
struct GestoPagina {
    enum Modo {
        case mover
        case esquina(fija: CGPoint, movil: CGPoint)
    }

    /// Lo que tiene que quedar a la vista de una página movida a un lado (en puntos de página).
    static let bordeVisible: CGFloat = 80

    let pagina: UUID
    let modo: Modo
    /// Dónde estaba la página al cogerla y dónde va ahora, en puntos de página.
    let inicial: CGRect
    var actual: CGRect
    /// Lo escrito encima, hecho imagen, que viaja con la página mientras dura el arrastre.
    var tinta: UIImageView?
    var marcoTinta = CGRect.zero

    /// Dónde queda la página con el dedo desplazado `d` (en puntos de página) desde que la cogió.
    func marco(desplazado d: CGPoint) -> CGRect {
        switch modo {
        case .mover:
            let borde = GestoPagina.bordeVisible
            let x = min(max(inicial.minX + d.x, borde - inicial.width), EditorHoja.anchoPagina - borde)
            let y = max(inicial.minY + d.y, 0)
            return CGRect(origin: CGPoint(x: x, y: y), size: inicial.size)
        case .esquina(let fija, let movil):
            let proporcion: CGFloat = inicial.height / max(inicial.width, 1)
            let dx: CGFloat = abs(movil.x + d.x - fija.x)
            let dy: CGFloat = abs(movil.y + d.y - fija.y)
            let pedido: CGFloat = max(dx, dy / proporcion)
            let ancho: CGFloat = min(max(pedido, EditorHoja.anchoMinimoPagina), EditorHoja.anchoPagina)
            let alto: CGFloat = ancho * proporcion
            let x: CGFloat = movil.x > fija.x ? fija.x : fija.x - ancho
            let y: CGFloat = movil.y > fija.y ? fija.y : fija.y - alto
            return CGRect(x: x, y: max(y, 0), width: ancho, height: alto)
        }
    }
}

/// Con el dedo: tocar una página la elige (o la suelta); arrastrar la elegida la mueve y tirar
/// de una de sus esquinas la agranda o la achica. El Pencil sigue escribiendo como siempre, y
/// fuera de la página elegida el dedo sigue desplazando el enunciado.
extension LienzoNotasView.Coordinador: UIGestureRecognizerDelegate {
    func prepararEdicion(_ vista: VistaEnunciado) {
        let dedo = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        let tocar = UITapGestureRecognizer(target: self, action: #selector(tocado(_:)))
        tocar.allowedTouchTypes = dedo
        tocar.delegate = self
        vista.addGestureRecognizer(tocar)
        let arrastrar = UIPanGestureRecognizer(target: self, action: #selector(arrastrado(_:)))
        arrastrar.allowedTouchTypes = dedo
        arrastrar.maximumNumberOfTouches = 1
        arrastrar.delegate = self
        vista.addGestureRecognizer(arrastrar)
        // El enunciado solo se desplaza si el dedo no ha cogido la página elegida.
        vista.canvas.panGestureRecognizer.require(toFail: arrastrar)
        vista.seleccion.alAjustar = { [weak self, weak vista] in
            guard let self = self, let vista = vista, let id = self.seleccionada else { return }
            self.editor.ajustarAlAncho(id)
            self.recargarNotas(vista.canvas)
        }
        vista.seleccion.alQuitar = { [weak self, weak vista] in
            guard let self = self, let vista = vista, let id = self.seleccionada else { return }
            self.seleccionada = nil
            self.editor.quitarPagina(id)
            self.recargarNotas(vista.canvas)
        }
    }

    /// El lienzo vuelve a enseñar las notas del editor, ya movidas o quitadas.
    func recargarNotas(_ canvas: PKCanvasView) {
        version = editor.versionNotas
        canvas.drawing = editor.notas
        moviendoTinta = false
        ajustarContenido(canvas)
        colocarPaginas(canvas)
    }

    // MARK: - Gestos

    @objc func tocado(_ toque: UITapGestureRecognizer) {
        guard let vista = toque.view as? VistaEnunciado else { return }
        let punto = enPagina(toque.location(in: vista.canvas), vista.canvas)
        let tocada = editor.paginasColocadas.last { $0.marco.contains(punto) }?.pagina.id
        seleccionada = tocada == seleccionada ? nil : tocada
        colocarPaginas(vista.canvas)
    }

    @objc func arrastrado(_ arrastre: UIPanGestureRecognizer) {
        guard let vista = arrastre.view as? VistaEnunciado else { return }
        let canvas = vista.canvas
        switch arrastre.state {
        case .began:
            guard var nuevo = agarre(en: inicio(de: arrastre, en: canvas), canvas: canvas) else { return }
            if let pagina = vistas[nuevo.pagina] { vista.paginas.bringSubviewToFront(pagina) }
            levantarTinta(&nuevo, en: vista)
            gesto = nuevo
            colocarPaginas(canvas)
        case .changed:
            guard var enCurso = gesto else { return }
            let t = arrastre.translation(in: canvas)
            let zoom = canvas.zoomScale
            enCurso.actual = enCurso.marco(desplazado: CGPoint(x: t.x / zoom, y: t.y / zoom))
            gesto = enCurso
            colocarPaginas(canvas)
        case .ended:
            terminar(guardando: true, canvas: canvas)
        default:
            terminar(guardando: false, canvas: canvas)
        }
    }

    func gestureRecognizerShouldBegin(_ gesto: UIGestureRecognizer) -> Bool {
        guard let arrastre = gesto as? UIPanGestureRecognizer,
              let vista = gesto.view as? VistaEnunciado else { return true }
        return agarre(en: inicio(de: arrastre, en: vista.canvas), canvas: vista.canvas) != nil
    }

    /// Los botones de la barrita de la página elegida van a lo suyo.
    func gestureRecognizer(_ gesto: UIGestureRecognizer, shouldReceive toque: UITouch) -> Bool {
        guard let vista = gesto.view as? VistaEnunciado, let tocada = toque.view else { return true }
        return !tocada.isDescendant(of: vista.seleccion)
    }

    // MARK: - Ayudas

    private func enPagina(_ punto: CGPoint, _ canvas: PKCanvasView) -> CGPoint {
        CGPoint(x: punto.x / canvas.zoomScale, y: punto.y / canvas.zoomScale)
    }

    /// Donde se puso el dedo (el arrastre empieza a contar cuando ya se ha movido un poco).
    private func inicio(de arrastre: UIPanGestureRecognizer, en canvas: PKCanvasView) -> CGPoint {
        let ahora = arrastre.location(in: canvas)
        let recorrido = arrastre.translation(in: canvas)
        return CGPoint(x: ahora.x - recorrido.x, y: ahora.y - recorrido.y)
    }

    /// Qué coge el dedo: una esquina de la página elegida (con holgura, 30 puntos de pantalla,
    /// aunque la página se vea pequeña) o la página entera. Nada si no hay página elegida o el
    /// dedo cae fuera de ella.
    private func agarre(en punto: CGPoint, canvas: PKCanvasView) -> GestoPagina? {
        guard let id = seleccionada, let marco = editor.marco(de: id) else { return nil }
        let zoom = canvas.zoomScale
        let esquinas = [CGPoint(x: marco.minX, y: marco.minY), CGPoint(x: marco.maxX, y: marco.minY),
                        CGPoint(x: marco.minX, y: marco.maxY), CGPoint(x: marco.maxX, y: marco.maxY)]
        let cogida = esquinas.firstIndex { (esquina: CGPoint) -> Bool in
            let dx: CGFloat = esquina.x * zoom - punto.x
            let dy: CGFloat = esquina.y * zoom - punto.y
            return dx * dx + dy * dy < 900
        }
        if let i = cogida {
            return GestoPagina(pagina: id, modo: .esquina(fija: esquinas[3 - i], movil: esquinas[i]),
                               inicial: marco, actual: marco)
        }
        guard marco.applying(CGAffineTransform(scaleX: zoom, y: zoom)).contains(punto) else { return nil }
        return GestoPagina(pagina: id, modo: .mover, inicial: marco, actual: marco)
    }

    /// Lo escrito encima de la página sale del lienzo y se hace imagen, que acompaña a la página
    /// mientras se arrastra; al soltar vuelve al lienzo ya movido.
    private func levantarTinta(_ gesto: inout GestoPagina, en vista: VistaEnunciado) {
        let canvas = vista.canvas
        let inicial = gesto.inicial
        let todas = editor.notas.strokes
        let encima = todas.filter { EditorHoja.estaSobre($0, inicial) }
        guard !encima.isEmpty else { return }
        let dibujo = PKDrawing(strokes: encima)
        let zona = dibujo.bounds
        let escala = min(canvas.traitCollection.displayScale * canvas.zoomScale, 2)
        var imagen = UIImage()
        // En claro, como el lienzo: en modo oscuro la tinta negra saldría blanca.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            imagen = dibujo.image(from: zona, scale: escala)
        }
        let vistaTinta = UIImageView(image: imagen)
        vista.paginas.addSubview(vistaTinta)
        gesto.tinta = vistaTinta
        gesto.marcoTinta = zona
        moviendoTinta = true
        canvas.drawing = PKDrawing(strokes: todas.filter { !EditorHoja.estaSobre($0, inicial) })
    }

    /// Al soltar, la página se queda donde está (y lo escrito encima, con ella); si el arrastre
    /// se cancela, vuelve a su sitio.
    private func terminar(guardando: Bool, canvas: PKCanvasView) {
        guard let hecho = gesto else { return }
        gesto = nil
        hecho.tinta?.removeFromSuperview()
        let movida = guardando && hecho.actual != hecho.inicial
        if movida {
            editor.colocarPagina(hecho.pagina, en: hecho.actual, desde: hecho.inicial)
        } else {
            ordenPuesto = []
        }
        if movida || hecho.tinta != nil {
            recargarNotas(canvas)
        } else {
            colocarPaginas(canvas)
        }
    }
}

/// El marco de la página elegida: borde azul, una bola en cada esquina para tirar de ella y una
/// barrita con «Al ancho» y «Quitar». Deja pasar los toques (el Pencil escribe a través) salvo
/// en la barrita.
final class CapaSeleccion: UIView {
    var alAjustar: (() -> Void)?
    var alQuitar: (() -> Void)?
    private let borde = UIView()
    private let esquinas = (0..<4).map { _ in UIView() }
    private let barra = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isHidden = true
        overrideUserInterfaceStyle = .light
        borde.layer.borderColor = UIColor.systemBlue.cgColor
        borde.layer.borderWidth = 2
        borde.isUserInteractionEnabled = false
        addSubview(borde)
        for esquina in esquinas {
            esquina.bounds = CGRect(x: 0, y: 0, width: 20, height: 20)
            esquina.backgroundColor = .white
            esquina.layer.cornerRadius = 10
            esquina.layer.borderColor = UIColor.systemBlue.cgColor
            esquina.layer.borderWidth = 2
            esquina.isUserInteractionEnabled = false
            addSubview(esquina)
        }
        prepararBarra()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) no se usa")
    }

    private func prepararBarra() {
        let ajustar = UIButton(configuration: CapaSeleccion.boton("Al ancho", icono: "arrow.left.and.right", color: .systemBlue),
                               primaryAction: UIAction { [weak self] _ in self?.alAjustar?() })
        // Quitar pide confirmación: el menú se abre al tocar y hay que elegir «Quitar esta página».
        let quitar = UIButton(configuration: CapaSeleccion.boton("Quitar", icono: "trash", color: .systemRed))
        quitar.menu = UIMenu(title: "Se borra también lo escrito encima", children: [
            UIAction(title: "Quitar esta página", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.alQuitar?()
            },
        ])
        quitar.showsMenuAsPrimaryAction = true
        let fila = UIStackView(arrangedSubviews: [ajustar, quitar])
        fila.axis = .horizontal
        fila.spacing = 2
        let tamaño = fila.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        fila.frame = CGRect(x: 6, y: 2, width: tamaño.width, height: tamaño.height)
        barra.contentView.addSubview(fila)
        barra.bounds = CGRect(x: 0, y: 0, width: tamaño.width + 12, height: tamaño.height + 4)
        barra.layer.cornerRadius = (tamaño.height + 4) / 2
        barra.clipsToBounds = true
        addSubview(barra)
    }

    private static func boton(_ titulo: String, icono: String, color: UIColor) -> UIButton.Configuration {
        var configuracion = UIButton.Configuration.plain()
        configuracion.title = titulo
        configuracion.image = UIImage(systemName: icono)
        configuracion.imagePadding = 6
        configuracion.baseForegroundColor = color
        return configuracion
    }

    /// `marco`: la página elegida en las coordenadas de esta capa; nil si no hay ninguna.
    func mostrar(_ marco: CGRect?) {
        guard let marco = marco else {
            isHidden = true
            return
        }
        isHidden = false
        borde.frame = marco
        let puntos = [CGPoint(x: marco.minX, y: marco.minY), CGPoint(x: marco.maxX, y: marco.minY),
                      CGPoint(x: marco.minX, y: marco.maxY), CGPoint(x: marco.maxX, y: marco.maxY)]
        for (esquina, punto) in zip(esquinas, puntos) { esquina.center = punto }
        // La barrita va encima de la página; si la parte de arriba no se ve, arriba de la pantalla.
        let tamaño = barra.bounds.size
        let visible = bounds
        let x = min(max(marco.midX - tamaño.width / 2, visible.minX + 8), visible.maxX - tamaño.width - 8)
        let y = min(max(marco.minY - tamaño.height - 16, visible.minY + 8), marco.maxY + 8)
        barra.frame = CGRect(origin: CGPoint(x: x, y: y), size: tamaño)
    }

    /// Solo la barrita recoge toques; el resto pasa al lienzo de debajo.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let tocada = super.hitTest(point, with: event)
        return tocada === self ? nil : tocada
    }
}
