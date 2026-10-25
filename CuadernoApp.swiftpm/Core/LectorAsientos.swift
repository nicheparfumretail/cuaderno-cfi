import Foundation

/// Una palabra leída del lienzo con su posición. `x` va de 0 (borde izquierdo) a 1 (borde derecho);
/// `y` y `alto` van en puntos del lienzo (y crece hacia abajo).
public struct PalabraLeida: Hashable, Sendable {
    public var texto: String
    public var x: Double
    public var y: Double
    public var alto: Double
    /// Otras lecturas del mismo trozo de tinta, de más a menos probable («819,00» si leyó «814,00»).
    public var alternativas: [String]
    /// El renglón de tinta al que pertenece, cuando los trazos se agruparon antes de leer.
    public var renglon: Int?

    public init(_ texto: String, x: Double, y: Double, alto: Double = 30,
                alternativas: [String] = [], renglon: Int? = nil) {
        self.texto = texto
        self.x = x
        self.y = y
        self.alto = alto
        self.alternativas = alternativas
        self.renglon = renglon
    }
}

/// Un asiento tal como se ha leído de la tinta: puede estar a medio escribir o no cuadrar.
public struct AsientoLeido: Hashable, Codable, Sendable {
    public var fecha: Fecha?
    public var apuntes: [Apunte] = []
    /// Filas con números que no se han podido convertir en apunte; se enseñan para corregirlas.
    public var noEntendido: [String] = []
    /// Lo escrito en el centro que no se ha podido leer como fecha (se elige a mano en el panel).
    public var fechaIlegible: [String] = []
    /// Lo deducido con la partida doble: una lectura corregida o el importe que haría cuadrar.
    public var pistas: [String] = []

    public init(fecha: Fecha? = nil, apuntes: [Apunte] = [], noEntendido: [String] = [],
                fechaIlegible: [String] = [], pistas: [String] = []) {
        self.fecha = fecha
        self.apuntes = apuntes
        self.noEntendido = noEntendido
        self.fechaIlegible = fechaIlegible
        self.pistas = pistas
    }

    private enum CodingKeys: String, CodingKey { case fecha, apuntes, noEntendido, fechaIlegible, pistas }

    /// Tolerante con hojas guardadas por versiones anteriores, que no tenían todos los campos.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fecha: try c.decodeIfPresent(Fecha.self, forKey: .fecha),
                  apuntes: try c.decodeIfPresent([Apunte].self, forKey: .apuntes) ?? [],
                  noEntendido: try c.decodeIfPresent([String].self, forKey: .noEntendido) ?? [],
                  fechaIlegible: try c.decodeIfPresent([String].self, forKey: .fechaIlegible) ?? [],
                  pistas: try c.decodeIfPresent([String].self, forKey: .pistas) ?? [])
    }

    /// Sin apuntes ni filas por corregir: no hay asiento (una raya de más, una fecha suelta).
    public var vacio: Bool { apuntes.isEmpty && noEntendido.isEmpty }

    /// El asiento solo existe si cumple las reglas del motor (partida doble incluida).
    public func asiento(empresa: String, numero: Int) -> Result<Asiento, Error> {
        Result {
            try Asiento(empresa: empresa, numero: numero, fecha: fecha ?? Fecha.hoy(),
                        concepto: "", apuntes: apuntes)
        }
    }
}

/// Lee asientos escritos en el formato de clase (apuntes de Gema):
///
///     Debe ____________ 01/12/24 ____________ Haber
///     1.000,00 Proveedores (400)    a    (572) Bancos 1.000,00
///
/// La zona izquierda es el Debe y la derecha el Haber: la posición dice el lado. Una raya
/// horizontal separa un asiento del siguiente; una fecha en el centro, también. En cada fila,
/// el código de la cuenta va entre paréntesis o pegado al centro, y el importe en el borde.
/// El nombre de la cuenta se ignora: manda el código.
///
/// Si un asiento no cuadra, la partida doble sirve de prueba: entre las otras lecturas de la
/// tinta se busca la que lo hace cuadrar (ver `cuadrar`).
public enum LectorAsientos {
    private struct Fila {
        let zona: ZonaPagina
        let palabras: [PalabraLeida]
        var y: Double { palabras.map(\.y).reduce(0, +) / Double(palabras.count) }
        var alto: Double { palabras.map(\.alto).max() ?? 0 }
        var texto: String { palabras.sorted { $0.x < $1.x }.map(\.texto).joined(separator: " ") }
        var lado: Lado { zona == .debe ? .debe : .haber }
    }

