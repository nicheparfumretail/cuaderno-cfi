import SwiftUI
import PencilKit

/// Una hoja del cuaderno: su tinta, cómo se lee (apertura, fechas, zonas) y lo último leído.
struct Hoja: Codable, Identifiable {
    let id: UUID
    var creada: Date
    var modificada: Date
    var datos: DatosHoja
    /// La tinta de PencilKit (`PKDrawing.dataRepresentation()`).
    var tinta: Data
    /// Lo último leído de la tinta: así el histórico y la vista en limpio no esperan a Vision.
    var leidos: [AsientoLeido]

    static func nueva(apertura: Bool) -> Hoja {
        Hoja(id: UUID(), creada: Date(), modificada: Date(),
             datos: DatosHoja(esApertura: apertura, fechaInicial: Fecha.hoy()),
             tinta: PKDrawing().dataRepresentation(), leidos: [])
    }

    var dibujo: PKDrawing { (try? PKDrawing(data: tinta)) ?? PKDrawing() }

    var resueltos: [AsientoResuelto] { datos.resolver(leidos, empresa: Archivo.empresa) }
}

/// Las hojas guardadas: una por archivo en Documentos/hojas, la más reciente primero.
@MainActor
final class Archivo: ObservableObject {
    static let empresa = "Mi cuaderno"

    @Published private(set) var hojas: [Hoja] = []
    private let carpeta: URL

    init() {
        let documentos = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        carpeta = documentos.appendingPathComponent("hojas", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        // Restos del prototipo anterior (una sola hoja suelta): ya no se usan.
        for viejo in ["lienzo.drawing", "diario.json"] {
            try? FileManager.default.removeItem(at: documentos.appendingPathComponent(viejo))
        }
        let urls = (try? FileManager.default.contentsOfDirectory(at: carpeta, includingPropertiesForKeys: nil)) ?? []
        hojas = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Hoja.self, from: Data(contentsOf: $0)) }
            .sorted { $0.modificada > $1.modificada }
    }

    func hoja(_ id: UUID) -> Hoja? {
        hojas.first { $0.id == id }
    }

    func crear(apertura: Bool) -> Hoja {
        let hoja = Hoja.nueva(apertura: apertura)
        guardar(hoja)
        return hoja
    }

    func guardar(_ hoja: Hoja) {
        var copia = hoja
        copia.modificada = Date()
        try? JSONEncoder().encode(copia).write(to: url(de: copia.id), options: .atomic)
        if let indice = hojas.firstIndex(where: { $0.id == copia.id }) {
            hojas[indice] = copia
        } else {
            hojas.insert(copia, at: 0)
        }
        hojas.sort { $0.modificada > $1.modificada }
    }

    func borrar(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(de: id))
        hojas.removeAll { $0.id == id }
    }

    private func url(de id: UUID) -> URL {
        carpeta.appendingPathComponent("\(id.uuidString).json")
    }
}

extension Fecha {
    init(_ date: Date) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        self = Fecha(año: c.year ?? 2025, mes: c.month ?? 1, dia: c.day ?? 1) ?? Fecha.hoy()
    }

    var date: Date {
        Calendar.current.date(from: DateComponents(year: año, month: mes, day: dia)) ?? Date()
    }
}
