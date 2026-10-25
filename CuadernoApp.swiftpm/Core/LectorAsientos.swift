import Foundation

/// Una palabra leída del lienzo con su posición. `x` va de 0 (borde izquierdo) a 1 (borde derecho);
/// `y` y `alto` van en puntos del lienzo (y crece hacia abajo).
public struct PalabraLeida: Hashable, Sendable {
    public var texto: String
    public var x: Double
    public var y: Double
    public var alto: Double

    public init(_ texto: String, x: Double, y: Double, alto: Double = 30) {
        self.texto = texto
        self.x = x
        self.y = y
        self.alto = alto
    }
}

/// Un asiento tal como se ha leído de la tinta: puede estar a medio escribir o no cuadrar.
public struct AsientoLeido: Hashable, Sendable {
    public var fecha: Fecha?
    public var apuntes: [Apunte] = []
    /// Filas con números que no se han podido convertir en apunte; se enseñan para corregirlas.
    public var noEntendido: [String] = []

    public init(fecha: Fecha? = nil, apuntes: [Apunte] = [], noEntendido: [String] = []) {
        self.fecha = fecha
        self.apuntes = apuntes
        self.noEntendido = noEntendido
    }

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
/// La mitad izquierda es el Debe y la derecha el Haber: la posición dice el lado.
/// La fecha, en el centro, abre cada asiento. En cada fila, el código de la cuenta va entre
/// paréntesis y el importe es el número que queda. El nombre de la cuenta se ignora: manda el código.
public enum LectorAsientos {
    /// Ancho de la franja central (fecha y «a»), a cada lado de la mitad del lienzo.
    public static let margenCentro = 0.08

    private enum Zona: Int { case debe, centro, haber }

    private struct Fila {
        let zona: Zona
        let palabras: [PalabraLeida]
        var y: Double { palabras.map(\.y).reduce(0, +) / Double(palabras.count) }
        var alto: Double { palabras.map(\.alto).max() ?? 0 }
        var texto: String { palabras.sorted { $0.x < $1.x }.map(\.texto).joined(separator: " ") }
    }

    public static func leer(_ palabras: [PalabraLeida]) -> [AsientoLeido] {
        var filas: [(fila: Fila, fecha: Fecha?)] = []
        for zona in [Zona.debe, .centro, .haber] {
            for grupo in agruparEnFilas(palabras.filter { self.zona(de: $0) == zona }) {
                let fila = Fila(zona: zona, palabras: grupo)
                let fecha = zona == .centro ? self.fecha(en: numerico(fila.texto)) : nil
                filas.append((fila, fecha))
            }
        }
        // La fecha va en la raya, un poco por encima de sus apuntes: se adelanta medio renglón
        // para que abra su asiento antes que las filas que tiene a la misma altura.
        filas.sort { a, b in
            let ya = a.fila.y - (a.fecha != nil ? a.fila.alto : 0)
            let yb = b.fila.y - (b.fecha != nil ? b.fila.alto : 0)
            return ya == yb ? a.fila.zona.rawValue < b.fila.zona.rawValue : ya < yb
        }

        var asientos: [AsientoLeido] = []
        var actual: AsientoLeido?
        for (fila, fecha) in filas {
            let texto = fila.texto
            // Filas sin números («Debe», «Haber», un título): no son apuntes, se ignoran.
            guard texto.contains(where: { $0.isNumber }) else { continue }
            if let fecha {
                if let anterior = actual { asientos.append(enOrden(anterior)) }
                actual = AsientoLeido(fecha: fecha)
                continue
            }
            var asiento = actual ?? AsientoLeido()
            if fila.zona != .centro,
               let nuevo = apunte(en: numerico(texto), lado: fila.zona == .debe ? .debe : .haber) {
                asiento.apuntes.append(nuevo)
            } else {
                asiento.noEntendido.append(texto)
            }
            actual = asiento
        }
        if let ultimo = actual { asientos.append(enOrden(ultimo)) }
        return asientos
    }

    /// Como en el cuaderno: primero los apuntes del Debe y después los del Haber.
    private static func enOrden(_ leido: AsientoLeido) -> AsientoLeido {
        var ordenado = leido
        ordenado.apuntes = leido.apuntes.filter { $0.lado == .debe } + leido.apuntes.filter { $0.lado == .haber }
        return ordenado
    }

    private static func zona(de palabra: PalabraLeida) -> Zona {
        if palabra.x < 0.5 - margenCentro { return .debe }
        if palabra.x > 0.5 + margenCentro { return .haber }
        return .centro
    }

    /// Agrupa en filas las palabras cuya altura se solapa.
    private static func agruparEnFilas(_ palabras: [PalabraLeida]) -> [[PalabraLeida]] {
        var filas: [[PalabraLeida]] = []
        for palabra in palabras.sorted(by: { $0.y < $1.y }) {
            if let ultima = filas.last {
                let centro = ultima.map(\.y).reduce(0, +) / Double(ultima.count)
                let tolerancia = max(ultima.map(\.alto).max() ?? 0, palabra.alto) * 0.6
                if abs(palabra.y - centro) < tolerancia {
                    filas[filas.count - 1].append(palabra)
                    continue
                }
            }
            filas.append([palabra])
        }
        return filas
    }

    /// "01/12/24", "01 / 12 / 2024", "1-12-24"
    static func fecha(en texto: String) -> Fecha? {
        guard let grupos = buscar(#"(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{2,4})"#, en: texto)?.grupos,
              let dia = Int(grupos[1]), let mes = Int(grupos[2]), var año = Int(grupos[3]) else { return nil }
        if año < 100 { año += 2000 }
        return Fecha(año: año, mes: mes, dia: dia)
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
