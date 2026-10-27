import Foundation

/// Un apunte corregido a mano desde el panel, para cuando la tinta se lee mal y no compensa
/// reescribirla. Se guarda junto a lo que se leyó: si se reescribe la tinta y se lee otra cosa,
/// la corrección deja de aplicarse sola.
public struct Correccion: Codable, Hashable, Sendable {
    /// Lo que se leyó de la tinta: un apunte, o una fila que no se entendió.
    public enum Leido: Codable, Hashable, Sendable {
        case apunte(Apunte)
        case fila(String)
    }

    /// Posición del asiento en la hoja (0 = el primero), como las fechas puestas a mano.
    public var asiento: Int
    public var leido: Leido
    /// Lo bueno. Sin apunte, lo leído se descarta (una mancha que no era nada).
    public var apunte: Apunte?
    /// El asiento al que se ha arrastrado el apunte. Sin destino, se queda en el suyo.
    public var destino: Int?

    public init(asiento: Int, leido: Leido, apunte: Apunte?, destino: Int? = nil) {
        self.asiento = asiento
        self.leido = leido
        self.apunte = apunte
        self.destino = destino
    }
}

/// Un apunte tal como se enseña en el panel: lo que vale y de dónde sale.
public struct LineaAsiento: Hashable, Sendable {
    public let apunte: Apunte
    public let leido: Correccion.Leido
    public let corregida: Bool
    /// El asiento donde se leyó: su corrección se guarda ahí aunque se haya arrastrado a otro.
    public let origen: Int
}

extension DatosHoja {
    /// Corrige (o descarta, con `apunte` nil) algo leído en un asiento. Sustituye la corrección
    /// anterior de lo mismo; si se había arrastrado a otro asiento, sigue allí.
    public mutating func corregir(asiento: Int, leido: Correccion.Leido, por apunte: Apunte?) {
        let destino = correcciones.first { $0.asiento == asiento && $0.leido == leido }?.destino
        quitarCorreccion(asiento: asiento, leido: leido)
        correcciones.append(Correccion(asiento: asiento, leido: leido, apunte: apunte, destino: destino))
    }

    /// Lleva un apunte a otro asiento (o al otro lado del mismo): queda como `apunte` en `destino`.
    public mutating func mover(asiento: Int, leido: Correccion.Leido, apunte: Apunte, a destino: Int) {
        quitarCorreccion(asiento: asiento, leido: leido)
        correcciones.append(Correccion(asiento: asiento, leido: leido, apunte: apunte,
                                       destino: destino == asiento ? nil : destino))
    }

    /// Vuelve a lo leído de la tinta (y a su asiento, si se había arrastrado).
    public mutating func quitarCorreccion(asiento: Int, leido: Correccion.Leido) {
        correcciones.removeAll { $0.asiento == asiento && $0.leido == leido }
    }

    /// Vuelven las líneas descartadas de un asiento.
    public mutating func recuperarDescartadas(asiento: Int) {
        correcciones.removeAll { $0.asiento == asiento && $0.apunte == nil }
    }

    /// Lo leído de cada asiento con sus correcciones aplicadas, y con los apuntes arrastrados de
    /// un asiento a otro ya en su sitio. Las pistas de la lectura se quitan de un asiento que se
    /// ha tocado a mano: hablaban de lo leído, no de lo corregido.
    func aplicandoCorrecciones(a leidos: [AsientoLeido])
        -> [(leido: AsientoLeido, lineas: [LineaAsiento], descartadas: Int)] {
        var resultado: [(leido: AsientoLeido, lineas: [LineaAsiento], descartadas: Int)] = []
        var llegan: [Int: [LineaAsiento]] = [:]
        var tocados = Set<Int>()

        for (indice, leido) in leidos.enumerated() {
            let mias = correcciones.filter { $0.asiento == indice }
            var usadas = Set<Int>()
            func correccion(de leido: Correccion.Leido) -> Correccion? {
                guard let i = mias.indices.first(where: { !usadas.contains($0) && mias[$0].leido == leido }) else { return nil }
                usadas.insert(i)
                return mias[i]
            }

            var lineas: [LineaAsiento] = []
            var descartadas = 0
            /// Lo corregido se queda aquí o se va al asiento al que se arrastró.
            func colocar(_ hecha: Correccion, leido: Correccion.Leido) {
                guard let nuevo = hecha.apunte else { return descartadas += 1 }
                let linea = LineaAsiento(apunte: nuevo, leido: leido, corregida: true, origen: indice)
                if let destino = hecha.destino, destino < leidos.count, destino != indice {
                    llegan[destino, default: []].append(linea)
                    tocados.insert(destino)
                } else {
                    lineas.append(linea)
                }
            }
            for apunte in leido.apuntes {
                if let hecha = correccion(de: .apunte(apunte)) {
                    colocar(hecha, leido: .apunte(apunte))
                } else {
                    lineas.append(LineaAsiento(apunte: apunte, leido: .apunte(apunte), corregida: false, origen: indice))
                }
            }
            var noEntendido: [String] = []
            for fila in leido.noEntendido {
                if let hecha = correccion(de: .fila(fila)) {
                    colocar(hecha, leido: .fila(fila))
                } else {
                    noEntendido.append(fila)
                }
            }
            if !usadas.isEmpty { tocados.insert(indice) }
            var corregido = leido
            corregido.noEntendido = noEntendido
            resultado.append((corregido, lineas, descartadas))
        }

        for indice in resultado.indices {
            // Como en el cuaderno: primero el Debe y después el Haber.
            let todas = resultado[indice].lineas + (llegan[indice] ?? [])
            let lineas = todas.filter { $0.apunte.lado == .debe } + todas.filter { $0.apunte.lado == .haber }
            resultado[indice].lineas = lineas
            resultado[indice].leido.apuntes = lineas.map(\.apunte)
            if tocados.contains(indice) { resultado[indice].leido.pistas = [] }
        }
        return resultado
    }
}
