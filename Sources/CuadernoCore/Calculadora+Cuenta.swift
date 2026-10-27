import Foundation

/// Cómo resuelve la calculadora lo escrito: lo lee como un árbol con la prioridad de siempre
/// (paréntesis, potencias, productos y divisiones, sumas y restas) y lo calcula.
extension Calculadora {
    enum Fallo: Error {
        case sintaxis, divisionPorCero, fueraDeDominio, desbordamiento
    }

    indirect enum Nodo {
        case numero(Decimal)
        case binario(Operador, Nodo, Nodo)
        case funcion(Funcion, Nodo)
        case posfijo(Posfijo, Nodo)
        case negativo(Nodo)
    }

    static let posix = Locale(identifier: "en_US_POSIX")
    static let pi = Decimal(string: "3.14159265358979323846264338327950288", locale: posix)!
    static let e = Decimal(string: "2.71828182845904523536028747135266250", locale: posix)!

    // MARK: - Resolver

    /// El valor de lo escrito. Lo que queda a medias al final no cuenta («2 +» vale 2) y los
    /// paréntesis sin cerrar se cierran solos.
    func valor(de piezas: [Pieza]) throws -> Decimal {
        var completas = piezas
        while let ultima = completas.last, !Calculadora.cierraOperando(ultima) {
            completas.removeLast()
        }
        guard !completas.isEmpty else { throw Fallo.sintaxis }
        var lector = Lector(piezas: completas)
        let arbol = try lector.leerTodo()
        let resultado = try valor(de: arbol)
        guard !resultado.isNaN else { throw Fallo.desbordamiento }
        return resultado
    }

    static func cierraOperando(_ pieza: Pieza) -> Bool {
        switch pieza {
        case .numero, .valor, .constante, .cierra, .posfijo: return true
        default: return false
        }
    }

    func valor(de nodo: Nodo) throws -> Decimal {
        switch nodo {
        case .numero(let numero):
            return numero
        case .negativo(let dentro):
            let positivo = try valor(de: dentro)
            return -positivo
        case .posfijo(let posfijo, let dentro):
            let x = try valor(de: dentro)
            return try Calculadora.calcular(posfijo, de: x)
        case .funcion(let funcion, let dentro):
            let x = try valor(de: dentro)
            return try calcular(funcion, de: x)
        case .binario(let operador, let izquierda, let derecha):
            let a = try valor(de: izquierda)
            // El porcentaje de una suma o una resta es del número de delante, como en cualquier
            // calculadora: 100 + 21 % = 121 (la base con su IVA); 121 − 10 % = 108,9.
            if operador == .suma || operador == .resta, case .posfijo(.porcentaje, let dentro) = derecha {
                let tipo = try valor(de: dentro)
                let parte = a * tipo / 100
                return operador == .suma ? a + parte : a - parte
            }
            let b = try valor(de: derecha)
            return try Calculadora.operar(operador, a, b)
        }
    }

    static func operar(_ operador: Operador, _ a: Decimal, _ b: Decimal) throws -> Decimal {
        switch operador {
        case .suma:
            return sinRestos(a + b, a, b)
        case .resta:
            return sinRestos(a - b, a, b)
        case .producto:
            return a * b
        case .division:
            guard b != 0 else { throw Fallo.divisionPorCero }
            return a / b
        case .potencia:
            return try elevar(a, a: b)
        case .potenciaInversa:
            return try elevar(b, a: a)
        case .raiz:
            return try raiz(a, indice: b)
        case .logaritmo:
            guard a > 0, b > 0, b != 1 else { throw Fallo.fueraDeDominio }
            return try aDecimal(log(aDouble(a)) / log(aDouble(b)))
        case .exponente:
            let potencia = try elevar(10, a: b)
            return a * potencia
        }
    }

    /// Dividir y volver a multiplicar deja restos en la cifra 38 (1 ÷ 3 × 3 = 0,999…9). Lo que es
    /// tan pequeño al lado de los números que se suman o se restan es cero.
    static func sinRestos(_ resultado: Decimal, _ a: Decimal, _ b: Decimal) -> Decimal {
        let mayor = max(abs(a), abs(b))
        let umbral = mayor * Decimal(sign: .plus, exponent: -25, significand: 1)
        return abs(resultado) < umbral ? 0 : resultado
    }

    static func calcular(_ posfijo: Posfijo, de x: Decimal) throws -> Decimal {
        switch posfijo {
        case .porcentaje:
            return x / 100
        case .cuadrado:
            return x * x
        case .cubo:
            return x * x * x
        case .inverso:
            guard x != 0 else { throw Fallo.divisionPorCero }
            return 1 / x
        case .factorial:
            return try factorial(x)
        }
    }

