import XCTest
@testable import CuadernoCore

/// La corrección del modo práctica y el mayor con sus contrapartidas.
final class RevisionTests: XCTestCase {
    private func resolver(_ apuntes: [Apunte]) -> AsientoResuelto {
        let datos = DatosHoja(esApertura: false, fechaInicial: Fecha(año: 2025, mes: 1, dia: 20)!)
        return datos.resolver([AsientoLeido(apuntes: apuntes)], empresa: "X")[0]
    }

    func testUnAsientoQueCuadraConCuentasDelPGCNoTieneNadaQueRevisar() {
        let resuelto = resolver([Apunte(.debe, "600", 4_900), Apunte(.debe, "472", 819),
                                 Apunte(.haber, "407", 1_000), Apunte(.haber, "400", 4_719)])
        XCTAssertEqual(resuelto.revision, [])
    }

    func testCuentaQueNoExisteEnElPGC() {
        let resuelto = resolver([Apunte(.debe, "488", 100), Apunte(.haber, "5720", 100)])
        XCTAssertEqual(resuelto.cuentasFueraDelPGC, ["488"], "la 5720 es una subcuenta de la 572")
        XCTAssertEqual(resuelto.revision, ["La 488 no está en el cuadro de cuentas del PGC: revisa el número."])
    }

    func testLoQueNoCuadraSaleEnLaRevision() {
        let resuelto = resolver([Apunte(.debe, "600", 1_000), Apunte(.haber, "400", 900)])
        XCTAssertTrue(resuelto.revision.first?.hasPrefix("No cuadra") ?? false, "\(resuelto.revision)")
    }

    func testElMayorDiceLasContrapartidas() throws {
        let asiento = try Asiento(empresa: "X", numero: 2, fecha: Fecha(año: 2025, mes: 1, dia: 20)!, concepto: "",
                                  apuntes: [Apunte(.debe, "600", 4_900), Apunte(.debe, "472", 819),
                                            Apunte(.haber, "407", 1_000), Apunte(.haber, "400", 4_719)])
        let mayor = Mayor(cuenta: "400", asientos: [asiento])
        XCTAssertEqual(mayor.movimientos.map(\.contrapartidas), [["600", "472"]])
        XCTAssertEqual(mayor.movimientos.map(\.numero), [2])
    }
}
