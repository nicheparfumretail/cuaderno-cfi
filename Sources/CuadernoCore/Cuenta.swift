import Foundation

/// Cuenta del PGC identificada por su código como texto ("572", "4310", "4751.1").
/// El código manda: el primer dígito es el grupo y los dos primeros, el subgrupo.
public struct Cuenta: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let codigo: String

    /// Acepta códigos de al menos 3 dígitos (1 dígito = grupo, 2 = subgrupo: no se usan en
    /// asientos), opcionalmente con una subcuenta tras un punto, como "4751.1" en los apuntes.
    public init?(_ codigo: String) {
        let limpio = codigo.trimmingCharacters(in: .whitespaces)
        let partes = limpio.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(partes.count),
              partes.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }),
              partes[0].count >= 3,
              let primero = partes[0].first, primero != "0" else { return nil }
        self.codigo = limpio
    }

    public var grupo: Int { Int(String(codigo.prefix(1)))! }
    public var subgrupo: String { String(codigo.prefix(2)) }
    public var nombre: String? { PlanDeCuentas.nombre(de: codigo) }
    public var nombreDelGrupo: String { PlanDeCuentas.grupos[grupo] ?? "" }

    /// "(572) Bancos", como se escribe en el diario.
    public var description: String {
        nombre.map { "(\(codigo)) \($0)" } ?? "(\(codigo))"
    }

    /// El orden alfabético del código coincide con el del cuadro de cuentas: 430 < 4310 < 437.
    public static func < (a: Cuenta, b: Cuenta) -> Bool { a.codigo < b.codigo }
}

extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
