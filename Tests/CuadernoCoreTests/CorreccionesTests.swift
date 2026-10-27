import XCTest
@testable import CuadernoCore

/// Fechas escritas de cualquier forma (siempre día, mes, año) y apuntes corregidos a mano.
final class CorreccionesTests: XCTestCase {
    private func fecha(_ dia: Int, _ mes: Int, _ año: Int) -> Fecha { Fecha(año: año, mes: mes, dia: dia)! }

    // MARK: - Fechas

    func testFechaConUnaODosCifras() {
        XCTAssertEqual(FechaEscrita.leer("10/01/25"), fecha(10, 1, 2025))
        XCTAssertEqual(FechaEscrita.leer("10/1/25"), fecha(10, 1, 2025))
        XCTAssertEqual(FechaEscrita.leer("10-1-25"), fecha(10, 1, 2025))
        XCTAssertEqual(FechaEscrita.leer("1.1.2025"), fecha(1, 1, 2025))
        XCTAssertEqual(FechaEscrita.leer("10 1 25"), fecha(10, 1, 2025))
        XCTAssertEqual(FechaEscrita.leer("10 / 01 / 2025"), fecha(10, 1, 2025))
    }

    /// Captura del iPad (25-10-2026, 21:18): «01/10/25» llegó como «01/10125».
    func testUnaBarraLeidaComoUno() {
        XCTAssertEqual(FechaEscrita.leer("01/10125"), fecha(1, 10, 2025))
        XCTAssertEqual(FechaEscrita.leer("10/1125"), fecha(10, 1, 2025), "10/1/25 con la segunda barra como un 1")
        XCTAssertEqual(FechaEscrita.leer("111125"), fecha(1, 1, 2025), "1/1/25 con las dos barras como unos")
        XCTAssertEqual(FechaEscrita.leer("10/01725"), fecha(10, 1, 2025), "una barra leída como un 7")
        let palabras = [PalabraLeida("01/10125", x: 0.5, y: 100),
                        PalabraLeida("1000", x: 0.05, y: 200), PalabraLeida("407", x: 0.35, y: 200)]
        XCTAssertEqual(LectorAsientos.leer(palabras).first?.fecha, fecha(1, 10, 2025))
    }

    func testLoQueNoEsFechaNoSeAdivina() {
        XCTAssertNil(FechaEscrita.leer("1.000,00"))
        XCTAssertNil(FechaEscrita.leer("(472)"))
        XCTAssertNil(FechaEscrita.leer("32/01/25"), "no hay día 32")
        XCTAssertNil(FechaEscrita.leer("10/13/25"), "siempre día y después mes: no hay mes 13")
    }

    // MARK: - Correcciones a mano

    private let leido = AsientoLeido(apuntes: [Apunte(.debe, "407", 1_000), Apunte(.haber, "400", 1_210)],
                                     noEntendido: ["0,00 HJA oportado (472)"],
                                     pistas: ["Para que cuadre, la 472 tendría que llevar 210,00."])

    private func datos() -> DatosHoja {
        DatosHoja(esApertura: false, fechaInicial: fecha(10, 1, 2025))
    }

    func testFilaSinEntenderCorregidaCuadraElAsiento() throws {
        var datos = datos()
        datos.corregir(asiento: 0, leido: .fila("0,00 HJA oportado (472)"), por: Apunte(.debe, "472", 210))
        let resuelto = try XCTUnwrap(datos.resolver([leido], empresa: "X").first)
        XCTAssertEqual(resuelto.leido.apuntes, [Apunte(.debe, "407", 1_000), Apunte(.debe, "472", 210),
                                                Apunte(.haber, "400", 1_210)])
        XCTAssertEqual(resuelto.lineas.map(\.corregida), [false, true, false])
        XCTAssertNotNil(resuelto.asiento)
        XCTAssertEqual(resuelto.sugerencias, [], "ya no queda nada por entender ni pistas viejas")
    }

    func testCorregirUnImporteLeidoYVolverALoLeido() throws {
        var datos = datos()
        let leidoMal = Correccion.Leido.apunte(Apunte(.haber, "400", 1_210))
        datos.corregir(asiento: 0, leido: leidoMal, por: Apunte(.haber, "400", 1_000))
        XCTAssertEqual(datos.resolver([leido], empresa: "X")[0].leido.apuntes.last, Apunte(.haber, "400", 1_000))
        datos.corregir(asiento: 0, leido: leidoMal, por: Apunte(.haber, "400", 1_100))
        XCTAssertEqual(datos.correcciones.count, 1, "corregir otra vez lo mismo sustituye")
        datos.quitarCorreccion(asiento: 0, leido: leidoMal)
        XCTAssertEqual(datos.resolver([leido], empresa: "X")[0].leido.apuntes.last, Apunte(.haber, "400", 1_210))
    }

    func testDescartarYRecuperar() {
        var datos = datos()
        datos.corregir(asiento: 0, leido: .fila("0,00 HJA oportado (472)"), por: nil)
        let resuelto = datos.resolver([leido], empresa: "X")[0]
        XCTAssertEqual(resuelto.leido.noEntendido, [])
        XCTAssertEqual(resuelto.descartadas, 1)
        datos.recuperarDescartadas(asiento: 0)
        XCTAssertEqual(datos.resolver([leido], empresa: "X")[0].leido.noEntendido, ["0,00 HJA oportado (472)"])
    }

