import XCTest
@testable import CuadernoCore

final class AsientoTests: XCTestCase {
    let fecha = Fecha(año: 2025, mes: 3, dia: 31)!

    private func asiento(_ apuntes: [Apunte]) throws -> Asiento {
        try Asiento(empresa: "Prueba", fecha: fecha, concepto: "Prueba", apuntes: apuntes)
    }

    func testAsientoQueCuadraSeAcepta() throws {
        let a = try asiento([Apunte(.debe, "572", 1_000), Apunte(.haber, "700", 1_000)])
        XCTAssertEqual(a.sumaDebe, a.sumaHaber)
    }

    func testAsientoDescuadradoSeRechazaConLaDiferencia() {
        XCTAssertThrowsError(try asiento([Apunte(.debe, "572", 1_000), Apunte(.haber, "700", 900)])) { error in
            let e = error as? ErrorAsiento
            XCTAssertEqual(e, .descuadre(debe: 1_000, haber: 900))
            XCTAssertEqual(e?.diferencia, 100)
            XCTAssertEqual(e?.errorDescription,
                           "No cuadra: el Debe suma 1.000 y el Haber 900. Faltan 100 en el Haber.")
        }
    }

    func testDescuadrePorCentimos() {
        let debe = Decimal(string: "24.20")!
        let haber = Decimal(string: "24.02")!
        XCTAssertThrowsError(try asiento([Apunte(.debe, "400", debe), Apunte(.haber, "606", haber)])) { error in
            XCTAssertEqual((error as? ErrorAsiento)?.diferencia, Decimal(string: "0.18"))
        }
    }

    func testImporteCeroONegativoSeRechaza() {
        XCTAssertThrowsError(try asiento([Apunte(.debe, "572", 0), Apunte(.haber, "700", 0)]))
        XCTAssertThrowsError(try asiento([Apunte(.debe, "572", -50), Apunte(.debe, "700", 50)])) { error in
            XCTAssertEqual(error as? ErrorAsiento, .importeNoPositivo(cuenta: "572"))
        }
    }

    func testCuentaNoValidaSeRechaza() {
        for codigo in ["", "57", "abc", "072", "4751.", "57a2"] {
            XCTAssertThrowsError(try asiento([Apunte(.debe, codigo, 10), Apunte(.haber, "700", 10)]),
                                 "«\(codigo)» no debería aceptarse")
        }
    }

    func testAsientoSinApuntesSeRechaza() {
        XCTAssertThrowsError(try asiento([])) { error in
            XCTAssertEqual(error as? ErrorAsiento, .sinApuntes)
        }
    }

    func testCuentaDeduceGrupoYNombre() throws {
        let bancos = try XCTUnwrap(Cuenta("572"))
        XCTAssertEqual(bancos.grupo, 5)
        XCTAssertEqual(bancos.subgrupo, "57")
        XCTAssertEqual(bancos.description, "(572) Bancos")
        XCTAssertEqual(Cuenta("4751.1")?.grupo, 4)
        XCTAssertTrue(Cuenta("430")! < Cuenta("4310")!)
        XCTAssertTrue(Cuenta("4310")! < Cuenta("437")!)
    }

    func testDiarioNumeraYNoRepite() throws {
        var diario = Diario()
        let primero = try diario.añadir(try asiento([Apunte(.debe, "572", 10), Apunte(.haber, "700", 10)]))
        let segundo = try diario.añadir(try asiento([Apunte(.debe, "572", 20), Apunte(.haber, "700", 20)]))
        XCTAssertEqual([primero.numero, segundo.numero], [1, 2])

        var repetido = try asiento([Apunte(.debe, "572", 5), Apunte(.haber, "700", 5)])
        repetido.numero = 2
        XCTAssertThrowsError(try diario.añadir(repetido))
    }

    func testJSONConAsientoDescuadradoNoSeCarga() {
        let json = """
        {"version":1,"asientos":[{"id":"6F1C2E3A-0000-4000-8000-000000000001","empresa":"X",
        "numero":1,"fecha":"2025-01-01","concepto":"Malo","apuntes":[
        {"lado":"debe","cuenta":"572","importe":"100"},{"lado":"haber","cuenta":"700","importe":"99.99"}]}]}
        """
        XCTAssertThrowsError(try Diario.desdeJSON(Data(json.utf8)))
    }
}
