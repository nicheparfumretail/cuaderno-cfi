import SwiftUI
import PencilKit

/// Una hoja del cuaderno: su tinta, cómo se lee (apertura, fechas, zonas) y lo último leído.
/// En el modo práctica lleva además el enunciado (páginas de imagen) y las notas escritas encima.
struct Hoja: Codable, Identifiable {
    let id: UUID
    var creada: Date
    var modificada: Date
    var datos: DatosHoja
    /// La tinta de PencilKit (`PKDrawing.dataRepresentation()`).
    var tinta: Data
    /// Lo último leído de la tinta: así el histórico y la vista en limpio no esperan a Vision.
    var leidos: [AsientoLeido]
    /// Hoja de práctica: el panel enseña el enunciado y la corrección espera a «Solución».
    var practica = false
    /// Las páginas del enunciado, en orden. Las imágenes van aparte, en la carpeta de la hoja.
    var enunciado: [PaginaEnunciado] = []
    /// Lo escrito encima del enunciado (`PKDrawing.dataRepresentation()`).
    var notas: Data?

    static func nueva(apertura: Bool, practica: Bool = false) -> Hoja {
        Hoja(id: UUID(), creada: Date(), modificada: Date(),
             datos: DatosHoja(esApertura: apertura, fechaInicial: Fecha.hoy()),
             tinta: PKDrawing().dataRepresentation(), leidos: [], practica: practica)
    }

    var dibujo: PKDrawing { (try? PKDrawing(data: tinta)) ?? PKDrawing() }
    var dibujoNotas: PKDrawing { notas.flatMap { try? PKDrawing(data: $0) } ?? PKDrawing() }

    var resueltos: [AsientoResuelto] { datos.resolver(leidos, empresa: Archivo.empresa) }

    private enum CodingKeys: String, CodingKey {
        case id, creada, modificada, datos, tinta, leidos, practica, enunciado, notas
    }
}

extension Hoja {
    /// Tolerante con hojas guardadas por versiones anteriores, que no tenían práctica ni enunciado.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(UUID.self, forKey: .id),
                  creada: try c.decode(Date.self, forKey: .creada),
                  modificada: try c.decode(Date.self, forKey: .modificada),
                  datos: try c.decode(DatosHoja.self, forKey: .datos),
                  tinta: try c.decode(Data.self, forKey: .tinta),
                  leidos: try c.decodeIfPresent([AsientoLeido].self, forKey: .leidos) ?? [],
                  practica: try c.decodeIfPresent(Bool.self, forKey: .practica) ?? false,
                  enunciado: try c.decodeIfPresent([PaginaEnunciado].self, forKey: .enunciado) ?? [],
                  notas: try c.decodeIfPresent(Data.self, forKey: .notas))
    }
}

/// Una página del enunciado de una práctica: una captura, o una página de un PDF o de un Word.
struct PaginaEnunciado: Codable, Hashable, Identifiable {
    let id: UUID
    /// El archivo del que sale (las páginas de un mismo PDF comparten adjunto y se quitan juntas).
    let adjunto: UUID
    let nombre: String
    /// Tamaño de la imagen en píxeles: da la proporción de la página.
    let ancho: Double
    let alto: Double
}

/// Las hojas guardadas: una por archivo en Documentos/hojas, la más reciente primero. Las
/// imágenes del enunciado de cada práctica van en Documentos/hojas/<id de la hoja>/.
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

    func crear(apertura: Bool, practica: Bool = false) -> Hoja {
        let hoja = Hoja.nueva(apertura: apertura, practica: practica)
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
        try? FileManager.default.removeItem(at: carpeta(de: id))
        hojas.removeAll { $0.id == id }
    }

    // MARK: - Imágenes del enunciado

    func guardarImagen(_ datos: Data, pagina: UUID, hoja: UUID) {
        try? FileManager.default.createDirectory(at: carpeta(de: hoja), withIntermediateDirectories: true)
        try? datos.write(to: urlImagen(pagina: pagina, hoja: hoja), options: .atomic)
    }

    func imagen(pagina: UUID, hoja: UUID) -> UIImage? {
        UIImage(contentsOfFile: urlImagen(pagina: pagina, hoja: hoja).path)
    }

    func borrarImagen(pagina: UUID, hoja: UUID) {
        try? FileManager.default.removeItem(at: urlImagen(pagina: pagina, hoja: hoja))
    }

    private func url(de id: UUID) -> URL {
        carpeta.appendingPathComponent("\(id.uuidString).json")
    }

    private func carpeta(de hoja: UUID) -> URL {
        carpeta.appendingPathComponent(hoja.uuidString, isDirectory: true)
    }

    private func urlImagen(pagina: UUID, hoja: UUID) -> URL {
        carpeta(de: hoja).appendingPathComponent("\(pagina.uuidString).jpg")
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
