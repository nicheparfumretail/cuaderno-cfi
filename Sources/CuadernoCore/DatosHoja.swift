import Foundation

/// Dónde acaba el Debe y empieza el Haber, en proporción al ancho de la página (0–1).
/// Entre los dos queda la franja central: la fecha y la «a».
public struct Zonas: Codable, Hashable, Sendable {
    public static let anchoMinimoCentro = 0.06

    public var finDebe: Double
    public var inicioHaber: Double

    public init(finDebe: Double = 0.42, inicioHaber: Double = 0.58) {
        self.finDebe = finDebe
        self.inicioHaber = inicioHaber
    }

    /// Mueve el borde del Debe sin que las zonas se crucen ni desaparezcan.
    public func moviendo(finDebe nuevo: Double) -> Zonas {
        Zonas(finDebe: min(max(nuevo, 0.15), inicioHaber - Zonas.anchoMinimoCentro), inicioHaber: inicioHaber)
    }

    /// Mueve el borde del Haber sin que las zonas se crucen ni desaparezcan.
    public func moviendo(inicioHaber nuevo: Double) -> Zonas {
        Zonas(finDebe: finDebe, inicioHaber: max(min(nuevo, 0.85), finDebe + Zonas.anchoMinimoCentro))
    }
}

/// Un asiento de la hoja con su número, su fecha y su concepto ya decididos.
public struct AsientoResuelto: Identifiable {
    public let numero: Int
    public let fecha: Fecha
    public let fechaPuestaAMano: Bool
    public let concepto: String
    /// Lo leído de la tinta, con las correcciones hechas en el panel ya aplicadas.
    public let leido: AsientoLeido
    /// Los apuntes como se enseñan: cada uno sabe de qué lectura sale y si está corregido.
    public let lineas: [LineaAsiento]
    /// Cuántas cosas leídas se han descartado a mano en este asiento.
    public let descartadas: Int
    /// El asiento, si cumple la partida doble; si no, el error con la diferencia.
    public let resultado: Result<Asiento, Error>
    /// Avisos de estudio que no impiden el asiento (por ejemplo, en la apertura).
    public let avisos: [String]
    /// Qué falta o no se ha entendido, como recomendación: nunca bloquea la escritura.
    public let sugerencias: [String]

    public var id: Int { numero }
    public var asiento: Asiento? { try? resultado.get() }
}

/// Lo que acompaña a la tinta de una hoja: si empieza con la apertura, las fechas puestas a mano
/// y las zonas Debe | centro | Haber.
public struct DatosHoja: Codable, Hashable, Sendable {
    public var esApertura: Bool
    public var fechaInicial: Fecha
    /// Fecha elegida a mano para un asiento, por su posición en la hoja (0 = el primero).
    public var fechasManuales: [Int: Fecha]
    public var zonas: Zonas
    /// Apuntes corregidos a mano en el panel.
    public var correcciones: [Correccion]

    public init(esApertura: Bool, fechaInicial: Fecha, fechasManuales: [Int: Fecha] = [:], zonas: Zonas = Zonas(),
                correcciones: [Correccion] = []) {
        self.esApertura = esApertura
        self.fechaInicial = fechaInicial
        self.fechasManuales = fechasManuales
        self.zonas = zonas
        self.correcciones = correcciones
    }

    private enum CodingKeys: String, CodingKey { case esApertura, fechaInicial, fechasManuales, zonas, correcciones }

    /// Tolerante con hojas guardadas por versiones anteriores, que no tenían todos los campos.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(esApertura: try c.decode(Bool.self, forKey: .esApertura),
                  fechaInicial: try c.decode(Fecha.self, forKey: .fechaInicial),
                  fechasManuales: try c.decodeIfPresent([Int: Fecha].self, forKey: .fechasManuales) ?? [:],
                  zonas: try c.decodeIfPresent(Zonas.self, forKey: .zonas) ?? Zonas(),
                  correcciones: try c.decodeIfPresent([Correccion].self, forKey: .correcciones) ?? [])
    }

    /// Numera los asientos leídos y decide su fecha: la puesta a mano; si no, la escrita y leída;
    /// si no, la del asiento anterior («si sigo con el mismo día, el programa lo entiende»).
    public func resolver(_ leidos: [AsientoLeido], empresa: String) -> [AsientoResuelto] {
        var anterior = fechaInicial
        return leidos.enumerated().map { indice, tinta in
            let (leido, lineas, descartadas) = aplicandoCorrecciones(a: tinta, asiento: indice)
            let manual = fechasManuales[indice]
            let fecha = manual ?? leido.fecha ?? anterior
            anterior = fecha
            let numero = indice + 1
            let apertura = esApertura && indice == 0
            let concepto = apertura ? "Asiento de apertura" : ""
            let resultado = Result<Asiento, Error> {
                try Asiento(empresa: empresa, numero: numero, fecha: fecha, concepto: concepto, apuntes: leido.apuntes)
            }
            return AsientoResuelto(numero: numero, fecha: fecha, fechaPuestaAMano: manual != nil,
                                   concepto: concepto, leido: leido, lineas: lineas, descartadas: descartadas,
                                   resultado: resultado,
                                   avisos: apertura ? DatosHoja.avisosApertura(leido.apuntes) : [],
                                   sugerencias: DatosHoja.sugerencias(leido))
        }
    }

    /// Pistas de lo que falta en un asiento a medio escribir o mal leído.
    public static func sugerencias(_ leido: AsientoLeido) -> [String] {
        var lista: [String] = []
        for fila in leido.noEntendido {
            if let cuenta = LectorAsientos.cuentaSinImporte(LectorAsientos.numerico(fila)) {
                lista.append("En «\(fila)» leo la cuenta \(cuenta) pero no un importe: repasa las cifras del borde.")
            } else if LectorAsientos.trozosNumericos(LectorAsientos.numerico(fila)).count < 2 {
                lista.append("En «\(fila)» solo leo un número: la cuenta va pegada al centro y el importe en el borde.")
            } else {
                lista.append("En «\(fila)» no encuentro una cuenta válida (3 cifras o más, sin empezar por 0).")
            }
        }
        for texto in leido.fechaIlegible {
            lista.append("En el centro leo «\(texto)» y no es una fecha: elígela con el selector de fecha.")
        }
        lista += leido.pistas
        let hayDebe = leido.apuntes.contains { $0.lado == .debe }
        let hayHaber = leido.apuntes.contains { $0.lado == .haber }
        if hayDebe && !hayHaber {
            lista.append("Falta el Haber: escribe a la derecha la cuenta y el importe.")
        }
        if hayHaber && !hayDebe {
            lista.append("Falta el Debe: escribe a la izquierda el importe y la cuenta.")
        }
        return lista
    }

    /// El asiento de apertura vuelve a abrir los saldos del balance: solo lleva cuentas de balance
    /// (grupos 1 a 5). Una cuenta de gastos o ingresos en la apertura es un error de concepto.
    public static func avisosApertura(_ apuntes: [Apunte]) -> [String] {
        Set(apuntes.map(\.cuenta)).sorted().compactMap { codigo in
            guard let cuenta = Cuenta(codigo), cuenta.grupo >= 6 else { return nil }
            return "La apertura solo lleva cuentas de balance (grupos 1 a 5): la \(codigo) es del grupo \(cuenta.grupo)."
        }
    }
}