    func calcular(_ funcion: Funcion, de x: Decimal) throws -> Decimal {
        let d = Calculadora.aDouble(x)
        switch funcion {
        case .raizCuadrada:
            guard x >= 0 else { throw Fallo.fueraDeDominio }
            return try Calculadora.aDecimal(d.squareRoot())
        case .raizCubica:
            return try Calculadora.aDecimal(cbrt(d))
        case .ln, .log10, .log2:
            guard x > 0 else { throw Fallo.fueraDeDominio }
            let resultado: Double
            switch funcion {
            case .ln: resultado = log(d)
            case .log10: resultado = log10(d)
            default: resultado = log2(d)
            }
            return try Calculadora.aDecimal(resultado)
        case .exponencial:
            return try Calculadora.aDecimal(exp(d))
        case .diezALa:
            return try Calculadora.elevar(10, a: x)
        case .dosALa:
            return try Calculadora.elevar(2, a: x)
        case .seno:
            return try Calculadora.trigonometrico(sin(aRadianes(d)))
        case .coseno:
            return try Calculadora.trigonometrico(cos(aRadianes(d)))
        case .tangente:
            guard abs(cos(aRadianes(d))) > 1e-12 else { throw Fallo.fueraDeDominio }
            return try Calculadora.trigonometrico(tan(aRadianes(d)))
        case .arcoseno:
            guard abs(d) <= 1 else { throw Fallo.fueraDeDominio }
            return try Calculadora.aDecimal(deRadianes(asin(d)))
        case .arcocoseno:
            guard abs(d) <= 1 else { throw Fallo.fueraDeDominio }
            return try Calculadora.aDecimal(deRadianes(acos(d)))
        case .arcotangente:
            return try Calculadora.aDecimal(deRadianes(atan(d)))
        case .senoH:
            return try Calculadora.aDecimal(sinh(d))
        case .cosenoH:
            return try Calculadora.aDecimal(cosh(d))
        case .tangenteH:
            return try Calculadora.aDecimal(tanh(d))
        case .arcosenoH:
            return try Calculadora.aDecimal(asinh(d))
        case .arcocosenoH:
            guard d >= 1 else { throw Fallo.fueraDeDominio }
            return try Calculadora.aDecimal(acosh(d))
        case .arcotangenteH:
            guard abs(d) < 1 else { throw Fallo.fueraDeDominio }
            return try Calculadora.aDecimal(atanh(d))
        }
    }

    private func aRadianes(_ angulo: Double) -> Double {
        enRadianes ? angulo : angulo * Double.pi / 180
    }

    private func deRadianes(_ angulo: Double) -> Double {
        enRadianes ? angulo : angulo * 180 / Double.pi
    }

    /// sin 180° da 1,2·10⁻¹⁶ con Double: es cero.
    static func trigonometrico(_ resultado: Double) throws -> Decimal {
        if abs(resultado) < 1e-13 { return 0 }
        return try aDecimal(resultado)
    }

    /// Con exponente entero, en `Decimal` y exacta: 1,05¹⁰ = 1,62889462677744140625. Si no, con
    /// `Double`.
    static func elevar(_ base: Decimal, a exponente: Decimal) throws -> Decimal {
        if let n = entero(exponente), abs(n) <= 9999 {
            if n < 0 && base == 0 { throw Fallo.divisionPorCero }
            var resultado: Decimal = 1
            var factor = base
            var resto = abs(n)
            while resto > 0 {
                if resto % 2 == 1 { resultado *= factor }
                resto /= 2
                if resto > 0 { factor *= factor }
            }
            guard !resultado.isNaN else { throw Fallo.desbordamiento }
            return n < 0 ? 1 / resultado : resultado
        }
        guard base > 0 || (base == 0 && exponente > 0) else { throw Fallo.fueraDeDominio }
        return try aDecimal(pow(aDouble(base), aDouble(exponente)))
    }

    /// Solo las raíces de índice impar de un número negativo existen: ∛−8 = −2.
    static func raiz(_ x: Decimal, indice: Decimal) throws -> Decimal {
        guard indice != 0 else { throw Fallo.fueraDeDominio }
        if x < 0 {
            guard let n = entero(indice), n % 2 != 0 else { throw Fallo.fueraDeDominio }
            let positiva = try raiz(-x, indice: indice)
            return -positiva
        }
        return try aDecimal(pow(aDouble(x), 1 / aDouble(indice)))
    }

    /// Exacto hasta 100!; sin decimales no hay factorial de verdad y se usa la función gamma, como
    /// hace la de Apple.
    static func factorial(_ x: Decimal) throws -> Decimal {
        guard let n = entero(x) else {
            return try aDecimal(tgamma(aDouble(x) + 1))
        }
        guard n >= 0 else { throw Fallo.fueraDeDominio }
        guard n <= 100 else { throw Fallo.desbordamiento }
        var resultado: Decimal = 1
        var k = 2
        while k <= n {
            resultado *= Decimal(k)
            k += 1
        }
        return resultado
    }

