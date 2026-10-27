import Foundation

/// Balance de comprobación de sumas y saldos. Si la partida doble se ha respetado en cada
/// asiento, Σ sumas Debe = Σ sumas Haber y Σ saldos deudores = Σ saldos acreedores.
public struct BalanceComprobacion: Sendable {
    public struct Linea: Hashable, Identifiable, Sendable {
        public var id: String { cuenta }
        public let cuenta: String
        public let sumaDebe: Decimal
        public let sumaHaber: Decimal

        public var saldoDeudor: Decimal { max(sumaDebe - sumaHaber, 0) }
        public var saldoAcreedor: Decimal { max(sumaHaber - sumaDebe, 0) }
    }

    public let lineas: [Linea]

    public init(asientos: [Asiento]) {
        var debe: [String: Decimal] = [:]
        var haber: [String: Decimal] = [:]
        for apunte in asientos.flatMap(\.apuntes) {
            debe[apunte.cuenta, default: 0] += apunte.debe
            haber[apunte.cuenta, default: 0] += apunte.haber
        }
        lineas = Set(debe.keys).union(haber.keys).sorted().map {
            Linea(cuenta: $0, sumaDebe: debe[$0] ?? 0, sumaHaber: haber[$0] ?? 0)
        }
    }

    public var totalSumaDebe: Decimal { lineas.reduce(0) { $0 + $1.sumaDebe } }
    public var totalSumaHaber: Decimal { lineas.reduce(0) { $0 + $1.sumaHaber } }
    public var totalSaldoDeudor: Decimal { lineas.reduce(0) { $0 + $1.saldoDeudor } }
    public var totalSaldoAcreedor: Decimal { lineas.reduce(0) { $0 + $1.saldoAcreedor } }

    public var cuadra: Bool {
        totalSumaDebe == totalSumaHaber && totalSaldoDeudor == totalSaldoAcreedor
    }
}
