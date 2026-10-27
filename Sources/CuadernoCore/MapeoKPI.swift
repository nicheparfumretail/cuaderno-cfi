import Foundation

/// Un KPI es una proyección lineal de los asientos: KPI = Σ w · (Haber − Debe), con w = 1 en
/// las cuentas que entran y 0 en las demás. Ingresos (acreedores) suman y gastos (deudores) restan.
/// Qué cuentas entran es una tabla de prefijos; gana el prefijo más largo ("630" manda sobre "63").
public struct MapeoKPI: Sendable {
    public struct Regla: Sendable {
        public let prefijo: String
        public let entra: Bool

        public init(_ prefijo: String, entra: Bool) {
            self.prefijo = prefijo
            self.entra = entra
        }
    }

    public let nombre: String
    public let reglas: [Regla]

    public init(nombre: String, reglas: [Regla]) {
        self.nombre = nombre
        self.reglas = reglas
    }

    public func entra(_ cuenta: String) -> Bool {
        reglas
            .filter { cuenta.hasPrefix($0.prefijo) }
            .max { $0.prefijo.count < $1.prefijo.count }?
            .entra ?? false
    }

    public func valor(_ asientos: [Asiento]) -> Decimal {
        asientos
            .flatMap(\.apuntes)
            .filter { entra($0.cuenta) }
            .reduce(0) { $0 + $1.haber - $1.debe }
    }

    /// Cuánto mueve un solo asiento el KPI: la «visión aumentada» al escribirlo.
    public func impacto(de asiento: Asiento) -> Decimal {
        valor([asiento])
    }

    /// EBITDA según la cascada de la PyG del PGC: resultado de explotación antes de amortizaciones.
    /// Entran 60–65 y 70–75 (incluye 631 Otros tributos y 740 Subvenciones a la explotación).
    /// No entran 630 (Impuesto sobre beneficios), 66/76 (financieros), 68 (amortizaciones)
    /// ni las cuentas de balance (grupos 1–5).
    public static let ebitda = MapeoKPI(nombre: "EBITDA", reglas: [
        Regla("60", entra: true), Regla("61", entra: true), Regla("62", entra: true),
        Regla("63", entra: true), Regla("64", entra: true), Regla("65", entra: true),
        Regla("630", entra: false),
        Regla("70", entra: true), Regla("71", entra: true), Regla("72", entra: true),
        Regla("73", entra: true), Regla("74", entra: true), Regla("75", entra: true),
    ])
}