    /// Una fila del Debe o del Haber que no se ha podido leer como apunte.
    struct Fallida {
        let lado: Lado
        let cuenta: String?
    }

    /// Lo que se encuentra al bajar por la hoja: una fila de texto o una raya.
    private enum Evento {
        case fila(Fila, fecha: Fecha?)
        case raya
    }

    /// - Parameters:
    ///   - palabras: lo leído de la tinta, con `x` relativa al ancho de la página (0–1).
    ///   - separadores: altura de cada raya horizontal que separa asientos.
    ///   - zonas: dónde acaban el Debe y empieza el Haber.
    public static func leer(_ palabras: [PalabraLeida], separadores: [Double] = [],
                            zonas: Zonas = Zonas()) -> [AsientoLeido] {
        var eventos: [(altura: Double, orden: Int, evento: Evento)] = []
        for zona in [ZonaPagina.debe, .centro, .haber] {
            var grupos = agruparEnFilas(palabras.filter { zonas.zona(de: $0.x) == zona })
            if zona != .centro {
                grupos = unirRenglonesPartidos(grupos, lado: zona == .debe ? .debe : .haber, separadores: separadores)
            }
            for grupo in grupos {
                let fila = Fila(zona: zona, palabras: grupo)
                let fecha = zona == .centro ? lecturas(grupo).lazy.compactMap(fechaEscrita).first : nil
                // La fecha va en la raya, un poco por encima de sus apuntes: se adelanta un renglón
                // para que abra su asiento antes que las filas que tiene a la misma altura.
                let altura = fila.y - (fecha != nil ? fila.alto : 0)
                eventos.append((altura, zona.rawValue, .fila(fila, fecha: fecha)))
            }
        }
        for raya in separadores {
            eventos.append((raya, -1, .raya))
        }
        eventos.sort { $0.altura == $1.altura ? $0.orden < $1.orden : $0.altura < $1.altura }

        var asientos: [AsientoLeido] = []
        var actual = AsientoLeido()
        // Por cada apunte, las otras lecturas que dio la tinta; y las filas que no se entendieron.
        var dudas: [[Apunte]] = []
        var fallidas: [Fallida] = []
        func cerrar() {
            if actual.vacio {
                // Una fecha escrita justo encima de la raya sigue valiendo para el asiento de debajo.
                actual = AsientoLeido(fecha: actual.fecha)
            } else {
                asientos.append(enOrden(cuadrar(actual, dudas: dudas, fallidas: fallidas)))
                actual = AsientoLeido()
            }
            dudas = []
            fallidas = []
        }

        for (_, _, evento) in eventos {
            guard case let .fila(fila, fecha) = evento else {
                cerrar()
                continue
            }
            let texto = fila.texto
            if let fecha {
                if !actual.vacio { cerrar() }
                actual.fecha = fecha
                continue
            }
            // La primera lectura que es un apunte; las demás quedan como dudas para cuadrar.
            let opciones = fila.zona == .centro ? []
                : lecturas(fila.palabras).compactMap { apunte(en: numerico($0), lado: fila.lado) }
            if let elegido = opciones.first {
                actual.apuntes.append(elegido)
                dudas.append(opciones.filter { $0.cuenta == elegido.cuenta && $0.importe != elegido.importe })
                continue
            }
            // Filas sin números («Debe», «Haber», un título, la «a»): no son apuntes, se ignoran.
            guard texto.contains(where: { $0.isNumber }) else { continue }
            if fila.zona == .centro {
                actual.fechaIlegible.append(texto)
            } else {
                actual.noEntendido.append(texto)
                fallidas.append(Fallida(lado: fila.lado, cuenta: cuentaSinImporte(numerico(texto))))
            }
        }
        if !actual.vacio { asientos.append(enOrden(cuadrar(actual, dudas: dudas, fallidas: fallidas))) }
        return asientos
    }

    /// La lectura más probable de unas palabras y, detrás, las alternativas: cada una cambia un solo trozo.
    static func lecturas(_ palabras: [PalabraLeida]) -> [String] {
        let ordenadas = palabras.sorted { $0.x < $1.x }
        let textos = ordenadas.map(\.texto)
        var lista = [textos.joined(separator: " ")]
        for (i, palabra) in ordenadas.enumerated() {
            for alternativa in palabra.alternativas {
                var cambiados = textos
                cambiados[i] = alternativa
                let lectura = cambiados.joined(separator: " ")
                if !lista.contains(lectura) { lista.append(lectura) }
            }
        }
        return lista
    }

