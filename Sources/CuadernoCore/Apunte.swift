import Foundation

public enum Lado: String, Codable, Sendable, CaseIterable {
    case debe
    case haber
}

/// Una línea de un asiento: una cuenta, un lado (Debe o Haber) y un importe positivo.
/// En JSON el importe va como texto ("1185.80") para que ningún lector lo pase por `Double`.
public struct Apunte: Hashable, Codable, Sendable {
    public var lado: Lado
    public var cuenta: String
    public var importe: Decimal
    /// Tercero o aclaración que en el cuaderno va entre paréntesis: «(430) Clientes (Nord)».
    public var detalle: String?

    public init(_ lado: Lado, _ cuenta: String, _ importe: Decimal, detalle: String? = nil) {
        self.lado = lado
        self.cuenta = cuenta.trimmingCharacters(in: .whitespaces)
        self.importe = importe
        self.detalle = detalle
    }

    public var debe: Decimal { lado == .debe ? importe : 0 }
    public var haber: Decimal { lado == .haber ? importe : 0 }

    private enum CodingKeys: String, CodingKey { case lado, cuenta, importe, detalle }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let texto = try c.decode(String.self, forKey: .importe)
        guard let importe = Decimal(string: texto, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorruptedError(forKey: .importe, in: c,
                                                   debugDescription: "Importe no válido: \(texto)")
        }
        self.init(try c.decode(Lado.self, forKey: .lado),
                  try c.decode(String.self, forKey: .cuenta),
                  importe,
                  detalle: try c.decodeIfPresent(String.self, forKey: .detalle))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lado, forKey: .lado)
        try c.encode(cuenta, forKey: .cuenta)
        try c.encode("\(importe)", forKey: .importe)
        try c.encodeIfPresent(detalle, forKey: .detalle)
    }
}
