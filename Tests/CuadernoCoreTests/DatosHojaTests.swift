import XCTest
@testable import CuadernoCore

/// Rayas que separan asientos, fechas que se heredan, zonas ajustables y la apertura.
final class DatosHojaTests: XCTestCase {
    private func fila(_ debe: String, _ cuentaDebe: String, _ cuentaHaber: String, _ haber: String,
                      y: Double) -> [PalabraLeida] {
        [PalabraLeida(debe, x: 0.05, y: y), PalabraLeida(cuentaDebe, x: 0.35, y: y),
         PalabraLeida(cuentaHaber, x: 0.65, y: y), PalabraLeida(haber, x: 0.95, y: y)]
    }

    func testUnaRayaSeparaLosAsientos() {
        let palabras = fila("1000", "572", "430", "1000", y: 100) + fila("500", "600", "400", "500", y: 300)
        XCTAssertEqual(LectorAsientos.leer(palabras).count, 1, "sin raya ni fecha, es un solo asiento")
        let leidos = LectorAsientos.leer(palabras, separadores: [200])
        XCTAssertEqual(leidos.count, 2)
        XCTAssertEqual(leidos[1].apuntes, [Apunte(.debe, "600", 500), Apunte(.haber, "400", 500)])
    }

    func testRayasDeMasNoCreanAsientosVacios() {
        let palabras = fila("1000", "572", "430", "1000", y: 100)
        XCTAssertEqual(LectorAsientos.leer(palabras, separadores: [20, 60, 200, 210]).count, 1)
    }

    func testFechaEscritaEncimaDeLaRayaValeParaElAsientoDeDebajo() {
        let palabras = [PalabraLeida("01/12/24", x: 0.5, y: 80)] + fila("1000", "572", "430", "1000", y: 150)
        let leidos = LectorAsientos.leer(palabras, separadores: [110])
        XCTAssertEqual(leidos.count, 1)
        XCTAssertEqual(leidos[0].fecha, Fecha(año: 2024, mes: 12, dia: 1))
    }

    func testEsSeparador() {
        XCTAssertTrue(LectorAsientos.esSeparador(ancho: 400, alto: 12, anchoPagina: 1000))
        XCTAssertTrue(LectorAsientos.esSeparador(ancho: 300, alto: 22, anchoPagina: 1000))
        XCTAssertFalse(LectorAsientos.esSeparador(ancho: 120, alto: 10, anchoPagina: 1000), "demasiado corta")
        XCTAssertFalse(LectorAsientos.esSeparador(ancho: 400, alto: 90, anchoPagina: 1000), "no es plana")
    }

    func testZonasAjustadasCambianElLado() {
        // «Hacienda Pública, acreedora» ocupa más: el Debe se ensancha hasta 0,55.
        let palabras = [PalabraLeida("1000", x: 0.05, y: 100), PalabraLeida("4751", x: 0.50, y: 100)]
        XCTAssertEqual(LectorAsientos.leer(palabras)[0].apuntes, [], "con las zonas por defecto, 0,50 es el centro")
        let anchas = Zonas().moviendo(inicioHaber: 0.7).moviendo(finDebe: 0.55)
        XCTAssertEqual(LectorAsientos.leer(palabras, zonas: anchas)[0].apuntes, [Apunte(.debe, "4751", 1_000)])
    }

    func testLasZonasNoSeCruzan() {
        let zonas = Zonas(finDebe: 0.42, inicioHaber: 0.58)
        XCTAssertEqual(zonas.moviendo(finDebe: 0.9).finDebe, 0.58 - Zonas.anchoMinimoCentro, accuracy: 1e-9)
        XCTAssertEqual(zonas.moviendo(inicioHaber: 0.1).inicioHaber, 0.42 + Zonas.anchoMinimoCentro, accuracy: 1e-9)
        XCTAssertEqual(zonas.moviendo(finDebe: 0).finDebe, 0.15, accuracy: 1e-9)
    }

    func testSiNoHayFechaSeHeredaLaDelAsientoAnterior() {
        let leidos = [AsientoLeido(fecha: Fecha(año: 2024, mes: 12, dia: 1)), AsientoLeido(), AsientoLeido()]
        var datos = DatosHoja(esApertura: false, fechaInicial: Fecha(año: 2025, mes: 1, dia: 1)!)
        datos.fechasManuales[2] = Fecha(año: 2024, mes: 12, dia: 5)
        let resueltos = datos.resolver(leidos, empresa: "X")
        XCTAssertEqual(resueltos.map(\.fecha), [Fecha(año: 2024, mes: 12, dia: 1)!, Fecha(año: 2024, mes: 12, dia: 1)!,
                                               Fecha(año: 2024, mes: 12, dia: 5)!])
        XCTAssertEqual(resueltos.map(\.fechaPuestaAMano), [false, false, true])
        XCTAssertEqual(resueltos.map(\.numero), [1, 2, 3])
    }

    func testSinNingunaFechaSeUsaLaDeLaHoja() {
        let datos = DatosHoja(esApertura: false, fechaInicial: Fecha(año: 2025, mes: 10, dia: 25)!)
        XCTAssertEqual(datos.resolver([AsientoLeido()], empresa: "X")[0].fecha, Fecha(año: 2025, mes: 10, dia: 25))
    }

    func testAperturaConElAsientoDeTuria() throws {
        let apertura = try XCTUnwrap(CasoTuria.asientos().first)
        let datos = DatosHoja(esApertura: true, fechaInicial: apertura.fecha)
        let resuelto = datos.resolver([AsientoLeido(apuntes: apertura.apuntes)], empresa: "X")[0]
        XCTAssertEqual(resuelto.concepto, "Asiento de apertura")
        XCTAssertEqual(resuelto.avisos, [])
        XCTAssertNotNil(resuelto.asiento)
    }

    func testAperturaConCuentaDeGastosAvisa() {
        let apuntes = [Apunte(.debe, "572", 1_000), Apunte(.debe, "600", 200), Apunte(.haber, "100", 1_200)]
        let datos = DatosHoja(esApertura: true, fechaInicial: Fecha(año: 2025, mes: 1, dia: 1)!)
        let resueltos = datos.resolver([AsientoLeido(apuntes: apuntes), AsientoLeido(apuntes: apuntes)], empresa: "X")
        XCTAssertEqual(resueltos[0].avisos,
                       ["La apertura solo lleva cuentas de balance (grupos 1 a 5): la 600 es del grupo 6."])
        XCTAssertEqual(resueltos[1].avisos, [], "solo el primer asiento es la apertura")
        XCTAssertEqual(resueltos[1].concepto, "")
    }

    func testRecomendacionesSinBloquear() {
        let aMedias = AsientoLeido(apuntes: [Apunte(.debe, "572", 1_000)], noEntendido: ["1000"])
        XCTAssertEqual(DatosHoja.sugerencias(aMedias), [
            "En «1000» solo leo un número: la cuenta va pegada al centro y el importe en el borde.",
            "Falta el Haber: escribe a la derecha la cuenta y el importe.",
        ])
        XCTAssertEqual(DatosHoja.sugerencias(AsientoLeido(noEntendido: ["1000 072"])),
                       ["En «1000 072» no encuentro una cuenta válida (3 cifras o más, sin empezar por 0)."])
        let completo = AsientoLeido(apuntes: [Apunte(.debe, "572", 1_000), Apunte(.haber, "430", 1_000)])
        XCTAssertEqual(DatosHoja.sugerencias(completo), [])
    }
}
