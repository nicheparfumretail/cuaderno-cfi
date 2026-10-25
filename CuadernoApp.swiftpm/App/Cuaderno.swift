import SwiftUI
import PencilKit

/// Estado de la app. La hoja de tinta es lo que escribe Iulian; al dejar de escribir se lee
/// entera y se convierte en asientos. Los que cuadran forman el diario, que se guarda en JSON
/// para exportarlo. Todo vive en la carpeta Documentos de la app.
@MainActor
final class Cuaderno: ObservableObject {
    static let empresa = "Mi cuaderno"

    /// Lo leído de la tinta, en el orden del lienzo, cuadre o no.
    @Published private(set) var hoja: [AsientoLeido] = []
    @Published private(set) var leyendo = false
    /// Cambia cuando el lienzo se sustituye desde fuera (hoja nueva): el lienzo se repinta.
    @Published private(set) var versionLienzo = 0
    @Published var aviso: String?

    /// La tinta. No es @Published: cada trazo redibujaría el diario entero sin necesidad.
    private(set) var dibujo = PKDrawing()
    /// Ancho del lienzo en pantalla: la mitad izquierda es el Debe y la derecha, el Haber.
    var anchoLienzo: CGFloat = 0 {
        didSet {
            if abs(anchoLienzo - oldValue) > 1 { programarLectura(espera: 0) }
        }
    }

    let urlDiario: URL
    private let urlLienzo: URL
    private var lectura: Task<Void, Never>?

    init() {
        let carpeta = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        urlDiario = carpeta.appendingPathComponent("diario.json")
        urlLienzo = carpeta.appendingPathComponent("lienzo.drawing")
        if let datos = try? Data(contentsOf: urlLienzo), let guardado = try? PKDrawing(data: datos) {
            dibujo = guardado
        }
    }

    /// Los asientos de la hoja que cumplen la partida doble, numerados en el orden del lienzo.
    var asientos: [Asiento] {
        hoja.enumerated().compactMap { indice, leido in
            try? leido.asiento(empresa: Cuaderno.empresa, numero: indice + 1).get()
        }
    }

    // MARK: Tinta → asientos

    func dibujoCambiado(_ nuevo: PKDrawing) {
        dibujo = nuevo
        programarLectura(espera: 1.2)
    }

    /// Lee la hoja cuando se deja de escribir un momento (cada trazo nuevo reinicia la espera).
    func programarLectura(espera segundos: Double) {
        lectura?.cancel()
        lectura = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(segundos * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.leer()
        }
    }

    private func leer() async {
        guard anchoLienzo > 0 else { return }
        guard !dibujo.strokes.isEmpty else {
            hoja = []
            guardar()
            return
        }
        leyendo = true
        let palabras = await Reconocedor.palabras(de: dibujo, anchoLienzo: anchoLienzo)
        leyendo = false
        guard !Task.isCancelled else { return }
        hoja = LectorAsientos.leer(palabras)
        guardar()
    }

    func hojaNueva() {
        lectura?.cancel()
        dibujo = PKDrawing()
        versionLienzo += 1
        hoja = []
        guardar()
    }

    // MARK: Guardado

    private func guardar() {
        try? dibujo.dataRepresentation().write(to: urlLienzo, options: .atomic)
        var diario = Diario()
        for asiento in asientos { try? diario.añadir(asiento) }
        do {
            try diario.json().write(to: urlDiario, options: .atomic)
        } catch {
            aviso = "No se ha podido guardar el diario: \(error.localizedDescription)"
        }
    }
}
