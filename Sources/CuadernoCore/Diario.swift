import Foundation

/// Libro diario: los asientos en orden de número, de una o varias empresas.
/// Es lo único que se guarda; el resto de libros se derivan de aquí.
public struct Diario: Hashable, Codable, Sendable {
    public static let versionFormato = 1

    public private(set) var asientos: [Asiento] = []

    public init() {}

    public var empresas: [String] {
        Array(Set(asientos.map(\.empresa))).sorted()
    }

    public func asientos(de empresa: String) -> [Asiento] {
        asientos.filter { $0.empresa == empresa }
    }

    public func siguienteNumero(empresa: String) -> Int {
        (asientos(de: empresa).map(\.numero).max() ?? 0) + 1
    }

    /// Añade un asiento ya validado. Si viene sin número (0), recibe el siguiente de su empresa.
    @discardableResult
    public mutating func añadir(_ asiento: Asiento) throws -> Asiento {
        var nuevo = asiento
        if nuevo.numero <= 0 {
            nuevo.numero = siguienteNumero(empresa: nuevo.empresa)
        } else if asientos.contains(where: { $0.empresa == nuevo.empresa && $0.numero == nuevo.numero }) {
            throw ErrorAsiento.numeroRepetido(nuevo.numero)
        }
        asientos.append(nuevo)
        ordenar()
        return nuevo
    }

    /// Sustituye un asiento corregido (mismo `id`).
    public mutating func reemplazar(_ asiento: Asiento) {
        guard let i = asientos.firstIndex(where: { $0.id == asiento.id }) else { return }
        asientos[i] = asiento
        ordenar()
    }

    public mutating func eliminar(id: UUID) {
        asientos.removeAll { $0.id == id }
    }

    /// Cuentas con algún movimiento, en el orden del cuadro de cuentas.
    public func cuentasUsadas(empresa: String) -> [String] {
        let codigos = Set(asientos(de: empresa).flatMap { $0.apuntes.map(\.cuenta) })
        return codigos.sorted()
    }

    private mutating func ordenar() {
        asientos.sort { ($0.empresa, $0.numero) < ($1.empresa, $1.numero) }
    }

    // MARK: JSON — { "version": 1, "asientos": [...], "nombresDeCuentas": {...} }

    private enum CodingKeys: String, CodingKey { case version, asientos, nombresDeCuentas }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        asientos = try c.decode([Asiento].self, forKey: .asientos)
        ordenar()
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Diario.versionFormato, forKey: .version)
        try c.encode(asientos, forKey: .asientos)
        // Solo para lectores de fuera (el visor del PC): al leer se ignora, el dato son los códigos.
        var nombres: [String: String] = [:]
        for codigo in Set(asientos.flatMap { $0.apuntes.map(\.cuenta) }) {
            nombres[codigo] = PlanDeCuentas.nombre(de: codigo)
        }
        try c.encode(nombres, forKey: .nombresDeCuentas)
    }

    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func desdeJSON(_ datos: Data) throws -> Diario {
        try JSONDecoder().decode(Diario.self, from: datos)
    }
}
