import Foundation

/// La calculadora de las hojas, como la científica de Apple: se escribe la cuenta entera (con
/// prioridad de operaciones y paréntesis) y «=» la resuelve.
///
/// Está en el motor, y no en la interfaz, para que sus cuentas se prueben con tests. Sumar, restar,
/// multiplicar, dividir y los porcentajes son cuentas de importes (bases, cuotas de IVA, sumas del
/// Debe) y van en `Decimal`, exactas como en el libro: 0,1 + 0,2 = 0,3. La potencia de exponente
/// entero —el interés compuesto, (1 + i)ⁿ— también. Solo las funciones científicas (raíces,
/// logaritmos, trigonometría) pasan por `Double`, redondeadas a 15 cifras.
public struct Calculadora {
    public enum Operador: Equatable {
        case suma, resta, producto, division
        /// xʸ, y su inversa del modo 2nd (yˣ: el segundo número elevado al primero).
        case potencia, potenciaInversa
        /// ʸ√x: la raíz y-ésima del primer número.
        case raiz
        /// logᵧ: el logaritmo del primer número en base el segundo.
        case logaritmo
        /// EE: 1,5 EE 3 = 1,5 × 10³.
        case exponente
    }

    public enum Funcion: Equatable {
        case raizCuadrada, raizCubica, ln, log10, log2, exponencial, diezALa, dosALa
        case seno, coseno, tangente, arcoseno, arcocoseno, arcotangente
        case senoH, cosenoH, tangenteH, arcosenoH, arcocosenoH, arcotangenteH
    }

    /// Lo que se aplica al número de delante: 21 %, 5!, 3², 3³, 4⁻¹.
    public enum Posfijo: Equatable {
        case porcentaje, factorial, cuadrado, cubo, inverso
    }

    public enum Constante: Equatable {
        case pi, e
    }

    public enum Memoria: Equatable {
        case borrar, sumar, restar, recuperar
    }

    public enum Tecla: Equatable {
        case digito(Int)
        case coma
        case operador(Operador)
        case posfijo(Posfijo)
        case funcion(Funcion)
        case constante(Constante)
        case abre, cierra
        case cambiarSigno
        /// «⌫» mientras se escribe; «AC» con un resultado o la pantalla vacía.
        case borrar
        case igual
        case memoria(Memoria)
        case aleatorio
        /// 2nd: las teclas científicas pasan a su inversa (sin⁻¹, log₂…).
        case segunda
        /// Rad/Deg: los ángulos en radianes o en grados.
        case radianes
    }

    /// Lo escrito, pieza a pieza.
    enum Pieza: Equatable {
        /// Un número tal como se teclea, con punto decimal: "12.5", "0.", "-3".
        case numero(String)
        /// Un número que viene de una cuenta (un resultado, la memoria, Rand), con todas sus cifras.
        case valor(Decimal)
        case operador(Operador)
        case posfijo(Posfijo)
        /// Siempre va seguida de su paréntesis: sin(…).
        case funcion(Funcion)
        case constante(Constante)
        case abre, cierra
        /// El signo menos delante de un número o de un paréntesis.
        case negativo
    }

    /// Cifras de un número tecleado y cifras con las que se enseña un resultado.
    static let maximoCifras = 15

    var piezas: [Pieza] = []
    /// La cuenta que se acaba de resolver; se ve en pequeño encima del resultado.
    public private(set) var cuentaAnterior = ""
    /// Recién pulsado «=»: una cifra empieza otra cuenta y un operador sigue con el resultado.
    private(set) var recienResuelta = false
    public private(set) var hayError = false
    public private(set) var memoria: Decimal = 0
    public private(set) var segunda = false
    /// Como la de Apple al abrirla: los ángulos, en grados.
    public private(set) var enRadianes = false

    public init() {}

    /// Lo que se ve en grande: la cuenta mientras se escribe o el resultado.
    public var pantalla: String {
        if hayError { return "Error" }
        return piezas.isEmpty ? "0" : Calculadora.texto(de: piezas)
    }

    public var etiquetaBorrar: String {
        piezas.isEmpty || recienResuelta || hayError ? "AC" : "⌫"
    }

