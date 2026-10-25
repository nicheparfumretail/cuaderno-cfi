import Foundation

/// La partida doble como prueba de la lectura: si un asiento no cuadra, la diferencia dice
/// qué cifra se ha leído mal y cuánto.
extension LectorAsientos {
    /// Si el asiento no cuadra, busca la lectura que lo hace cuadrar:
    /// - una fila con cuenta y sin importe: se dice qué importe haría falta;
    /// - una cifra en la que Vision dudó: se toma la otra lectura, y se avisa;
    /// - una cifra parecida (4 y 9, 1 y 7…) que Vision no propuso: solo se pregunta. Puede ser un
    ///   error de verdad al escribir, y eso es justo lo que hay que ver al estudiar.
    static func cuadrar(_ leido: AsientoLeido, dudas: [[Apunte]], fallidas: [Fallida]) -> AsientoLeido {
        var resultado = leido
        let debe = leido.apuntes.map(\.debe).reduce(0, +)
        let haber = leido.apuntes.map(\.haber).reduce(0, +)
        // Positivo: falta en el Debe; negativo: falta en el Haber.
        let falta = haber - debe
        guard falta != 0 else { return resultado }
        let ladoCorto: Lado = falta > 0 ? .debe : .haber
        let cuanto = falta > 0 ? falta : -falta

        if !fallidas.isEmpty {
            let sinImporte = fallidas.filter { $0.lado == ladoCorto && $0.cuenta != nil }
            if sinImporte.count == 1, let cuenta = sinImporte[0].cuenta {
                resultado.pistas.append("Para que cuadre, la \(cuenta) tendría que llevar \(Importe.formatear(cuanto)).")
            }
            return resultado
        }
        guard debe > 0, haber > 0 else { return resultado }
        func arregla(_ nuevo: Decimal, _ apunte: Apunte) -> Bool {
            nuevo - apunte.importe == (apunte.lado == .debe ? falta : -falta)
        }

        var arreglos: [(indice: Int, apunte: Apunte)] = []
        for (i, apunte) in leido.apuntes.enumerated() where i < dudas.count {
            if let bueno = dudas[i].first(where: { arregla($0.importe, apunte) }) {
                arreglos.append((i, bueno))
            }
        }
        if arreglos.count == 1, let arreglo = arreglos.first {
            let antes = Importe.formatear(leido.apuntes[arreglo.indice].importe)
            let despues = Importe.formatear(arreglo.apunte.importe)
            resultado.apuntes[arreglo.indice] = arreglo.apunte
            resultado.pistas.append("En la \(arreglo.apunte.cuenta) dudaba entre \(antes) y \(despues): "
                + "tomo \(despues), que es lo que hace cuadrar el asiento. Compruébalo.")
            return resultado
        }
        guard arreglos.isEmpty else { return resultado }

        var preguntas: [String] = []
        for apunte in leido.apuntes {
            let objetivo = apunte.importe + (apunte.lado == .debe ? falta : -falta)
            guard objetivo > 0, seConfunden(apunte.importe, objetivo) else { continue }
            let (escrito, cuadra) = (Importe.formatear(apunte.importe), Importe.formatear(objetivo))
            preguntas.append("¿En la \(apunte.cuenta) pone \(cuadra) y no \(escrito)? Con \(cuadra) cuadra.")
        }
        if (1...2).contains(preguntas.count) { resultado.pistas += preguntas }
        return resultado
    }

    /// Cifras que se confunden al escribir a mano o al leerlas.
    private static let parecidas: Set<String> = [
        "17", "49", "38", "56", "06", "08", "09", "27", "68", "35", "14", "23", "58", "89",
    ]

    /// Dos importes que solo se diferencian en una cifra parecida, o en una cifra que no se
    /// leyó («10» por «210»).
    static func seConfunden(_ a: Decimal, _ b: Decimal) -> Bool {
        let x = Array(centimos(a)), y = Array(centimos(b))
        if x.count == y.count {
            let distintas = x.indices.filter { x[$0] != y[$0] }
            guard distintas.count == 1, let i = distintas.first else { return false }
            return parecidas.contains(String([x[i], y[i]].sorted()))
        }
        let (corta, larga) = x.count < y.count ? (x, y) : (y, x)
        guard larga.count == corta.count + 1 else { return false }
        return larga.indices.contains { i in
            var sin = larga
            sin.remove(at: i)
            return sin == corta
        }
    }

    /// 819,00 → "81900": las cifras del importe en céntimos, sin separadores.
    private static func centimos(_ importe: Decimal) -> String {
        "\(Importe.redondear(importe) * 100)".split(separator: ".").first.map(String.init) ?? ""
    }
}
