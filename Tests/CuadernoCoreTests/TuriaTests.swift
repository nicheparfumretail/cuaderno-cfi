import XCTest
@testable import CuadernoCore

/// El caso Túria del curso, de punta a punta. Las cifras esperadas salen de la
/// «Comprobación final» de la nota del caso, no de la app.
final class TuriaTests: XCTestCase {
    let diario = CasoTuria.diario()

    func testAsientoDeAperturaCuadra() throws {
        let apertura = try XCTUnwrap(diario.asientos.first)
        XCTAssertEqual(apertura.numero, 1)
        XCTAssertEqual(apertura.concepto, "Apertura")
        XCTAssertEqual(apertura.fecha, Fecha(año: 2025, mes: 1, dia: 1))
        XCTAssertEqual(apertura.apuntes.count, 11)
        XCTAssertEqual(apertura.sumaDebe, 88_050)
        XCTAssertEqual(apertura.sumaHaber, 88_050)
        XCTAssertEqual(Mayor(cuenta: "100", asientos: [apertura]).saldo, -81_153)
    }

    func testLosSesentaYTresAsientosCuadran() {
        XCTAssertEqual(diario.asientos.count, 63)
        XCTAssertEqual(diario.asientos.map(\.numero), Array(1...63))
        for asiento in diario.asientos {
            XCTAssertEqual(asiento.sumaDebe, asiento.sumaHaber, "Asiento \(asiento.numero)")
        }
    }

    func testCuentasPuenteQuedanACero() {
        let puente = ["400", "401", "406", "407", "410", "430", "4310", "4311", "4312",
                      "437", "438", "440", "460", "465", "471", "476", "4708", "5208"]
        for cuenta in puente {
            let mayor = Mayor(cuenta: cuenta, asientos: diario.asientos)
            XCTAssertEqual(mayor.saldo, 0, "La \(cuenta) debería quedar saldada")
            XCTAssertEqual(mayor.tipoSaldo, .saldado)
        }
    }

    func testSaldosFinalesDelTrimestre() {
        let esperados: [(String, String, TipoSaldo)] = [
            ("572", "36775.20", .deudor),
            ("570", "612", .deudor),
            ("4315", "8591", .deudor),
            ("473", "117.80", .deudor),
            ("4751.1", "992.50", .acreedor),
            ("4751.3", "133", .acreedor),
        ]
        for (cuenta, importe, tipo) in esperados {
            let mayor = Mayor(cuenta: cuenta, asientos: diario.asientos)
            let saldo = mayor.saldo < 0 ? -mayor.saldo : mayor.saldo
            XCTAssertEqual(saldo, Decimal(string: importe), "Saldo de la \(cuenta)")
            XCTAssertEqual(mayor.tipoSaldo, tipo, "Tipo de saldo de la \(cuenta)")
        }
    }

    func testMayorDeEfectosImpagadosAcumulaNordYBosc() {
        let mayor = Mayor(cuenta: "4315", asientos: diario.asientos)
        XCTAssertEqual(mayor.movimientos.map(\.detalle), ["Nord", "Bosc"])
        XCTAssertEqual(mayor.movimientos.map(\.saldo), [3_630, 8_591])
    }

    func testBalanceDeComprobacionCuadra() {
        let balance = BalanceComprobacion(asientos: diario.asientos)
        XCTAssertTrue(balance.cuadra)
        XCTAssertEqual(balance.totalSumaDebe, balance.totalSumaHaber)
        XCTAssertEqual(balance.totalSaldoDeudor, balance.totalSaldoAcreedor)
    }

    func testDiarioSobreviveAlJSONSinPerderCentimos() throws {
        let copia = try Diario.desdeJSON(try diario.json())
        XCTAssertEqual(copia, diario)
        let pagoMestral = try XCTUnwrap(copia.asientos.first { $0.numero == 15 })
        XCTAssertEqual(pagoMestral.sumaDebe, Decimal(string: "1185.80"))
    }
}
