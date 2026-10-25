import XCTest
@testable import CuadernoCore

/// El formato de clase, tal como lo escribe Iulian en el iPad (foto del 25-10-2026):
///
///     Debe ____________ 01/12/24 ____________ Haber
///     1.000,00 Proveedores (400)    a    (572) Bancos 1.000,00
///
/// Las posiciones imitan las de la foto: x de 0 a 1 sobre el ancho del lienzo, y en puntos.
final class LectorAsientosTests: XCTestCase {
    /// Las palabras del ejemplo de la foto, con los títulos «Debe» y «Haber» incluidos.
    private let ejemploDeLaFoto: [PalabraLeida] = [
        PalabraLeida("Debe", x: 0.05, y: 470),
        PalabraLeida("01/12/24", x: 0.52, y: 480),
        PalabraLeida("Haber", x: 0.93, y: 450),
        PalabraLeida("1.000,00", x: 0.07, y: 600),
        PalabraLeida("Proveedores", x: 0.23, y: 600),
        PalabraLeida("(400)", x: 0.36, y: 595),
        PalabraLeida("a", x: 0.52, y: 605),
        PalabraLeida("(572)", x: 0.68, y: 580),
        PalabraLeida("Bancos", x: 0.79, y: 580),
        PalabraLeida("1.000,00", x: 0.95, y: 580),
    ]

    func testElEjemploDeLaFotoEsUnAsientoQueCuadra() throws {
        let leidos = LectorAsientos.leer(ejemploDeLaFoto)
        XCTAssertEqual(leidos.count, 1)
        let leido = try XCTUnwrap(leidos.first)
        XCTAssertEqual(leido.fecha, Fecha(año: 2024, mes: 12, dia: 1))
        XCTAssertEqual(leido.apuntes, [Apunte(.debe, "400", 1_000), Apunte(.haber, "572", 1_000)])
        XCTAssertEqual(leido.noEntendido, [])
        XCTAssertNoThrow(try leido.asiento(empresa: "X", numero: 1).get())
    }

    func testCadaFechaAbreUnAsientoNuevo() {
        let palabras = ejemploDeLaFoto + [
            PalabraLeida("02/12/24", x: 0.51, y: 985),
            PalabraLeida("600,00", x: 0.06, y: 1100),
            PalabraLeida("(600)", x: 0.37, y: 1100),
            PalabraLeida("126,00", x: 0.06, y: 1160),
            PalabraLeida("(472)", x: 0.37, y: 1160),
            PalabraLeida("a", x: 0.51, y: 1130),
            PalabraLeida("(400)", x: 0.66, y: 1130),
            PalabraLeida("726,00", x: 0.95, y: 1130),
        ]
        let leidos = LectorAsientos.leer(palabras)
        XCTAssertEqual(leidos.count, 2)
        XCTAssertEqual(leidos[1].fecha, Fecha(año: 2024, mes: 12, dia: 2))
        XCTAssertEqual(Set(leidos[1].apuntes), [Apunte(.debe, "600", 600), Apunte(.debe, "472", 126),
                                                Apunte(.haber, "400", 726)])
    }

    func testAsientoQueNoCuadraDiceLaDiferencia() {
        let palabras = [
            PalabraLeida("01/12/24", x: 0.5, y: 100),
            PalabraLeida("1.000,00", x: 0.07, y: 200),
            PalabraLeida("(400)", x: 0.36, y: 200),
            PalabraLeida("(572)", x: 0.68, y: 200),
            PalabraLeida("900,00", x: 0.95, y: 200),
        ]
        let resultado = LectorAsientos.leer(palabras)[0].asiento(empresa: "X", numero: 1)
        guard case .failure(let error) = resultado else { return XCTFail("No debería cuadrar") }
        XCTAssertEqual((error as? ErrorAsiento)?.diferencia, 100)
    }

