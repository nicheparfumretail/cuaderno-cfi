import SwiftUI
import PencilKit

/// Estado de la app: el diario (el único dato contable), el lienzo y qué parte del lienzo
/// ya se ha pasado a limpio. Todo se guarda en la carpeta Documentos de la app.
@MainActor
final class Cuaderno: ObservableObject {
    @Published private(set) var diario = Diario()
    @Published var empresa: String {
        didSet { UserDefaults.standard.set(empresa, forKey: Clave.empresa) }
    }
    /// Cambia cuando el lienzo se sustituye desde fuera (hoja nueva): el lienzo se repinta.
    @Published private(set) var versionLienzo = 0
    @Published var aviso: String?

    /// La tinta. No es @Published: cada trazo redibujaría el diario entero sin necesidad.
    private(set) var dibujo = PKDrawing()
    /// Trazos ya pasados a limpio; «Pasar a limpio» solo lee lo escrito después.
    private(set) var trazosProcesados: Int
    /// Ancho del lienzo en pantalla: dice en qué columna (Debe, Cuenta, Haber) cae cada trazo.
    var anchoLienzo: CGFloat = 0

    let urlDiario: URL
    private let urlLienzo: URL
    /// Si el diario guardado no se pudo leer, no se guarda nada encima para no perderlo.
    private var diarioIlegible = false
    private var guardadoLienzo: Task<Void, Never>?

    private enum Clave {
        static let empresa = "empresa"
        static let procesados = "trazosProcesados"
    }

    init() {
        let carpeta = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        urlDiario = carpeta.appendingPathComponent("diario.json")
        urlLienzo = carpeta.appendingPathComponent("lienzo.drawing")
        empresa = UserDefaults.standard.string(forKey: Clave.empresa) ?? "Mi empresa"
        trazosProcesados = UserDefaults.standard.integer(forKey: Clave.procesados)

        if let datos = try? Data(contentsOf: urlDiario) {
            do {
                diario = try Diario.desdeJSON(datos)
            } catch {
                // No se sobrescribe: se deja una copia aparte y se bloquea el guardado.
                let copia = carpeta.appendingPathComponent("diario-ilegible.json")
                try? FileManager.default.removeItem(at: copia)
                try? FileManager.default.copyItem(at: urlDiario, to: copia)
                diarioIlegible = true
                aviso = "No he podido leer el diario guardado (\(error.localizedDescription)). "
                    + "Hay una copia en diario-ilegible.json y no se guardará nada hasta arreglarlo."
            }
        } else {
            guardarDiario()
        }
        if let datos = try? Data(contentsOf: urlLienzo), let guardado = try? PKDrawing(data: datos) {
            dibujo = guardado
        }
        trazosProcesados = min(trazosProcesados, dibujo.strokes.count)
    }

    // MARK: Diario

    var asientos: [Asiento] { diario.asientos(de: empresa) }

    var empresas: [String] { Array(Set(diario.empresas + [empresa])).sorted() }

    func añadir(_ asiento: Asiento) throws {
        try diario.añadir(asiento)
        guardarDiario()
    }

    func reemplazar(_ asiento: Asiento) {
        diario.reemplazar(asiento)
        guardarDiario()
    }

    func eliminar(id: UUID) {
        diario.eliminar(id: id)
        guardarDiario()
    }

    func cargarCasoTuria() {
        if !diario.empresas.contains(CasoTuria.empresa) {
            for asiento in CasoTuria.asientos() { try? diario.añadir(asiento) }
            guardarDiario()
        }
        empresa = CasoTuria.empresa
    }

    func guardarDiario() {
        guard !diarioIlegible else {
            aviso = "El diario guardado no se puede leer; no se guarda nada para no pisarlo."
            return
        }
        do {
            try diario.json().write(to: urlDiario, options: .atomic)
        } catch {
            aviso = "No se ha podido guardar el diario: \(error.localizedDescription)"
        }
    }

    // MARK: Lienzo

    var trazosSinPasar: PKDrawing {
        PKDrawing(strokes: Array(dibujo.strokes.dropFirst(trazosProcesados)))
    }

    var totalTrazos: Int { dibujo.strokes.count }

    func dibujoCambiado(_ nuevo: PKDrawing) {
        dibujo = nuevo
        if trazosProcesados > nuevo.strokes.count {
            // Se han borrado trazos con la goma: lo que quede cuenta como ya pasado.
            marcarProcesados(hasta: nuevo.strokes.count)
        }
        guardadoLienzo?.cancel()
        guardadoLienzo = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            self?.guardarLienzo()
        }
    }

    func marcarProcesados(hasta total: Int) {
        trazosProcesados = total
        UserDefaults.standard.set(total, forKey: Clave.procesados)
    }

    func hojaNueva() {
        dibujo = PKDrawing()
        versionLienzo += 1
        marcarProcesados(hasta: 0)
        guardarLienzo()
    }

    private func guardarLienzo() {
        try? dibujo.dataRepresentation().write(to: urlLienzo, options: .atomic)
    }
}
