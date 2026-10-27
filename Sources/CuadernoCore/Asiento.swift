import Foundation

public enum ErrorAsiento: Error, Equatable, LocalizedError {
    case sinApuntes
    case cuentaNoValida(String)
    case importeNoPositivo(cuenta: String)
    case descuadre(debe: Decimal, haber: Decimal)
    case numeroRepetido(Int)

    /// Debe − Haber. Si es positiva, falta esa cantidad en el Haber; si es negativa, en el Debe.
    public var diferencia: Decimal? {
        if case let .descuadre(debe, haber) = self { return debe - haber }
        return nil
    }

    public var errorDescription: String? {
        switch self {
        case .sinApuntes:
            return "El asiento no tiene apuntes."
        case let .cuentaNoValida(codigo):
            return "«\(codigo)» no es un código de cuenta del PGC (mínimo 3 dígitos, sin empezar por 0)."
        case let .importeNoPositivo(cuenta):
            return "El importe de la cuenta \(cuenta) tiene que ser mayor que cero. El lado lo da la columna, no el signo."
        case let .descuadre(debe, haber):
            let dif = debe - haber
            let falta = Importe.formatear(dif < 0 ? -dif : dif)
            return "No cuadra: el Debe suma \(Importe.formatear(debe)) y el Haber \(Importe.formatear(haber)). "
                + "Faltan \(falta) en el \(dif > 0 ? "Haber" : "Debe")."
        case let .numeroRepetido(numero):
            return "Ya hay un asiento con el número \(numero)."
        }
    }
}

/// El asiento es el único dato del cuaderno: Diario, Mayor, Balance y KPIs se calculan a partir
/// de él. Solo existe si cumple la partida doble: Σ Debe = Σ Haber.
public struct Asiento: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var empresa: String
    /// 0 = sin numerar; el diario le asigna el siguiente al añadirlo.
    public var numero: Int
    public var fecha: Fecha
    public var concepto: String
    public private(set) var apuntes: [Apunte]

    public init(id: UUID = UUID(), empresa: String, numero: Int = 0, fecha: Fecha,
                concepto: String, apuntes: [Apunte]) throws {
        try Asiento.validar(apuntes)
        self.id = id
        self.empresa = empresa
        self.numero = numero
        self.fecha = fecha
        self.concepto = concepto
        self.apuntes = apuntes
    }

    public var sumaDebe: Decimal { apuntes.reduce(0) { $0 + $1.debe } }
    public var sumaHaber: Decimal { apuntes.reduce(0) { $0 + $1.haber } }

    /// Apuntes en el orden del cuaderno: primero el Debe y luego el Haber («a ...»).
    public var apuntesOrdenados: [Apunte] {
        apuntes.filter { $0.lado == .debe } + apuntes.filter { $0.lado == .haber }
    }

    /// Comprueba las reglas sin crear el asiento: sirve para avisar mientras se escribe.
    public static func validar(_ apuntes: [Apunte]) throws {
        guard !apuntes.isEmpty else { throw ErrorAsiento.sinApuntes }
        for apunte in apuntes {
            guard Cuenta(apunte.cuenta) != nil else { throw ErrorAsiento.cuentaNoValida(apunte.cuenta) }
            guard apunte.importe > 0 else { throw ErrorAsiento.importeNoPositivo(cuenta: apunte.cuenta) }
        }
        let debe = apuntes.reduce(Decimal(0)) { $0 + $1.debe }
        let haber = apuntes.reduce(Decimal(0)) { $0 + $1.haber }
        guard debe == haber else { throw ErrorAsiento.descuadre(debe: debe, haber: haber) }
    }

    private enum CodingKeys: String, CodingKey { case id, empresa, numero, fecha, concepto, apuntes }

    /// Al leer un JSON también se valida: un asiento descuadrado no entra ni desde un archivo.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: try c.decode(UUID.self, forKey: .id),
                      empresa: try c.decode(String.self, forKey: .empresa),
                      numero: try c.decode(Int.self, forKey: .numero),
                      fecha: try c.decode(Fecha.self, forKey: .fecha),
                      concepto: try c.decode(String.self, forKey: .concepto),
                      apuntes: try c.decode([Apunte].self, forKey: .apuntes))
    }
}