    func testConfusionesDeLaLetraAMano() {
        // «(S72)» y «(4oo)»: la S es un 5 y las oes son ceros. La fecha viene troceada.
        let palabras = [
            PalabraLeida("01", x: 0.47, y: 100), PalabraLeida("/", x: 0.49, y: 100),
            PalabraLeida("12", x: 0.51, y: 100), PalabraLeida("/", x: 0.53, y: 100),
            PalabraLeida("24", x: 0.55, y: 100),
            PalabraLeida("1.0O0,00", x: 0.07, y: 200),
            PalabraLeida("(4oo)", x: 0.36, y: 200),
            PalabraLeida("(S72)", x: 0.68, y: 200),
            PalabraLeida("Bancos", x: 0.79, y: 200),
            PalabraLeida("1.000,", x: 0.92, y: 200), PalabraLeida("00", x: 0.97, y: 200),
        ]
        let leido = LectorAsientos.leer(palabras)[0]
        XCTAssertEqual(leido.fecha, Fecha(año: 2024, mes: 12, dia: 1))
        XCTAssertEqual(leido.apuntes, [Apunte(.debe, "400", 1_000), Apunte(.haber, "572", 1_000)])
    }

    func testFilaSinCodigoSeEnseñaComoNoEntendida() {
        let palabras = [
            PalabraLeida("01/12/24", x: 0.5, y: 100),
            PalabraLeida("1.000,00", x: 0.07, y: 200),
            PalabraLeida("Proveedores", x: 0.23, y: 200),
        ]
        let leido = LectorAsientos.leer(palabras)[0]
        XCTAssertEqual(leido.apuntes, [])
        XCTAssertEqual(leido.noEntendido, ["1.000,00 Proveedores"])
    }

    func testSubcuentaConPuntoYCodigoSinParentesisDeApertura() {
        XCTAssertEqual(LectorAsientos.apunte(en: "992,50 HP acreedora (4751.1)", lado: .haber),
                       Apunte(.haber, "4751.1", Decimal(string: "992.50")!))
        XCTAssertEqual(LectorAsientos.apunte(en: "1.210,00 Bancos 572)", lado: .debe),
                       Apunte(.debe, "572", 1_210))
        XCTAssertEqual(LectorAsientos.apunte(en: "1.210,00 Bancos 572", lado: .debe),
                       Apunte(.debe, "572", 1_210))
    }

    /// Captura del iPad (25-10-2026, 19:59): sin paréntesis ni fecha. Vision leyó bien las cifras;
    /// el código es el número pegado al centro y el importe, el del borde.
    func testSinParentesisElCodigoEsElNumeroPegadoAlCentro() throws {
        let palabras = [
            PalabraLeida("1000,00", x: 0.05, y: 260),
            PalabraLeida("572", x: 0.31, y: 255),
            PalabraLeida("430", x: 0.64, y: 245),
            PalabraLeida("1000", x: 0.93, y: 245),
        ]
        let leido = try XCTUnwrap(LectorAsientos.leer(palabras).first)
        XCTAssertEqual(leido.apuntes, [Apunte(.debe, "572", 1_000), Apunte(.haber, "430", 1_000)])
        XCTAssertEqual(leido.noEntendido, [])
        XCTAssertNoThrow(try leido.asiento(empresa: "X", numero: 1).get())
    }

    func testImporteTroceadoSinParentesis() {
        XCTAssertEqual(LectorAsientos.trozosNumericos("1.000, 00 Bancos 572"), ["1.000,00", "572"])
        XCTAssertEqual(LectorAsientos.apunte(en: "430 Clientes 1.210, 00", lado: .haber),
                       Apunte(.haber, "430", 1_210))
    }

    func testSinFechaTodaviaTambienSeLee() {
        let palabras = [PalabraLeida("50,00", x: 0.07, y: 200), PalabraLeida("(570)", x: 0.36, y: 200)]
        let leidos = LectorAsientos.leer(palabras)
        XCTAssertEqual(leidos.count, 1)
        XCTAssertNil(leidos[0].fecha)
        XCTAssertEqual(leidos[0].apuntes, [Apunte(.debe, "570", 50)])
    }
}
