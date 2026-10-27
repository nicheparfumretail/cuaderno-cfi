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

    /// Captura del iPad (25-10-2026, 20:33), asiento 2 de Túria: «Compras / mercaderías» en dos
    /// renglones, con la (600) en el de arriba y el 4.900,00 en el de abajo.
    func testNombreEnDosRenglonesEsUnSoloApunte() throws {
        let palabras = [
            PalabraLeida("20-01-25", x: 0.49, y: 705),
            PalabraLeida("compros", x: 0.22, y: 700), PalabraLeida("(600)", x: 0.37, y: 705),
            PalabraLeida("4.900,00", x: 0.08, y: 735), PalabraLeida("merraderics", x: 0.25, y: 735),
            PalabraLeida("819,00", x: 0.08, y: 805), PalabraLeida("HP", x: 0.2, y: 800),
            PalabraLeida("IVA", x: 0.25, y: 800), PalabraLeida("(472)", x: 0.38, y: 805),
            PalabraLeida("soportado", x: 0.26, y: 835),
            PalabraLeida("(407)", x: 0.61, y: 700), PalabraLeida("Anticipos", x: 0.75, y: 695),
            PalabraLeida("1.000,00", x: 0.93, y: 700), PalabraLeida("proveedores", x: 0.79, y: 725),
            PalabraLeida("(400)", x: 0.62, y: 805), PalabraLeida("Proveedores", x: 0.78, y: 800),
            PalabraLeida("4.719,00", x: 0.93, y: 785),
        ]
        let leidos = LectorAsientos.leer(palabras, separadores: [670, 930])
        XCTAssertEqual(leidos.count, 1)
        let leido = try XCTUnwrap(leidos.first)
        XCTAssertEqual(leido.fecha, Fecha(año: 2025, mes: 1, dia: 20))
        XCTAssertEqual(Set(leido.apuntes), [Apunte(.debe, "600", 4_900), Apunte(.debe, "472", 819),
                                            Apunte(.haber, "407", 1_000), Apunte(.haber, "400", 4_719)])
        XCTAssertEqual(leido.noEntendido, [])
        XCTAssertNoThrow(try leido.asiento(empresa: "X", numero: 2).get())
    }

    func testRenglonesSeparadosPorUnaRayaNoSeUnen() {
        let palabras = [PalabraLeida("(600)", x: 0.37, y: 100), PalabraLeida("4.900,00", x: 0.08, y: 130)]
        let leidos = LectorAsientos.leer(palabras, separadores: [115])
        XCTAssertEqual(leidos.flatMap(\.apuntes), [])
        XCTAssertEqual(leidos.count, 2)
    }

    /// Vision lee la barra «/» de la fecha escrita a mano como un 1.
    func testFechaConBarrasLeidasComoUnos() {
        XCTAssertEqual(FechaEscrita.leer("10101125"), Fecha(año: 2025, mes: 1, dia: 10))
        XCTAssertEqual(FechaEscrita.leer("2511012025"), Fecha(año: 2025, mes: 10, dia: 25))
        XCTAssertNil(FechaEscrita.leer("12345678"))
        let palabras = [PalabraLeida("10l01l25", x: 0.5, y: 100),
                        PalabraLeida("1000", x: 0.05, y: 200), PalabraLeida("572", x: 0.35, y: 200),
                        PalabraLeida("430", x: 0.65, y: 200), PalabraLeida("1000", x: 0.95, y: 200)]
        XCTAssertEqual(LectorAsientos.leer(palabras).first?.fecha, Fecha(año: 2025, mes: 1, dia: 10))
    }

    func testLoQueNoEsFechaEnElCentroSeRecomiendaElegirla() throws {
        let palabras = [PalabraLeida("1O?2", x: 0.5, y: 100),
                        PalabraLeida("1000", x: 0.05, y: 200), PalabraLeida("572", x: 0.35, y: 200)]
        let leido = try XCTUnwrap(LectorAsientos.leer(palabras).first)
        XCTAssertNil(leido.fecha)
        XCTAssertEqual(leido.fechaIlegible, ["1O?2"])
        XCTAssertTrue(DatosHoja.sugerencias(leido).contains(
            "En el centro leo «1O?2» y no es una fecha: elígela con el selector de fecha."))
    }

    func testHojasGuardadasAntesSeSiguenLeyendo() throws {
        let viejo = #"{"apuntes":[{"lado":"debe","cuenta":"572","importe":"10"}],"noEntendido":[]}"#
        let leido = try JSONDecoder().decode(AsientoLeido.self, from: Data(viejo.utf8))
        XCTAssertEqual(leido.apuntes, [Apunte(.debe, "572", 10)])
        XCTAssertEqual(leido.fechaIlegible, [])
    }
}
