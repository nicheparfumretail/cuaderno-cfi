import Foundation

/// El nombre escrito de la cuenta como segunda prueba del código. En el cuaderno cada apunte
/// lleva el código y el nombre: si Vision lee «(608)» pero al lado pone «mercaderías», el
/// código que encaja con lo escrito es el 600 (Compras de mercaderías), no el 608
/// (Devoluciones de compras).
enum NombreCuenta {
    /// Palabras de los nombres del PGC que no distinguen una cuenta de otra.
    private static let vacias: Set<String> = ["otros", "otras", "sobre", "para", "operaciones", "similares", "cuenta"]

    /// Entre el código leído, las otras lecturas y los códigos a una cifra parecida, el que
    /// mejor encaja con el nombre escrito. Solo si encaja mejor que el leído y sin empate.
    static func mejorCodigo(leido: String, otros: [String], texto: String) -> String? {
        let base = coincidencias(leido, en: texto)
        let candidatos = Set(otros + variantes(de: leido)).subtracting([leido])
        let mejores = candidatos.map { ($0, coincidencias($0, en: texto)) }.filter { $0.1 > base }
        guard let maximo = mejores.map(\.1).max() else { return nil }
        let ganadores = mejores.filter { $0.1 == maximo }
        return ganadores.count == 1 ? ganadores[0].0 : nil
    }

    /// Cuántas palabras del nombre de la cuenta en el PGC aparecen, más o menos bien escritas,
    /// en lo leído. Una cuenta sin nombre en la tabla no suma nada.
    static func coincidencias(_ codigo: String, en texto: String) -> Int {
        guard let nombre = PlanDeCuentas.nombre(de: codigo) else { return 0 }
        let escritas = palabras(texto)
        return palabras(nombre).filter { !vacias.contains($0) }
            .filter { palabra in escritas.contains { seParecen($0, palabra) } }
            .count
    }

    /// Los códigos del PGC a una cifra parecida (4 y 9, 0 y 8…) del leído.
    static func variantes(de codigo: String) -> [String] {
        let cifras = Array(codigo)
        var lista: [String] = []
        for i in cifras.indices where cifras[i].isASCIIDigit {
            for par in LectorAsientos.parecidas where par.contains(cifras[i]) {
                guard let otra = par.first(where: { $0 != cifras[i] }) else { continue }
                var nueva = cifras
                nueva[i] = otra
                let variante = String(nueva)
                if PlanDeCuentas.nombre(de: variante) != nil { lista.append(variante) }
            }
        }
        return lista
    }

    /// Palabras de cuatro letras o más, en minúsculas y sin tildes.
    static func palabras(_ texto: String) -> [String] {
        texto.lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_ES"))
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 4 }
    }

    /// Iguales salvo una letra de cada cuatro («merraderics» y «mercaderias»), o una abreviada
    /// de la otra («antic» y «anticipos»).
    static func seParecen(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if min(a.count, b.count) >= 5, a.hasPrefix(b) || b.hasPrefix(a) { return true }
        return distancia(a, b) <= max(1, max(a.count, b.count) / 4)
    }

    /// Cambios de una letra (quitar, poner, sustituir) para pasar de una palabra a la otra.
    private static func distancia(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        guard !x.isEmpty, !y.isEmpty else { return max(x.count, y.count) }
        var anterior = Array(0...y.count)
        for i in 1...x.count {
            var actual = [i] + Array(repeating: 0, count: y.count)
            for j in 1...y.count {
                actual[j] = min(anterior[j] + 1, actual[j - 1] + 1, anterior[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            anterior = actual
        }
        return anterior[y.count]
    }
}
