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

    public init(asiento: Int, leido: Leido, apunte: Apunte?) {
        self.asiento = asiento
        self.leido = leido
        self.apunte = apunte
    }
}

/// Un apunte tal como se enseña en el panel: lo que vale y de dónde sale.
public struct LineaAsiento: Hashable, Sendable {
    public let apunte: Apunte
    public let leido: Correccion.Leido
    public let corregida: Bool
}

extension DatosHoja {
    /// Corrige (o descarta, con `apunte` nil) algo leído en un asiento. Sustituye la corrección
    /// anterior de lo mismo.
    public mutating func corregir(asiento: Int, leido: Correccion.Leido, por apunte: Apunte?) {
        quitarCorreccion(asiento: asiento, leido: leido)
        correcciones.append(Correccion(asiento: asiento, leido: leido, apunte: apunte))
    }

    /// Vuelve a lo leído de la tinta.
    public mutating func quitarCorreccion(asiento: Int, leido: Correccion.Leido) {
        correcciones.removeAll { $0.asiento == asiento && $0.leido == leido }
    }

    /// Vuelven las líneas descartadas de un asiento.
    public mutating func recuperarDescartadas(asiento: Int) {
        correcciones.removeAll { $0.asiento == asiento && $0.apunte == nil }
    }

    /// Lo leído de un asiento con sus correcciones aplicadas. Las pistas de la lectura se quitan
    /// si se ha corregido algo: hablaban de lo leído, no de lo corregido.
    func aplicandoCorrecciones(a leido: AsientoLeido, asiento indice: Int)
        -> (leido: AsientoLeido, lineas: [LineaAsiento], descartadas: Int) {
        let mias = correcciones.filter { $0.asiento == indice }
        var usadas = Set<Int>()
        func correccion(de leido: Correccion.Leido) -> Correccion? {
            guard let i = mias.indices.first(where: { !usadas.contains($0) && mias[$0].leido == leido }) else { return nil }
            usadas.insert(i)
            return mias[i]
        }

        var lineas: [LineaAsiento] = []
        var descartadas = 0
        for apunte in leido.apuntes {
            if let hecha = correccion(de: .apunte(apunte)) {
                if let nuevo = hecha.apunte {
                    lineas.append(LineaAsiento(apunte: nuevo, leido: .apunte(apunte), corregida: true))
                } else {
                    descartadas += 1
                }
            } else {
                lineas.append(LineaAsiento(apunte: apunte, leido: .apunte(apunte), corregida: false))
            }
        }
        var noEntendido: [String] = []
        for fila in leido.noEntendido {
            if let hecha = correccion(de: .fila(fila)) {
                if let nuevo = hecha.apunte {
                    lineas.append(LineaAsiento(apunte: nuevo, leido: .fila(fila), corregida: true))
                } else {
                    descartadas += 1
                }
            } else {
                noEntendido.append(fila)
            }
        }
        // Como en el cuaderno: primero el Debe y después el Haber.
        lineas = lineas.filter { $0.apunte.lado == .debe } + lineas.filter { $0.apunte.lado == .haber }

        var corregido = leido
        corregido.apuntes = lineas.map(\.apunte)
        corregido.noEntendido = noEntendido
        if !usadas.isEmpty { corregido.pistas = [] }
        return (corregido, lineas, descartadas)
    }
}