    func testSiLaTintaSeLeeDistintoLaCorreccionNoSeAplica() {
        var datos = datos()
        datos.corregir(asiento: 0, leido: .apunte(Apunte(.haber, "400", 1_210)), por: Apunte(.haber, "400", 1_000))
        XCTAssertEqual(datos.resolver([leido], empresa: "X")[0].lineas.filter(\.corregida).count, 1)
        let reescrito = AsientoLeido(apuntes: [Apunte(.debe, "407", 1_000), Apunte(.haber, "400", 1_000)])
        XCTAssertEqual(datos.resolver([reescrito], empresa: "X")[0].lineas.filter(\.corregida).count, 0)
        XCTAssertEqual(datos.resolver([AsientoLeido(), leido], empresa: "X")[1].lineas.filter(\.corregida).count, 0,
                       "la corrección es del asiento 1, no del 2")
    }

    func testHojasViejasSinCorreccionesSeSiguenAbriendo() throws {
        let viejo = #"{"esApertura":false,"fechaInicial":"2025-01-10","fechasManuales":{},"zonas":{"finDebe":0.42,"inicioHaber":0.58}}"#
        let datos = try JSONDecoder().decode(DatosHoja.self, from: Data(viejo.utf8))
        XCTAssertEqual(datos.correcciones, [])
        var nuevo = datos
        nuevo.corregir(asiento: 0, leido: .fila("x 472"), por: Apunte(.debe, "472", 210))
        XCTAssertEqual(try JSONDecoder().decode(DatosHoja.self, from: JSONEncoder().encode(nuevo)), nuevo)
    }

    // MARK: - Arrastrar apuntes entre asientos

    private let conDeMas = AsientoLeido(apuntes: [Apunte(.debe, "600", 1_000), Apunte(.haber, "400", 1_000),
                                                  Apunte(.haber, "407", 500)])
    private let alQueLeFalta = AsientoLeido(apuntes: [Apunte(.debe, "572", 500)])

    func testArrastrarUnApunteAOtroAsiento() throws {
        var datos = datos()
        let anticipo = Correccion.Leido.apunte(Apunte(.haber, "407", 500))
        datos.mover(asiento: 0, leido: anticipo, apunte: Apunte(.haber, "407", 500), a: 1)
        var resueltos = datos.resolver([conDeMas, alQueLeFalta], empresa: "X")
        XCTAssertEqual(resueltos[0].leido.apuntes, [Apunte(.debe, "600", 1_000), Apunte(.haber, "400", 1_000)])
        XCTAssertEqual(resueltos[1].leido.apuntes, [Apunte(.debe, "572", 500), Apunte(.haber, "407", 500)])
        XCTAssertNotNil(resueltos[0].asiento)
        XCTAssertNotNil(resueltos[1].asiento)
        XCTAssertEqual(resueltos[1].lineas.last?.origen, 0, "la corrección sigue guardada en el asiento donde se leyó")

        // Corregir el apunte ya movido no lo devuelve a su sitio.
        datos.corregir(asiento: 0, leido: anticipo, por: Apunte(.haber, "407", 600))
        resueltos = datos.resolver([conDeMas, alQueLeFalta], empresa: "X")
        XCTAssertEqual(resueltos[1].leido.apuntes.last, Apunte(.haber, "407", 600))

        // Volver a lo leído lo devuelve al asiento de la tinta.
        datos.quitarCorreccion(asiento: 0, leido: anticipo)
        resueltos = datos.resolver([conDeMas, alQueLeFalta], empresa: "X")
        XCTAssertEqual(resueltos[0].leido.apuntes.count, 3)
        XCTAssertEqual(resueltos[1].leido.apuntes, [Apunte(.debe, "572", 500)])
    }

    func testArrastrarAlOtroLadoDelMismoAsiento() {
        var datos = datos()
        let anticipo = Correccion.Leido.apunte(Apunte(.haber, "407", 500))
        datos.mover(asiento: 0, leido: anticipo, apunte: Apunte(.debe, "407", 500), a: 0)
        XCTAssertNil(datos.correcciones.first?.destino)
        XCTAssertEqual(datos.resolver([conDeMas], empresa: "X")[0].leido.apuntes.filter { $0.lado == .debe },
                       [Apunte(.debe, "600", 1_000), Apunte(.debe, "407", 500)])
    }

    func testSiElAsientoDestinoDesapareceElApunteVuelveASuAsiento() {
        var datos = datos()
        let anticipo = Correccion.Leido.apunte(Apunte(.haber, "407", 500))
        datos.mover(asiento: 0, leido: anticipo, apunte: Apunte(.haber, "407", 500), a: 1)
        XCTAssertEqual(datos.resolver([conDeMas], empresa: "X")[0].leido.apuntes.count, 3)
    }

    // MARK: - Cuadro de cuentas

    func testCuadroDeCuentas() {
        XCTAssertEqual(PlanDeCuentas.nombre(de: "572"), "Bancos", "mandan los nombres de clase")
        XCTAssertEqual(PlanDeCuentas.nombre(de: "625"), "Primas de seguros")
        XCTAssertEqual(PlanDeCuentas.nombre(de: "2818"), "Amortización acumulada de elementos de transporte")
        let codigos = PlanDeCuentas.todas.map { $0.codigo }
        XCTAssertEqual(codigos, codigos.sorted())
        XCTAssertEqual(Set(codigos).count, codigos.count)
        XCTAssertTrue(PlanDeCuentas.buscar("mercaderias").map { $0.codigo }.contains("600"), "sin tildes")
        XCTAssertEqual(PlanDeCuentas.buscar("477").map { $0.codigo }, ["477"])
    }
}
