import XCTest
@testable import CuadernoCore

/// Lo que hace robusta la lectura: renglones decididos por la tinta, varias lecturas por renglón
/// y la partida doble como prueba para elegir entre ellas.
final class ReconocimientoTests: XCTestCase {
    // MARK: - Captura del iPad (25-10-2026, 20:49)

    /// Asiento 2 de Túria. Vision leyó «814,00» donde pone 819,00: faltaban 5 en el Debe.
    private func asientoDos(_ ivaLeido: PalabraLeida) -> [PalabraLeida] {
        [
            PalabraLeida("20-01-25", x: 0.49, y: 705),
            PalabraLeida("4.900,00", x: 0.08, y: 735), PalabraLeida("(600)", x: 0.37, y: 735),
            ivaLeido, PalabraLeida("(472)", x: 0.38, y: 805),
            PalabraLeida("(407)", x: 0.61, y: 700), PalabraLeida("1.000,00", x: 0.93, y: 700),
            PalabraLeida("(400)", x: 0.62, y: 785), PalabraLeida("4.719,00", x: 0.93, y: 785),
        ]
    }

    func testSiVisionDudoSeTomaLaLecturaQueCuadra() throws {
        let iva = PalabraLeida("814,00", x: 0.08, y: 805, alternativas: ["874,00", "819,00"])
        let leido = try XCTUnwrap(LectorAsientos.leer(asientoDos(iva)).first)
        XCTAssertEqual(Set(leido.apuntes), [Apunte(.debe, "600", 4_900), Apunte(.debe, "472", 819),
                                            Apunte(.haber, "407", 1_000), Apunte(.haber, "400", 4_719)])
        XCTAssertNoThrow(try leido.asiento(empresa: "X", numero: 2).get())
        XCTAssertEqual(leido.pistas, ["En la 472 dudaba entre 814 y 819: tomo 819, que es lo que hace "
                                      + "cuadrar el asiento. Compruébalo."])
    }

    func testUnaCifraParecidaSoloSePregunta() throws {
        let iva = PalabraLeida("814,00", x: 0.08, y: 805)
        let leido = try XCTUnwrap(LectorAsientos.leer(asientoDos(iva)).first)
        XCTAssertTrue(leido.apuntes.contains(Apunte(.debe, "472", 814)), "sin dudas de Vision no se cambia nada")
        XCTAssertEqual(Set(leido.pistas), [
            "¿En la 472 pone 819 y no 814? Con 819 cuadra.",
            "¿En la 400 pone 4.714 y no 4.719? Con 4.714 cuadra.",
        ])
    }

    /// Asiento 1: «210,00 HP. IVA soportado (472)» llegó como «0,00 HJA oportado (472)».
    private func asientoUno(_ ivaLeido: PalabraLeida) -> [PalabraLeida] {
        [
            PalabraLeida("10/01/25", x: 0.5, y: 80),
            PalabraLeida("1.000,00", x: 0.08, y: 130), PalabraLeida("(407)", x: 0.37, y: 130),
            ivaLeido, PalabraLeida("HJA", x: 0.2, y: 190), PalabraLeida("oportado", x: 0.28, y: 190),
            PalabraLeida("(472)", x: 0.38, y: 190),
            PalabraLeida("(400)", x: 0.62, y: 160), PalabraLeida("1.210,00", x: 0.93, y: 160),
        ]
    }

    func testCuentaSinImporteDiceCuantoFalta() throws {
        let leido = try XCTUnwrap(LectorAsientos.leer(asientoUno(PalabraLeida("0,00", x: 0.08, y: 190))).first)
        XCTAssertEqual(leido.apuntes, [Apunte(.debe, "407", 1_000), Apunte(.haber, "400", 1_210)])
        XCTAssertEqual(leido.noEntendido, ["0,00 HJA oportado (472)"])
        XCTAssertEqual(DatosHoja.sugerencias(leido), [
            "En «0,00 HJA oportado (472)» leo la cuenta 472 pero no un importe: repasa las cifras del borde.",
            "Para que cuadre, la 472 tendría que llevar 210.",
        ])
    }

