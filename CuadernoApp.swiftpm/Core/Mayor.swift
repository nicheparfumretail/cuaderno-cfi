import Foundation

public enum TipoSaldo: String, Sendable {
    case deudor
    case acreedor
    case saldado
}

/// Libro mayor de una cuenta: sus movimientos con el saldo acumulado (la cuenta en T, en fila).
/// Saldo = Σ Debe − Σ Haber: positivo es deudor y negativo, acreedor.
public struct Mayor: Sendable {
    public struct Movimiento: Hashable, Identifiable, Sendable {
        public let id: String
        public let numero: Int
        public let fecha: Fecha
        public let concepto: String
        public let detalle: String?
        public let debe: Decimal
        public let haber: Decimal
        /// Saldo de la cuenta después de este movimiento.
        public let saldo: Decimal
        /// Las cuentas del otro lado del asiento: con qué se cargó o se abonó esta.
        public let contrapartidas: [String]
    }

    public let cuenta: String
    public let movimientos: [Movimiento]

    public init(cuenta: String, asientos: [Asiento]) {
        self.cuenta = cuenta
        var saldo: Decimal = 0
        var lista: [Movimiento] = []
        for asiento in asientos {
            for (i, apunte) in asiento.apuntes.enumerated() where apunte.cuenta == cuenta {
                saldo += apunte.debe - apunte.haber
                var contrapartidas: [String] = []
                for otro in asiento.apuntes where otro.lado != apunte.lado && !contrapartidas.contains(otro.cuenta) {
                    contrapartidas.append(otro.cuenta)
                }
                lista.append(Movimiento(id: "\(asiento.id)-\(i)", numero: asiento.numero,
                                        fecha: asiento.fecha, concepto: asiento.concepto,
                                        detalle: apunte.detalle, debe: apunte.debe,
                                        haber: apunte.haber, saldo: saldo, contrapartidas: contrapartidas))
            }
        }
        movimientos = lista
    }

    public var sumaDebe: Decimal { movimientos.reduce(0) { $0 + $1.debe } }
    public var sumaHaber: Decimal { movimientos.reduce(0) { $0 + $1.haber } }
    public var saldo: Decimal { sumaDebe - sumaHaber }

    public var tipoSaldo: TipoSaldo {
        Mayor.tipo(de: saldo)
    }

    static func tipo(de saldo: Decimal) -> TipoSaldo {
        saldo > 0 ? .deudor : (saldo < 0 ? .acreedor : .saldado)
    }
}
