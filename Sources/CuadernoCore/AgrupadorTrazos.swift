import Foundation

/// Las tres franjas de la página, de izquierda a derecha.
public enum ZonaPagina: Int, Hashable, Sendable {
    case debe, centro, haber
}

extension Zonas {
    /// En qué franja cae una posición horizontal (0–1).
    public func zona(de x: Double) -> ZonaPagina {
        if x < finDebe { return .debe }
        if x > inicioHaber { return .haber }
        return .centro
    }
}

/// La caja de un trazo en puntos de la página (y crece hacia abajo).
public struct CajaTrazo: Hashable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public var midX: Double { (minX + maxX) / 2 }
    public var midY: Double { (minY + maxY) / 2 }
    public var ancho: Double { maxX - minX }
    public var alto: Double { maxY - minY }

    func uniendo(_ otra: CajaTrazo) -> CajaTrazo {
        CajaTrazo(minX: min(minX, otra.minX), minY: min(minY, otra.minY),
                  maxX: max(maxX, otra.maxX), maxY: max(maxY, otra.maxY))
    }
}

/// Un renglón escrito en una franja: los trazos que lo forman.
public struct RenglonTrazos: Hashable, Sendable {
    public let zona: ZonaPagina
    /// Posición de cada trazo en la lista de entrada.
    public let indices: [Int]
    public let caja: CajaTrazo
    /// Centro horizontal de sus trazos, de 0 a 1: siempre cae dentro de su franja.
    public let x: Double
    /// Altura del renglón: la media de sus trazos con cuerpo, sin comas ni puntos.
    public let y: Double
    /// Los trozos del renglón separados por un hueco (el importe, el nombre, el código), de
    /// izquierda a derecha. Cada trozo se lee aparte: un número suelto se lee mejor solo que
    /// con un hueco grande en medio.
    public let trozos: [[Int]]
}

/// Decide qué trazos forman cada renglón antes de leer nada, con la geometría de la tinta.
///
/// Así cada renglón se lee por separado: retocar una cifra solo cambia ese renglón, y una
/// línea que Vision lea de punta a punta ya no reparte mal las palabras entre el Debe y el Haber.
public enum AgrupadorTrazos {
    public static func renglones(_ cajas: [CajaTrazo], anchoPagina: Double, zonas: Zonas) -> [RenglonTrazos] {
        guard !cajas.isEmpty else { return [] }
        let letra = alturaDeLetra(cajas)
        func conCuerpo(_ i: Int) -> Bool { max(cajas[i].alto, cajas[i].ancho) >= letra * 0.4 }

        var resultado: [RenglonTrazos] = []
        for zona in [ZonaPagina.debe, .centro, .haber] {
            // De izquierda a derecha, como se escribe: un renglón algo torcido se sigue igual.
            let indices = cajas.indices
                .filter { zonas.zona(de: cajas[$0].midX / anchoPagina) == zona }
                .sorted { cajas[$0].minX < cajas[$1].minX }

            var grupos: [[Int]] = []
            for i in indices {
                // Se compara con los últimos trazos con cuerpo de cada renglón: su altura «local».
                let cercano = grupos.indices
                    .map { ($0, abs(cajas[i].midY - alturaLocal(grupos[$0], cajas, conCuerpo))) }
                    .filter { $0.1 < letra * 0.75 }
                    .min { $0.1 < $1.1 }
                if let cercano {
                    grupos[cercano.0].append(i)
                } else {
                    grupos.append([i])
                }
            }
            grupos = unirSueltos(grupos, cajas, letra: letra, conCuerpo: conCuerpo)

            for grupo in grupos {
                let caja = grupo.dropFirst().reduce(cajas[grupo[0]]) { $0.uniendo(cajas[$1]) }
                let conAltura = grupo.filter(conCuerpo)
                let base = conAltura.isEmpty ? grupo : conAltura
                let ordenados = grupo.sorted { cajas[$0].minX < cajas[$1].minX }
                resultado.append(RenglonTrazos(
                    zona: zona, indices: ordenados, caja: caja,
                    x: grupo.map { cajas[$0].midX }.reduce(0, +) / Double(grupo.count) / anchoPagina,
                    y: base.map { cajas[$0].midY }.reduce(0, +) / Double(base.count),
                    trozos: trocear(ordenados, cajas, hueco: letra)))
            }
        }
        return resultado.sorted { $0.y == $1.y ? $0.zona.rawValue < $1.zona.rawValue : $0.y < $1.y }
    }

    /// Corta el renglón donde hay un hueco de más de `hueco` entre lo escrito hasta ahí y el
    /// siguiente trazo. Entre las cifras de un número no hay tanto hueco.
    private static func trocear(_ ordenados: [Int], _ cajas: [CajaTrazo], hueco: Double) -> [[Int]] {
        var trozos: [[Int]] = []
        var finTrozo = -Double.infinity
        for i in ordenados {
            if trozos.isEmpty || cajas[i].minX - finTrozo > hueco {
                trozos.append([i])
                finTrozo = cajas[i].maxX
            } else {
                trozos[trozos.count - 1].append(i)
                finTrozo = max(finTrozo, cajas[i].maxX)
            }
        }
        return trozos
    }

    /// La altura típica de una cifra escrita: la mediana de los trazos, sin puntos ni comas.
    static func alturaDeLetra(_ cajas: [CajaTrazo]) -> Double {
        let altos = cajas.map(\.alto).filter { $0 >= 6 }.sorted()
        guard !altos.isEmpty else { return 30 }
        return max(altos[altos.count / 2], 12)
    }

    private static func alturaLocal(_ grupo: [Int], _ cajas: [CajaTrazo], _ conCuerpo: (Int) -> Bool) -> Double {
        let utiles = grupo.filter(conCuerpo)
        let ultimos = (utiles.isEmpty ? grupo : utiles).suffix(3)
        return ultimos.map { cajas[$0].midY }.reduce(0, +) / Double(ultimos.count)
    }

    /// Un punto o una coma que han quedado solos (el punto de una «i», una coma baja) van con
    /// el renglón más cercano: solos no se leen como nada.
    private static func unirSueltos(_ grupos: [[Int]], _ cajas: [CajaTrazo], letra: Double,
                                    conCuerpo: (Int) -> Bool) -> [[Int]] {
        var conTexto = grupos.filter { $0.contains(where: conCuerpo) }
        guard !conTexto.isEmpty else { return grupos }
        for suelto in grupos where !suelto.contains(where: conCuerpo) {
            let y = suelto.map { cajas[$0].midY }.reduce(0, +) / Double(suelto.count)
            let (g, distancia) = conTexto.indices
                .map { ($0, abs(y - alturaLocal(conTexto[$0], cajas, conCuerpo))) }
                .min { $0.1 < $1.1 }!
            if distancia < letra * 1.2 {
                conTexto[g] += suelto
            } else {
                conTexto.append(suelto)
            }
        }
        return conTexto
    }
}