    public var hayMemoria: Bool {
        memoria != 0
    }

    public mutating func pulsar(_ tecla: Tecla) {
        if hayError {
            // Tras un error se empieza de nuevo.
            hayError = false
            piezas = []
            if tecla == .borrar { return }
        }
        switch tecla {
        case .digito(let cifra): escribir(cifra)
        case .coma: escribirComa()
        case .operador(let operador): poner(operador)
        case .posfijo(let posfijo): aplicar(posfijo)
        case .funcion(let funcion): aplicar(funcion)
        case .constante(let constante): ponerOperando(.constante(constante))
        case .aleatorio: ponerOperando(.valor(Calculadora.aleatorio()))
        case .abre: abrir()
        case .cierra: cerrar()
        case .cambiarSigno: cambiarSigno()
        case .borrar: borrar()
        case .igual: resolver()
        case .memoria(let accion): usar(accion)
        case .segunda: segunda.toggle()
        case .radianes: enRadianes.toggle()
        }
    }

    // MARK: - Escribir

    private mutating func escribir(_ cifra: Int) {
        empezarSiResuelta()
        if case .numero(let texto)? = piezas.last {
            guard texto.filter(\.isNumber).count < Calculadora.maximoCifras else { return }
            let nuevo: String
            if texto == "0" {
                nuevo = "\(cifra)"
            } else if texto == "-0" {
                nuevo = "-\(cifra)"
            } else {
                nuevo = texto + "\(cifra)"
            }
            piezas[piezas.count - 1] = .numero(nuevo)
            return
        }
        multiplicarSiHaceFalta()
        piezas.append(.numero("\(cifra)"))
    }

    private mutating func escribirComa() {
        empezarSiResuelta()
        if case .numero(let texto)? = piezas.last {
            if !texto.contains(".") { piezas[piezas.count - 1] = .numero(texto + ".") }
            return
        }
        multiplicarSiHaceFalta()
        piezas.append(.numero("0."))
    }

    private mutating func poner(_ operador: Operador) {
        recienResuelta = false
        guard let ultima = piezas.last else {
            // Sin nada escrito, «−» empieza un número negativo y los demás operan sobre 0.
            piezas = operador == .resta ? [.negativo] : [.numero("0"), .operador(operador)]
            return
        }
        switch ultima {
        case .operador:
            // Dos operadores seguidos: vale el último, como en la de Apple.
            piezas[piezas.count - 1] = .operador(operador)
        case .abre, .negativo, .funcion:
            if operador == .resta && ultima != .negativo { piezas.append(.negativo) }
        default:
            piezas.append(.operador(operador))
        }
    }

    private mutating func aplicar(_ posfijo: Posfijo) {
        recienResuelta = false
        guard rangoUltimoOperando() != nil else { return }
        piezas.append(.posfijo(posfijo))
    }

    /// Con un número delante, la función se le aplica (30 sin → sin(30)); si no, se abre su
    /// paréntesis y el número se escribe dentro.
    private mutating func aplicar(_ funcion: Funcion) {
        recienResuelta = false
        var nuevas: [Pieza] = [.funcion(funcion), .abre]
        if let rango = rangoUltimoOperando() {
            nuevas += Array(piezas[rango])
            nuevas.append(.cierra)
            piezas.replaceSubrange(rango, with: nuevas)
        } else {
            piezas += nuevas
        }
    }

    private mutating func ponerOperando(_ pieza: Pieza) {
        empezarSiResuelta()
        multiplicarSiHaceFalta()
        piezas.append(pieza)
    }

    private mutating func abrir() {
        empezarSiResuelta()
        multiplicarSiHaceFalta()
        piezas.append(.abre)
    }

    private mutating func cerrar() {
        guard parentesisAbiertos > 0, rangoUltimoOperando() != nil else { return }
        piezas.append(.cierra)
    }