    static func aleatorio() -> Decimal {
        (try? aDecimal(Double.random(in: 0..<1))) ?? 0
    }

    // MARK: - Decimal y Double

    static func leer(_ texto: String) -> Decimal? {
        let limpio = texto.hasSuffix(".") ? String(texto.dropLast()) : texto
        return Decimal(string: limpio, locale: posix)
    }

    static func entero(_ x: Decimal) -> Int? {
        guard !x.isNaN else { return nil }
        var entrada = x
        var redondeado = Decimal()
        NSDecimalRound(&redondeado, &entrada, 0, .plain)
        guard redondeado == x else { return nil }
        return Int(plano(redondeado))
    }

    static func aDouble(_ x: Decimal) -> Double {
        Double("\(x)") ?? .nan
    }

    /// De `Double` a `Decimal` con 15 cifras: lo que da de sí un Double sin arrastrar sus restos
    /// binarios (0,1 en binario es 0,1000000000000000055…).
    static func aDecimal(_ numero: Double) throws -> Decimal {
        guard numero.isFinite else { throw Fallo.fueraDeDominio }
        guard abs(numero) < 1e125 else { throw Fallo.desbordamiento }
        guard abs(numero) >= 1e-100 else { return 0 }
        let texto = String(format: "%.14e", abs(numero))
        let partes = texto.split(separator: "e")
        guard partes.count == 2, let mantisa = leer(String(partes[0])), let exponente = Int(partes[1]) else {
            throw Fallo.sintaxis
        }
        return Decimal(sign: numero < 0 ? .minus : .plus, exponent: exponente, significand: mantisa)
    }

    // MARK: - Lector

    /// Lee las piezas de izquierda a derecha con la prioridad de siempre.
    struct Lector {
        let piezas: [Pieza]
        var posicion = 0

        init(piezas: [Pieza]) {
            self.piezas = piezas
        }

        mutating func leerTodo() throws -> Nodo {
            let arbol = try suma()
            guard posicion == piezas.count else { throw Fallo.sintaxis }
            return arbol
        }

        private var actual: Pieza? {
            posicion < piezas.count ? piezas[posicion] : nil
        }

        private mutating func suma() throws -> Nodo {
            var nodo = try producto()
            while case .operador(let operador)? = actual, operador == .suma || operador == .resta {
                posicion += 1
                let derecha = try producto()
                nodo = .binario(operador, nodo, derecha)
            }
            return nodo
        }

        private mutating func producto() throws -> Nodo {
            var nodo = try signo()
            while case .operador(let operador)? = actual, operador == .producto || operador == .division {
                posicion += 1
                let derecha = try signo()
                nodo = .binario(operador, nodo, derecha)
            }
            return nodo
        }

        /// El menos de delante liga menos que la potencia: −2² = −4.
        private mutating func signo() throws -> Nodo {
            if actual == .negativo {
                posicion += 1
                let dentro = try signo()
                return .negativo(dentro)
            }
            return try potencia()
        }

        /// Por la derecha: 2^3^2 = 2^9. Y admite un exponente negativo: 2^−3.
        private mutating func potencia() throws -> Nodo {
            let base = try notacion()
            if case .operador(let operador)? = actual,
               operador == .potencia || operador == .potenciaInversa || operador == .raiz || operador == .logaritmo {
                posicion += 1
                let exponente = try signo()
                return .binario(operador, base, exponente)
            }
            return base
        }

        private mutating func notacion() throws -> Nodo {
            var nodo = try posfijos()
            while actual == .operador(.exponente) {
                posicion += 1
                let exponente = try posfijos()
                nodo = .binario(.exponente, nodo, exponente)
            }
            return nodo
        }

        private mutating func posfijos() throws -> Nodo {
            var nodo = try atomo()
            while case .posfijo(let posfijo)? = actual {
                posicion += 1
                nodo = .posfijo(posfijo, nodo)
            }
            return nodo
        }

        private mutating func atomo() throws -> Nodo {
            guard let pieza = actual else { throw Fallo.sintaxis }
            posicion += 1
            switch pieza {
            case .numero(let texto):
                guard let numero = Calculadora.leer(texto) else { throw Fallo.sintaxis }
                return .numero(numero)
            case .valor(let numero):
                return .numero(numero)
            case .constante(let constante):
                return .numero(constante == .pi ? Calculadora.pi : Calculadora.e)
            case .abre:
                let dentro = try suma()
                if actual == .cierra { posicion += 1 }
                return dentro
            case .funcion(let funcion):
                guard actual == .abre else { throw Fallo.sintaxis }
                let argumento = try atomo()
                return .funcion(funcion, argumento)
            default:
                throw Fallo.sintaxis
            }
        }
    }
}
