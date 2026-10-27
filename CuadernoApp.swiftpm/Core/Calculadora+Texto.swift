import Foundation

/// Cómo enseña la calculadora lo escrito y sus resultados: a la española, como los importes del
/// cuaderno (1.234,5), y en notación científica si no caben en la pantalla.
extension Calculadora {
    static func texto(de piezas: [Pieza]) -> String {
        var resultado = ""
        for pieza in piezas { resultado += Calculadora.texto(de: pieza) }
        return resultado
    }

    static func texto(de pieza: Pieza) -> String {
        switch pieza {
        case .numero(let escrito): return escritoALaEspañola(escrito)
        case .valor(let valor): return formatear(valor)
        case .operador(let operador): return simbolo(de: operador)
        case .posfijo(let posfijo): return simbolo(de: posfijo)
        case .funcion(let funcion): return simbolo(de: funcion)
        case .constante(let constante): return constante == .pi ? "π" : "e"
        case .abre: return "("
        case .cierra: return ")"
        case .negativo: return "−"
        }
    }

    static func simbolo(de operador: Operador) -> String {
        switch operador {
        case .suma: return "+"
        case .resta: return "−"
        case .producto: return "×"
        case .division: return "÷"
        case .potencia: return "^"
        case .potenciaInversa: return "yˣ"
        case .raiz: return "ʸ√"
        case .logaritmo: return "logᵧ"
        case .exponente: return "E"
        }
    }

    static func simbolo(de posfijo: Posfijo) -> String {
        switch posfijo {
        case .porcentaje: return "%"
        case .factorial: return "!"
        case .cuadrado: return "²"
        case .cubo: return "³"
        case .inverso: return "⁻¹"
        }
    }

    static func simbolo(de funcion: Funcion) -> String {
        switch funcion {
        case .raizCuadrada: return "√"
        case .raizCubica: return "∛"
        case .ln: return "ln"
        case .log10: return "log"
        case .log2: return "log₂"
        case .exponencial: return "e^"
        case .diezALa: return "10^"
        case .dosALa: return "2^"
        case .seno: return "sin"
        case .coseno: return "cos"
        case .tangente: return "tan"
        case .arcoseno: return "sin⁻¹"
        case .arcocoseno: return "cos⁻¹"
        case .arcotangente: return "tan⁻¹"
        case .senoH: return "sinh"
        case .cosenoH: return "cosh"
        case .tangenteH: return "tanh"
        case .arcosenoH: return "sinh⁻¹"
        case .arcocosenoH: return "cosh⁻¹"
        case .arcotangenteH: return "tanh⁻¹"
        }
    }

    /// Un resultado como en la pantalla: hasta 15 cifras, a la española (1.234,5) y, si es muy
    /// grande o muy pequeño, en notación científica (9,9999998e15).
    public static func formatear(_ valor: Decimal) -> String {
        guard !valor.isNaN else { return "Error" }
        let redondeado = redondear(valor, cifras: maximoCifras)
        guard redondeado != 0 else { return "0" }
        let potencia = orden(redondeado)
        guard potencia >= maximoCifras || potencia < -9 else {
            return escritoALaEspañola(plano(redondeado))
        }
        let signo: FloatingPointSign = redondeado < 0 ? .minus : .plus
        let mantisa = Decimal(sign: signo, exponent: -potencia, significand: abs(redondeado))
        let exponente = String(potencia).replacingOccurrences(of: "-", with: "−")
        return escritoALaEspañola(plano(redondear(mantisa, cifras: 10))) + "e" + exponente
    }

    /// Un número tecleado ("-1234.50") a la española ("−1.234,50"), tal cual, con sus ceros.
    static func escritoALaEspañola(_ escrito: String) -> String {
        let negativo = escrito.hasPrefix("-")
        let cuerpo = negativo ? String(escrito.dropFirst()) : escrito
        let partes = cuerpo.split(separator: ".", omittingEmptySubsequences: false)
        var resultado = agrupar(String(partes.first ?? "0"))
        if partes.count > 1 { resultado += "," + String(partes[1]) }
        return (negativo ? "−" : "") + resultado
    }

    /// "1234567" → "1.234.567", como en los importes.
    static func agrupar(_ entera: String) -> String {
        var grupos: [String] = []
        var resto = Substring(entera)
        while resto.count > 3 {
            grupos.insert(String(resto.suffix(3)), at: 0)
            resto = resto.dropLast(3)
        }
        grupos.insert(String(resto), at: 0)
        return grupos.joined(separator: ".")
    }

    /// El número con punto decimal y sin ceros de sobra: "1234.5", "-0.25", "3".
    static func plano(_ valor: Decimal) -> String {
        var texto = "\(valor)"
        if texto.contains(".") {
            while texto.hasSuffix("0") { texto.removeLast() }
            if texto.hasSuffix(".") { texto.removeLast() }
        }
        return texto
    }

    /// La potencia de diez de la primera cifra: 1.234,5 → 3; 0,0012 → −3.
    static func orden(_ valor: Decimal) -> Int {
        let texto = "\(abs(valor))"
        let partes = texto.split(separator: ".", omittingEmptySubsequences: false)
        let entera = partes.first ?? "0"
        if entera != "0" { return entera.count - 1 }
        let decimales = partes.count > 1 ? partes[1] : ""
        return -(decimales.prefix { $0 == "0" }.count + 1)
    }

    /// Redondea a unas cifras significativas, mitad hacia arriba, como `Importe.redondear`.
    static func redondear(_ valor: Decimal, cifras: Int) -> Decimal {
        guard valor != 0, !valor.isNaN else { return valor }
        var entrada = valor
        var salida = Decimal()
        NSDecimalRound(&salida, &entrada, cifras - 1 - orden(valor), .plain)
        return salida
    }
}