    private mutating func cambiarSigno() {
        recienResuelta = false
        guard let rango = rangoUltimoOperando() else {
            if piezas.last == .negativo { piezas.removeLast() } else { piezas.append(.negativo) }
            return
        }
        let inicio = rango.lowerBound
        if rango.count == 1, case .numero(let texto) = piezas[inicio] {
            piezas[inicio] = .numero(texto.hasPrefix("-") ? String(texto.dropFirst()) : "-" + texto)
        } else if rango.count == 1, case .valor(let valor) = piezas[inicio] {
            piezas[inicio] = .valor(-valor)
        } else if inicio > 0, piezas[inicio - 1] == .negativo {
            piezas.remove(at: inicio - 1)
        } else {
            piezas.insert(.negativo, at: inicio)
        }
    }

    private mutating func borrar() {
        if piezas.isEmpty || recienResuelta {
            piezas = []
            cuentaAnterior = ""
            recienResuelta = false
            return
        }
        let ultima = piezas.removeLast()
        switch ultima {
        case .numero(let texto):
            let corto = String(texto.dropLast())
            if !corto.isEmpty && corto != "-" { piezas.append(.numero(corto)) }
        case .abre:
            // El paréntesis de una función se va con ella.
            if case .funcion? = piezas.last { piezas.removeLast() }
        default:
            break
        }
    }

    private mutating func resolver() {
        guard !piezas.isEmpty, !recienResuelta else { return }
        let cuenta = Calculadora.texto(de: piezas)
        do {
            let resultado = try valor(de: piezas)
            cuentaAnterior = cuenta
            piezas = [.valor(resultado)]
            recienResuelta = true
        } catch {
            cuentaAnterior = cuenta
            piezas = []
            hayError = true
        }
    }

    /// M+ y M− resuelven lo escrito y suman (o restan) el resultado: 100 + 21 % M+ guarda 121.
    private mutating func usar(_ accion: Memoria) {
        switch accion {
        case .borrar:
            memoria = 0
        case .sumar, .restar:
            if !piezas.isEmpty && !recienResuelta { resolver() }
            guard !hayError else { return }
            let actual = valorEnPantalla
            memoria = accion == .sumar ? memoria + actual : memoria - actual
            recienResuelta = true
        case .recuperar:
            ponerOperando(.valor(memoria))
        }
    }

    // MARK: - Ayudas

    private mutating func empezarSiResuelta() {
        if recienResuelta {
            piezas = []
            recienResuelta = false
        }
    }

    /// Un número o un paréntesis justo detrás de otro número multiplica: 2(3 + 4) = 14.
    private mutating func multiplicarSiHaceFalta() {
        if rangoUltimoOperando() != nil { piezas.append(.operador(.producto)) }
    }

    private var parentesisAbiertos: Int {
        var abiertos = 0
        for pieza in piezas {
            if pieza == .abre { abiertos += 1 }
            if pieza == .cierra { abiertos -= 1 }
        }
        return abiertos
    }

    /// El número de la pantalla (0 si está vacía).
    private var valorEnPantalla: Decimal {
        guard piezas.count == 1 else { return 0 }
        switch piezas[0] {
        case .valor(let valor): return valor
        case .numero(let texto): return Calculadora.leer(texto) ?? 0
        default: return 0
        }
    }

    /// Dónde empieza lo último escrito si está completo: un número, una constante o un paréntesis
    /// cerrado (con su función delante), con lo que lleve detrás (%, !, ²…). Nil si lo último es un
    /// operador o un paréntesis abierto.
    func rangoUltimoOperando() -> Range<Int>? {
        var i = piezas.count - 1
        while i >= 0, case .posfijo = piezas[i] { i -= 1 }
        guard i >= 0 else { return nil }
        switch piezas[i] {
        case .numero, .valor, .constante:
            return i..<piezas.count
        case .cierra:
            var nivel = 0
            var j = i
            while j >= 0 {
                if piezas[j] == .cierra { nivel += 1 }
                if piezas[j] == .abre {
                    nivel -= 1
                    if nivel == 0 { break }
                }
                j -= 1
            }
            guard j >= 0 else { return nil }
            if j > 0, case .funcion = piezas[j - 1] { j -= 1 }
            return j..<piezas.count
        default:
            return nil
        }
    }
}