    func testOtraLecturaDelRenglonRecuperaLaCifraPerdida() throws {
        let iva = PalabraLeida("0,00", x: 0.08, y: 190, alternativas: ["210,00"])
        let leido = try XCTUnwrap(LectorAsientos.leer(asientoUno(iva)).first)
        XCTAssertEqual(leido.apuntes, [Apunte(.debe, "407", 1_000), Apunte(.debe, "472", 210),
                                       Apunte(.haber, "400", 1_210)])
        XCTAssertEqual(DatosHoja.sugerencias(leido), [])
    }

    func testCifrasQueSeConfunden() {
        XCTAssertTrue(LectorAsientos.seConfunden(814, 819))
        XCTAssertTrue(LectorAsientos.seConfunden(1_000, 7_000))
        XCTAssertTrue(LectorAsientos.seConfunden(10, 210), "una cifra que no se leyó")
        XCTAssertFalse(LectorAsientos.seConfunden(4_900, 4_905), "0 y 5 no se parecen")
        XCTAssertFalse(LectorAsientos.seConfunden(123, 456))
    }

    func testElRenglonDeTintaMandaSobreLaAltura() {
        // Dos renglones muy juntos: por la altura serían uno; por la tinta son dos apuntes.
        let palabras = [
            PalabraLeida("1.000,00 (572)", x: 0.2, y: 100, renglon: 1),
            PalabraLeida("200,00 (472)", x: 0.2, y: 112, renglon: 2),
            PalabraLeida("(430) 1.200,00", x: 0.8, y: 106, renglon: 3),
        ]
        XCTAssertEqual(LectorAsientos.leer(palabras).first?.apuntes,
                       [Apunte(.debe, "572", 1_000), Apunte(.debe, "472", 200), Apunte(.haber, "430", 1_200)])
    }

    // MARK: - Renglones a partir de los trazos

    private func trazo(_ x: Double, _ y: Double, ancho: Double = 20, alto: Double = 30) -> CajaTrazo {
        CajaTrazo(minX: x, minY: y - alto / 2, maxX: x + ancho, maxY: y + alto / 2)
    }

    func testTrazosEnRenglonesPorFranja() {
        let fecha = stride(from: 470.0, to: 540, by: 22).map { trazo($0, 60) }
        let debe1 = stride(from: 40.0, to: 340, by: 30).map { trazo($0, 100) } + [trazo(150, 118, ancho: 4, alto: 8)]
        let haber = stride(from: 620.0, to: 950, by: 30).map { trazo($0, 125) }
        let debe2 = stride(from: 40.0, to: 340, by: 30).map { trazo($0, 150) }
        let renglones = AgrupadorTrazos.renglones(fecha + debe1 + haber + debe2, anchoPagina: 1000, zonas: Zonas())

        XCTAssertEqual(renglones.map(\.zona), [.centro, .debe, .haber, .debe])
        XCTAssertEqual(renglones.map(\.indices.count), [fecha.count, debe1.count, haber.count, debe2.count],
                       "la coma va con su renglón")
        XCTAssertEqual(renglones[1].y, 100, accuracy: 0.001, "la coma no mueve la altura del renglón")
        XCTAssertTrue(renglones.allSatisfy { Zonas().zona(de: $0.x) == $0.zona })
    }

    func testRenglonTorcidoSigueSiendoUno() {
        // Cada trazo baja 4 puntos: de punta a punta, 40, más que la altura de una cifra.
        let torcido = (0..<11).map { trazo(40 + Double($0) * 30, 100 + Double($0) * 4) }
        let debajo = (0..<11).map { trazo(40 + Double($0) * 30, 160 + Double($0) * 4) }
        let renglones = AgrupadorTrazos.renglones(torcido + debajo, anchoPagina: 1000, zonas: Zonas())
        XCTAssertEqual(renglones.map(\.indices.count), [11, 11])
    }

