import XCTest
@testable import CuadernoCore

final class ImporteTests: XCTestCase {
    func testCuotasDeIVAdelCasoTuria() {
        XCTAssertEqual(Importe.cuota(base: 4_850, tipo: 21), Decimal(string: "1018.50"))
        XCTAssertEqual(Importe.cuota(base: 20, tipo: 21), Decimal(string: "4.20"))
        XCTAssertEqual(Importe.cuota(base: 700, tipo: 19), 133)
    }

    /// Mitad hacia arriba: 0,50 × 21 % = 0,105 → 0,11. El redondeo «del banquero» daría 0,10.
    func testRedondeoMitadHaciaArriba() {
        XCTAssertEqual(Importe.cuota(base: Decimal(string: "0.50")!, tipo: 21), Decimal(string: "0.11"))
        XCTAssertEqual(Importe.redondear(Decimal(string: "2.345")!), Decimal(string: "2.35"))
    }

    /// Con Double, 0,1 + 0,2 = 0,30000000000000004. Con Decimal, 0,30 exacto.
    func testDecimalNoPierdeCentimos() {
        let suma = Decimal(string: "0.1")! + Decimal(string: "0.2")!
        XCTAssertEqual(suma, Decimal(string: "0.3"))
    }

    func testFormatoDelCuaderno() {
        XCTAssertEqual(Importe.formatear(Decimal(string: "1185.8")!), "1.185,80")
        XCTAssertEqual(Importe.formatear(1_000), "1.000")
        XCTAssertEqual(Importe.formatear(81_153), "81.153")
        XCTAssertEqual(Importe.formatear(Decimal(string: "-24.2")!), "-24,20")
        XCTAssertEqual(Importe.formatear(Decimal(string: "0.5")!), "0,50")
        XCTAssertEqual(Importe.formatear(1_234_567), "1.234.567")
    }

    func testLeerImportesEscritos() {
        XCTAssertEqual(Importe.leer("1.185,80"), Decimal(string: "1185.80"))
        XCTAssertEqual(Importe.leer("1.000"), 1_000)
        XCTAssertEqual(Importe.leer("81.153"), 81_153)
        XCTAssertEqual(Importe.leer("24,20"), Decimal(string: "24.20"))
        XCTAssertEqual(Importe.leer("12.5"), Decimal(string: "12.5"))
        XCTAssertEqual(Importe.leer("4.719 €"), 4_719)
        XCTAssertNil(Importe.leer("abc"))
        XCTAssertNil(Importe.leer(""))
    }

    /// Lo que no es un importe en euros se rechaza en vez de leerse mal sin avisar.
    func testImportesAmbiguosSeRechazan() {
        XCTAssertNil(Importe.leer("1,185.80"), "formato inglés")
        XCTAssertNil(Importe.leer("1,234"), "tres decimales")
        XCTAssertNil(Importe.leer("5-"), "signo fuera de sitio")
        XCTAssertNil(Importe.leer("1-2"), "signo fuera de sitio")
        XCTAssertEqual(Importe.leer("-24,20"), Decimal(string: "-24.20"))
    }

    func testFechas() {
        XCTAssertEqual(Fecha(texto: "31/03/2025"), Fecha(año: 2025, mes: 3, dia: 31))
        XCTAssertEqual(Fecha(texto: "2025-03-31")?.description, "31/03/2025")
        XCTAssertNil(Fecha(año: 2025, mes: 2, dia: 29))
        XCTAssertNotNil(Fecha(año: 2024, mes: 2, dia: 29))
        XCTAssertTrue(Fecha(año: 2025, mes: 1, dia: 31)! < Fecha(año: 2025, mes: 2, dia: 1)!)
    }
}

final class MapeoKPITests: XCTestCase {
    let ebitda = MapeoKPI.ebitda

    func testQueCuentasEntranEnElEBITDA() {
        for cuenta in ["600", "621", "631", "640", "649", "700", "708", "740", "759"] {
            XCTAssertTrue(ebitda.entra(cuenta), "\(cuenta) debería entrar")
        }
        // 630 impuesto sobre beneficios, 665/769 financieros, 681 amortización, balance.
        for cuenta in ["630", "665", "769", "681", "472", "4751.1", "410", "572"] {
            XCTAssertFalse(ebitda.entra(cuenta), "\(cuenta) no debería entrar")
        }
    }

    func testIVAyRetencionesNoMuevenElEBITDA() throws {
        // Factura del alquiler de Túria (asiento 39): solo los 700 de la 621 restan.
        let alquiler = try Asiento(empresa: "X", fecha: Fecha(año: 2025, mes: 3, dia: 12)!, concepto: "Alquiler",
                                   apuntes: [Apunte(.debe, "621", 700), Apunte(.debe, "472", 147),
                                             Apunte(.haber, "4751.3", 133), Apunte(.haber, "410", 714)])
        XCTAssertEqual(ebitda.impacto(de: alquiler), -700)
    }

    func testIngresoSumaYGastoResta() throws {
        let venta = try Asiento(empresa: "X", fecha: Fecha(año: 2025, mes: 1, dia: 1)!, concepto: "Venta",
                                apuntes: [Apunte(.debe, "430", 1_210), Apunte(.haber, "700", 1_000),
                                          Apunte(.haber, "477", 210)])
        XCTAssertEqual(ebitda.impacto(de: venta), 1_000)
    }
}
