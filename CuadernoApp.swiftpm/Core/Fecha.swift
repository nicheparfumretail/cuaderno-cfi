import Foundation

/// Fecha contable (día, mes, año) sin hora ni zona horaria: un asiento del 31/03 es del 31/03
/// en cualquier dispositivo. En JSON se guarda como "2025-03-31".
public struct Fecha: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let año: Int
    public let mes: Int
    public let dia: Int

    public init?(año: Int, mes: Int, dia: Int) {
        guard (1...12).contains(mes), dia >= 1, dia <= Fecha.diasDelMes(mes, año: año) else { return nil }
        self.año = año
        self.mes = mes
        self.dia = dia
    }

    /// "2025-03-31"
    public init?(iso: String) {
        let partes = iso.split(separator: "-").compactMap { Int($0) }
        guard partes.count == 3 else { return nil }
        self.init(año: partes[0], mes: partes[1], dia: partes[2])
    }

    /// "31/03/2025" (como se escribe en el cuaderno) o "2025-03-31".
    public init?(texto: String) {
        let limpio = texto.trimmingCharacters(in: .whitespaces)
        if limpio.contains("-") {
            self.init(iso: limpio)
            return
        }
        let partes = limpio.split(separator: "/").compactMap { Int($0) }
        guard partes.count == 3 else { return nil }
        let año = partes[2] < 100 ? 2000 + partes[2] : partes[2]
        self.init(año: año, mes: partes[1], dia: partes[0])
    }

    public static func hoy() -> Fecha {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: Date())
        return Fecha(año: c.year ?? 2025, mes: c.month ?? 1, dia: c.day ?? 1)!
    }

    public var iso: String {
        "\(Fecha.cifras(año, 4))-\(Fecha.cifras(mes, 2))-\(Fecha.cifras(dia, 2))"
    }

    /// "31/03/2025"
    public var description: String {
        "\(Fecha.cifras(dia, 2))/\(Fecha.cifras(mes, 2))/\(Fecha.cifras(año, 4))"
    }

    private static func cifras(_ n: Int, _ ancho: Int) -> String {
        let s = String(n)
        return String(repeating: "0", count: max(0, ancho - s.count)) + s
    }

    public static func < (a: Fecha, b: Fecha) -> Bool {
        (a.año, a.mes, a.dia) < (b.año, b.mes, b.dia)
    }

    private static func diasDelMes(_ mes: Int, año: Int) -> Int {
        switch mes {
        case 2:
            let bisiesto = (año % 4 == 0 && año % 100 != 0) || año % 400 == 0
            return bisiesto ? 29 : 28
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }

    public init(from decoder: Decoder) throws {
        let texto = try decoder.singleValueContainer().decode(String.self)
        guard let fecha = Fecha(iso: texto) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Fecha no válida: \(texto)"))
        }
        self = fecha
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(iso)
    }
}