    /// Una fila que no es apunte pero sí trae una cuenta: le falta el importe o lo trae a cero.
    public static func cuentaSinImporte(_ texto: String) -> String? {
        var resto = texto
        if let codigo = extraerCodigoEntreParentesis(de: &resto) { return codigo }
        let numeros = trozosNumericos(texto)
        guard numeros.count >= 2, let primero = numeros.first, let ultimo = numeros.last else { return nil }
        for (codigo, otro) in [(ultimo, primero), (primero, ultimo)] where Cuenta(codigo) != nil {
            if (Importe.leer(otro) ?? 0) <= 0 { return codigo }
        }
        return nil
    }

    /// Un nombre largo («Compras de / mercaderías») ocupa dos renglones y la cuenta puede quedar en
    /// uno y el importe en el otro. Dos renglones seguidos que solos no son un apunte y juntos sí,
    /// son el mismo apunte, si están cerca y no hay una raya entre ellos. Los renglones sin cifras
    /// (el resto del nombre) no cuentan.
    private static func unirRenglonesPartidos(_ renglones: [[PalabraLeida]], lado: Lado,
                                              separadores: [Double]) -> [[PalabraLeida]] {
        let conCifras = renglones.filter { $0.contains { $0.texto.contains(where: { $0.isNumber }) } }
        func esApunte(_ palabras: [PalabraLeida]) -> Bool {
            lecturas(palabras).contains { apunte(en: numerico($0), lado: lado) != nil }
        }
        func centro(_ palabras: [PalabraLeida]) -> Double {
            palabras.map(\.y).reduce(0, +) / Double(palabras.count)
        }
        var resultado: [[PalabraLeida]] = []
        var i = 0
        while i < conCifras.count {
            let arriba = conCifras[i]
            if i + 1 < conCifras.count {
                let abajo = conCifras[i + 1]
                let (y1, y2) = (centro(arriba), centro(abajo))
                let alto = (arriba + abajo).map(\.alto).max() ?? 0
                let sinRaya = !separadores.contains { $0 > y1 && $0 < y2 }
                if sinRaya, y2 - y1 < alto * 2.5, !esApunte(arriba), !esApunte(abajo), esApunte(arriba + abajo) {
                    resultado.append(arriba + abajo)
                    i += 2
                    continue
                }
            }
            resultado.append(arriba)
            i += 1
        }
        return resultado
    }

    /// Una raya que separa asientos: un trazo largo (al menos una quinta parte de la página)
    /// y casi plano. Las palabras, aunque sean largas, se escriben con trazos cortos.
    public static func esSeparador(ancho: Double, alto: Double, anchoPagina: Double) -> Bool {
        ancho >= anchoPagina * 0.2 && alto <= max(24, ancho * 0.08)
    }

    /// Como en el cuaderno: primero los apuntes del Debe y después los del Haber.
    private static func enOrden(_ leido: AsientoLeido) -> AsientoLeido {
        var ordenado = leido
        ordenado.apuntes = leido.apuntes.filter { $0.lado == .debe } + leido.apuntes.filter { $0.lado == .haber }
        return ordenado
    }

    /// Agrupa en filas las palabras cuya altura se solapa. Si ya vienen con su renglón de tinta,
    /// manda el renglón.
    private static func agruparEnFilas(_ palabras: [PalabraLeida]) -> [[PalabraLeida]] {
        var filas = Array(Dictionary(grouping: palabras.filter { $0.renglon != nil }, by: { $0.renglon ?? 0 }).values)
        let porRenglon = filas.count
        for palabra in palabras.filter({ $0.renglon == nil }).sorted(by: { $0.y < $1.y }) {
            if filas.count > porRenglon, let ultima = filas.last {
                let centro = ultima.map(\.y).reduce(0, +) / Double(ultima.count)
                let tolerancia = max(ultima.map(\.alto).max() ?? 0, palabra.alto) * 0.6
                if abs(palabra.y - centro) < tolerancia {
                    filas[filas.count - 1].append(palabra)
                    continue
                }
            }
            filas.append([palabra])
        }
        func centro(_ fila: [PalabraLeida]) -> Double { fila.map(\.y).reduce(0, +) / Double(fila.count) }
        return filas.sorted { centro($0) < centro($1) }
    }