    func testElPuntoDeUnaIVaConSuRenglon() {
        let renglon = stride(from: 40.0, to: 340, by: 30).map { trazo($0, 100) }
        let punto = trazo(100, 72, ancho: 4, alto: 4)
        let renglones = AgrupadorTrazos.renglones(renglon + [punto], anchoPagina: 1000, zonas: Zonas())
        XCTAssertEqual(renglones.count, 1)
        XCTAssertEqual(renglones[0].indices.count, renglon.count + 1)
    }

    /// Captura del iPad (25-10-2026, 22:48): «819 … (472)» se leyó «89». Con el hueco del nombre
    /// en medio, cada trozo se lee aparte.
    func testRenglonSeParteEnTrozosPorLosHuecos() {
        let cifras = [40.0, 62, 84].map { trazo($0, 100) }
        let codigo = stride(from: 300.0, to: 400, by: 22).map { trazo($0, 100) }
        let renglones = AgrupadorTrazos.renglones(cifras + codigo, anchoPagina: 1000, zonas: Zonas())
        XCTAssertEqual(renglones.count, 1)
        XCTAssertEqual(renglones[0].trozos.map(\.count), [cifras.count, codigo.count])
    }

    // MARK: - El nombre escrito confirma la cuenta

    /// Captura del iPad (25-10-2026, 22:48): «(600)» se leyó «(608)», pero al lado pone «mercaderías».
    func testElNombreEscritoCorrigeLaCuenta() throws {
        let palabras = [
            PalabraLeida("4.900,00", x: 0.08, y: 200), PalabraLeida("merraderics", x: 0.25, y: 200),
            PalabraLeida("(608)", x: 0.37, y: 200),
            PalabraLeida("(400)", x: 0.62, y: 200), PalabraLeida("Proveedores", x: 0.78, y: 200),
            PalabraLeida("4.900,00", x: 0.93, y: 200),
        ]
        let leido = try XCTUnwrap(LectorAsientos.leer(palabras).first)
        XCTAssertEqual(leido.apuntes, [Apunte(.debe, "600", 4_900), Apunte(.haber, "400", 4_900)])
        XCTAssertEqual(leido.pistas, ["Leo la 608, pero el nombre escrito es el de la 600 (Compras de mercaderías): "
                                      + "tomo la 600. Si no, tócala y corrígela."])
    }

    func testSiElNombreEncajaNoSeTocaLaCuenta() throws {
        let palabras = [PalabraLeida("300,00", x: 0.08, y: 200), PalabraLeida("Devoluciones", x: 0.2, y: 200),
                        PalabraLeida("compras", x: 0.3, y: 200), PalabraLeida("(608)", x: 0.37, y: 200)]
        let leido = try XCTUnwrap(LectorAsientos.leer(palabras).first)
        XCTAssertEqual(leido.apuntes, [Apunte(.debe, "608", 300)])
        XCTAssertEqual(leido.pistas, [])
    }

    func testPalabrasQueSeParecen() {
        XCTAssertTrue(NombreCuenta.seParecen("merraderics", "mercaderias"))
        XCTAssertTrue(NombreCuenta.seParecen("antic", "anticipos"), "abreviada")
        XCTAssertFalse(NombreCuenta.seParecen("bancos", "caja"))
        XCTAssertEqual(NombreCuenta.palabras("HP, IVA soportado"), ["soportado"])
    }

    func testHojasConPistasSeGuardanYSeLeen() throws {
        let leido = AsientoLeido(apuntes: [Apunte(.debe, "572", 10)], pistas: ["Compruébalo."])
        let copia = try JSONDecoder().decode(AsientoLeido.self, from: JSONEncoder().encode(leido))
        XCTAssertEqual(copia, leido)
    }
}
