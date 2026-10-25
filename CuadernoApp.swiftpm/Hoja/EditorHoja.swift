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

    @Published private(set) var hoja: Hoja
    @Published private(set) var leyendo = false

    private(set) var dibujo: PKDrawing
    private let archivo: Archivo
    private var lectura: Task<Void, Never>?

    init(hoja: Hoja, archivo: Archivo) {
        self.hoja = hoja
        self.archivo = archivo
        dibujo = hoja.dibujo
    }

    var resueltos: [AsientoResuelto] { hoja.resueltos }
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

    /// Lo que se puede hacer con un apunte, igual desde el panel que desde En limpio.
    func acciones(verMayor: @escaping (String) -> Void) -> AccionesApunte {
        AccionesApunte(
            corregir: { [weak self] fila, apunte in self?.corregir(asiento: fila.asiento, leido: fila.leido, por: apunte) },
            volver: { [weak self] fila in self?.quitarCorreccion(asiento: fila.asiento, leido: fila.leido) },
            verMayor: verMayor)
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

    /// Al salir de la hoja: se guarda la tinta aunque no haya dado tiempo a leerla.
    func cerrar() {
        lectura?.cancel()
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

    private func guardar() {
        hoja.tinta = dibujo.dataRepresentation()
        archivo.guardar(hoja)
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