    /// La fecha del centro (ver `FechaEscrita`), con las confusiones de la letra ya corregidas.
    static func fechaEscrita(_ texto: String) -> Fecha? {
        FechaEscrita.leer(numerico(texto))
    }

    /// "1.000,00 Proveedores (400)" → Debe 400 por 1.000. Sin código o sin importe, no hay apunte.
    static func apunte(en texto: String, lado: Lado) -> Apunte? {
        var resto = texto
        if let codigo = extraerCodigoEntreParentesis(de: &resto) {
            guard let grupos = buscar(#"\d{1,3}(?:\s?\.\s?\d{3})+(?:\s?,\s?\d{1,2})?|\d+\s?,\s?\d{1,2}|\d+"#, en: resto)?.grupos,
                  let importe = Importe.leer(grupos[0].replacingOccurrences(of: " ", with: "")),
                  importe > 0 else { return nil }
            return Apunte(lado, codigo, importe)
        }
        // Sin paréntesis manda la posición, como en el formato de clase: el código va pegado al
        // centro (último número en el Debe, primero en el Haber) y el importe, en el borde de fuera.
        let numeros = trozosNumericos(texto)
        guard numeros.count >= 2, let primero = numeros.first, let ultimo = numeros.last else { return nil }
        let (codigo, textoImporte) = lado == .debe ? (ultimo, primero) : (primero, ultimo)
        guard Cuenta(codigo) != nil, let importe = Importe.leer(textoImporte), importe > 0 else { return nil }
        return Apunte(lado, codigo, importe)
    }

    /// Código entre paréntesis «(400)», o solo con el de cierre «400)» si el de apertura no se leyó.
    /// Lo quita del texto para que no se lea como importe.
    private static func extraerCodigoEntreParentesis(de texto: inout String) -> String? {
        let patrones = [
            #"[(\[{<]\s*(\d{3,}(?:\.\d+)?)\s*[)\]}>]?"#,
            #"(\d{3,}(?:\.\d+)?)\s*[)\]}>]"#,
        ]
        for patron in patrones {
            if let m = buscar(patron, en: texto), Cuenta(m.grupos[1]) != nil {
                texto.removeSubrange(m.rango)
                return m.grupos[1]
            }
        }
        return nil
    }

    /// Los números de la fila, en orden. Une los trozos que Vision separa («1.000,» «00»).
    static func trozosNumericos(_ texto: String) -> [String] {
        var trozos: [String] = []
        var seguido = false
        for palabra in texto.split(separator: " ").map(String.init) {
            guard palabra.contains(where: { $0.isNumber }) || palabra == "," || palabra == "." else {
                seguido = false
                continue
            }
            if seguido, let anterior = trozos.last,
               anterior.hasSuffix(",") || anterior.hasSuffix(".") || palabra.hasPrefix(",") || palabra.hasPrefix(".") {
                trozos[trozos.count - 1] += palabra
            } else {
                trozos.append(palabra)
            }
            seguido = true
        }
        return trozos.map { $0.filter { "0123456789.,".contains($0) } }.filter { !$0.isEmpty }
    }

    /// Confusiones típicas de la letra a mano dentro de una palabra con cifras:
    /// O → 0, l/I/| → 1, S → 5, Z → 2. Las palabras sin cifras («Bancos») no se tocan.
    static func numerico(_ texto: String) -> String {
        texto.split(separator: " ", omittingEmptySubsequences: false).map { palabra -> String in
            guard palabra.contains(where: { $0.isNumber }) else { return String(palabra) }
            return String(palabra.map { letra -> Character in
                switch letra {
                case "O", "o": return "0"
                case "l", "I", "|": return "1"
                case "S", "s": return "5"
                case "Z", "z": return "2"
                default: return letra
                }
            })
        }.joined(separator: " ")
    }

    /// Primera coincidencia del patrón: su rango y sus grupos (el 0 es la coincidencia entera).
    private struct Coincidencia {
        let rango: Range<String.Index>
        let grupos: [String]
    }

    private static func buscar(_ patron: String, en texto: String) -> Coincidencia? {
        guard let regex = try? NSRegularExpression(pattern: patron),
              let resultado = regex.firstMatch(in: texto, range: NSRange(texto.startIndex..., in: texto)),
              let rango = Range(resultado.range, in: texto) else { return nil }
        let grupos = (0..<resultado.numberOfRanges).map { i -> String in
            Range(resultado.range(at: i), in: texto).map { String(texto[$0]) } ?? ""
        }
        return Coincidencia(rango: rango, grupos: grupos)
    }
}
