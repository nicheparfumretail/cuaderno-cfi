import XCTest
@testable import CuadernoCore

final class CalculadoraTests: XCTestCase {
    /// Teclea como en la calculadora: cifras, «,», + - * / ^ %, paréntesis, «=», «±» (cambiar de
    /// signo) y «<» (⌫ o AC).
    private func teclear(_ texto: String, en calculadora: inout Calculadora) {
        for caracter in texto {
            switch caracter {
            case "0"..."9": calculadora.pulsar(.digito(Int(String(caracter))!))
            case ",": calculadora.pulsar(.coma)
            case "+": calculadora.pulsar(.operador(.suma))
            case "-": calculadora.pulsar(.operador(.resta))
            case "*": calculadora.pulsar(.operador(.producto))
            case "/": calculadora.pulsar(.operador(.division))
            case "^": calculadora.pulsar(.operador(.potencia))
            case "%": calculadora.pulsar(.posfijo(.porcentaje))
            case "(": calculadora.pulsar(.abre)
            case ")": calculadora.pulsar(.cierra)
            case "=": calculadora.pulsar(.igual)
            case "±": calculadora.pulsar(.cambiarSigno)
            case "<": calculadora.pulsar(.borrar)
            default: XCTFail("Tecla desconocida: \(caracter)")
            }
        }
    }

    private func pantalla(_ texto: String) -> String {
        var calculadora = Calculadora()
        teclear(texto, en: &calculadora)
        return calculadora.pantalla
    }

    func testPrioridadDeOperacionesYParentesis() {
        XCTAssertEqual(pantalla("2+3*4="), "14")
        XCTAssertEqual(pantalla("(2+3)*4="), "20")
        XCTAssertEqual(pantalla("2(3+4)="), "14", "un paréntesis detrás de un número multiplica")
        XCTAssertEqual(pantalla("(2+3*4="), "14", "los paréntesis sin cerrar se cierran solos")
        XCTAssertEqual(pantalla("2+*3="), "6", "dos operadores seguidos: vale el último")
    }

    /// El porcentaje como en cualquier calculadora: en una suma, base + IVA.
    func testPorcentajeDeIVA() {
        XCTAssertEqual(pantalla("100+21%="), "121")
        XCTAssertEqual(pantalla("4850+21%="), "5.868,5", "base de Túria con su IVA")
        XCTAssertEqual(pantalla("4850*21%="), "1.018,5", "la cuota de IVA")
        XCTAssertEqual(pantalla("121-10%="), "108,9")
        XCTAssertEqual(pantalla("50%="), "0,5")
    }

    /// Las cuentas de importes van en Decimal: nada de 0,30000000000000004.
    func testDecimalesExactos() {
        XCTAssertEqual(pantalla("0,1+0,2="), "0,3")
        XCTAssertEqual(pantalla("1/3*3="), "1")
        XCTAssertEqual(pantalla("1/3*3-1="), "0", "sin restos de la cifra 38")
        XCTAssertEqual(pantalla("10/4="), "2,5")
    }

    /// Interés compuesto: 1.000 € al 5 % durante 10 años, exacto con Decimal.
    func testInteresCompuesto() {
        XCTAssertEqual(pantalla("1000*1,05^10="), "1.628,89462677744")
        XCTAssertEqual(pantalla("2^3±="), "0,125", "exponente negativo con ±")
    }

    func testSeEscribeALaEspañola() {
        var calculadora = Calculadora()
        teclear("1234,50", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "1.234,50")
        teclear("+2", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "1.234,50+2")
        XCTAssertEqual(pantalla("99999999*99999999="), "9,9999998e15", "lo que no cabe, en notación científica")
    }

    func testBorrarYAC() {
        var calculadora = Calculadora()
        teclear("12+3", en: &calculadora)
        XCTAssertEqual(calculadora.etiquetaBorrar, "⌫")
        teclear("<", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "12+")
        teclear("<", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "12")
        teclear("=", en: &calculadora)
        XCTAssertEqual(calculadora.etiquetaBorrar, "AC")
        teclear("<", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "0")
    }

    func testDespuesDelResultado() {
        var calculadora = Calculadora()
        teclear("2+3=", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "5")
        XCTAssertEqual(calculadora.cuentaAnterior, "2+3")
        teclear("*2=", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "10", "un operador sigue con el resultado")
        teclear("7", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "7", "una cifra empieza otra cuenta")
    }

    func testCambiarDeSigno() {
        XCTAssertEqual(pantalla("5±+8="), "3")
        XCTAssertEqual(pantalla("2*(3+4)±="), "−14")
    }

    func testDividirEntreCeroEsError() {
        var calculadora = Calculadora()
        teclear("5/0=", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "Error")
        teclear("7", en: &calculadora)
        XCTAssertEqual(calculadora.pantalla, "7", "tras el error se empieza de nuevo")
    }

    func testFuncionesCientificas() {
        var raiz = Calculadora()
        teclear("9", en: &raiz)
        raiz.pulsar(.funcion(.raizCuadrada))
        teclear("=", en: &raiz)
        XCTAssertEqual(raiz.pantalla, "3")

        var delante = Calculadora()
        delante.pulsar(.funcion(.raizCuadrada))
        teclear("16=", en: &delante)
        XCTAssertEqual(delante.pantalla, "4", "la función primero y el número dentro")

        var seno = Calculadora()
        teclear("30", en: &seno)
        seno.pulsar(.funcion(.seno))
        teclear("=", en: &seno)
        XCTAssertEqual(seno.pantalla, "0,5", "en grados, como la de Apple al abrirla")

        var radianes = Calculadora()
        radianes.pulsar(.radianes)
        radianes.pulsar(.constante(.pi))
        radianes.pulsar(.funcion(.seno))
        teclear("=", en: &radianes)
        XCTAssertEqual(radianes.pantalla, "0")

        var factorial = Calculadora()
        teclear("5", en: &factorial)
        factorial.pulsar(.posfijo(.factorial))
        teclear("=", en: &factorial)
        XCTAssertEqual(factorial.pantalla, "120")

        var notacion = Calculadora()
        teclear("1,5", en: &notacion)
        notacion.pulsar(.operador(.exponente))
        teclear("3=", en: &notacion)
        XCTAssertEqual(notacion.pantalla, "1.500")

        var logaritmo = Calculadora()
        logaritmo.pulsar(.funcion(.ln))
        teclear("0=", en: &logaritmo)
        XCTAssertEqual(logaritmo.pantalla, "Error")
    }

    /// M+ para ir sumando, como al cuadrar el Debe de varios asientos.
    func testMemoria() {
        var calculadora = Calculadora()
        teclear("100", en: &calculadora)
        calculadora.pulsar(.memoria(.sumar))
        teclear("20+1=", en: &calculadora)
        calculadora.pulsar(.memoria(.sumar))
        XCTAssertTrue(calculadora.hayMemoria)
        teclear("<", en: &calculadora)
        calculadora.pulsar(.memoria(.recuperar))
        XCTAssertEqual(calculadora.pantalla, "121")
        calculadora.pulsar(.memoria(.borrar))
        XCTAssertFalse(calculadora.hayMemoria)
    }
}
