import SwiftUI
import PencilKit
import UniformTypeIdentifiers

/// La hoja abierta: recibe la tinta, la relee en segundo plano cuando se deja de escribir
/// y guarda. Nunca bloquea la escritura: lo que no se entiende se queda como recomendación.
@MainActor
final class EditorHoja: ObservableObject {
    /// Ancho fijo de la página en puntos de tinta. La pantalla la escala para que quepa:
    /// así la tinta no se descoloca al plegar el panel o hacer zoom.
    static let anchoPagina: CGFloat = 1000

    @Published var hoja: Hoja {
        didSet { resueltosGuardados = nil }
    }
    @Published private(set) var leyendo = false
    /// Cambia cuando las notas del enunciado se tocan desde fuera de su lienzo (al quitar un adjunto).
    @Published var versionNotas = 0

    private(set) var dibujo: PKDrawing
    /// Lo escrito encima del enunciado, en el modo práctica.
    var notas: PKDrawing
    /// La hoja de cálculos, en el modo práctica.
    var calculos: PKDrawing
    let archivo: Archivo
    private var lectura: Task<Void, Never>?
    private var guardado: Task<Void, Never>?
    /// Las páginas del enunciado ya cargadas. Se vacía sola si falta memoria.
    let imagenes = NSCache<NSUUID, UIImage>()
    /// Los asientos resueltos de la hoja tal como está; se rehacen solo cuando cambia.
    private var resueltosGuardados: [AsientoResuelto]?

    init(hoja: Hoja, archivo: Archivo) {
        self.hoja = hoja
        self.archivo = archivo
        dibujo = hoja.dibujo
        notas = hoja.dibujoNotas
        calculos = hoja.dibujoCalculos
        imagenes.countLimit = 8
    }

    var esPractica: Bool { hoja.practica }
    var resueltos: [AsientoResuelto] {
        if let guardados = resueltosGuardados { return guardados }
        let nuevos = hoja.resueltos
        resueltosGuardados = nuevos
        return nuevos
    }
    var asientos: [Asiento] { resueltos.compactMap(\.asiento) }

    func dibujoCambiado(_ nuevo: PKDrawing) {
        dibujo = nuevo
        programarLectura(espera: 1.2)
    }

    func cambiarZonas(_ zonas: Zonas) {
        hoja.datos.zonas = zonas
        programarLectura(espera: 0.4)
    }

    func ponerFecha(_ fecha: Fecha, asiento indice: Int) {
        hoja.datos.fechasManuales[indice] = fecha
        guardar()
    }

    /// Corrige a mano algo leído (o lo descarta, con `apunte` nil). La tinta no se toca.
    func corregir(asiento indice: Int, leido: Correccion.Leido, por apunte: Apunte?) {
        hoja.datos.corregir(asiento: indice, leido: leido, por: apunte)
        guardar()
    }

    func quitarCorreccion(asiento indice: Int, leido: Correccion.Leido) {
        hoja.datos.quitarCorreccion(asiento: indice, leido: leido)
        guardar()
    }

    func recuperarDescartadas(asiento indice: Int) {
        hoja.datos.recuperarDescartadas(asiento: indice)
        guardar()
    }

    /// Lleva un apunte, con lo que valga ahora, a otro asiento (o lo devuelve al suyo).
    func mover(_ fila: FilaEditable, _ apunte: Apunte, a destino: Int) {
        hoja.datos.mover(asiento: fila.asiento, leido: fila.leido, apunte: apunte, a: destino)
        guardar()
    }

    /// Lo que se puede hacer con un apunte, igual desde el panel que desde En limpio.
    func acciones(interaccion: InteraccionHoja) -> AccionesApunte {
        AccionesApunte(
            corregir: { [weak self] fila, apunte in self?.corregir(asiento: fila.asiento, leido: fila.leido, por: apunte) },
            volver: { [weak self] fila in self?.quitarCorreccion(asiento: fila.asiento, leido: fila.leido) },
            verMayor: { [weak interaccion] codigo in interaccion?.cuentaMayor = CuentaSeleccionada(codigo: codigo) },
            mover: { [weak self] fila, apunte, destino in self?.mover(fila, apunte, a: destino) },
            soltar: { [weak self] fila, destino, lado in self?.soltar(fila, en: destino, lado: lado) },
            asientos: resueltos.map { (indice: $0.numero - 1, titulo: "Nº \($0.numero) · \($0.fecha.description)") })
    }

    /// Un apunte arrastrado desde su asiento a otro (o al otro lado del mismo).
    func soltar(_ fila: FilaEditable, en destino: Int, lado: Lado) {
        guard var apunte = fila.apunte else { return }
        apunte.lado = lado
        mover(fila, apunte, a: destino)
    }

    /// Relee la hoja cuando se deja de escribir un momento; cada trazo nuevo reinicia la espera.
    func programarLectura(espera segundos: Double) {
        lectura?.cancel()
        lectura = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(segundos * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.leer()
        }
    }

    /// Guarda un poco después del último cambio (las notas del enunciado cambian a cada trazo).
    func programarGuardado() {
        guardado?.cancel()
        guardado = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.guardar()
        }
    }

    /// Al salir de la hoja: se guarda la tinta aunque no haya dado tiempo a leerla.
    func cerrar() {
        lectura?.cancel()
        guardado?.cancel()
        leyendo = false
        guardar()
    }

    private func leer() async {
        leyendo = true
        let tinta = await Reconocedor.leer(dibujo, anchoPagina: EditorHoja.anchoPagina, zonas: hoja.datos.zonas)
        leyendo = false
        guard !Task.isCancelled else { return }
        hoja.leidos = LectorAsientos.leer(tinta.palabras, separadores: tinta.separadores, zonas: hoja.datos.zonas)
        guardar()
    }

    func guardar() {
        hoja.tinta = dibujo.dataRepresentation()
        if hoja.practica {
            hoja.notas = notas.dataRepresentation()
            hoja.calculos = calculos.dataRepresentation()
        }
        archivo.guardar(hoja)
    }

    /// La hoja en limpio en PDF, como se ve en la pantalla; con `solucion`, con lo que hay que
    /// revisar de cada asiento.
    func pdf(solucion: Bool, oscuro: Bool) -> DiarioPDF {
        DiarioPDF(resueltos: resueltos, creada: hoja.creada, practica: esPractica, solucion: solucion, oscuro: oscuro)
    }

    /// El diario de la hoja en JSON, para abrirlo en el visor del PC.
    var exportable: DiarioJSON {
        var diario = Diario()
        for asiento in asientos { try? diario.añadir(asiento) }
        return DiarioJSON(datos: (try? diario.json()) ?? Data())
    }
}

struct DiarioJSON: Transferable {
    let datos: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.datos }
            .suggestedFileName("diario.json")
    }
}
