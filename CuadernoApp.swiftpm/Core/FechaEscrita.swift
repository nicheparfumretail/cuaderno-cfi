import Foundation

/// La fecha escrita a mano en el centro de la hoja. Siempre día, mes y año, en ese orden; el día y
/// el mes con una o dos cifras y el año con dos o cuatro: «10/01/25», «10-1-25» y «10.1.2025»
/// son el 10 de enero de 2025. Cualquier cosa que no sea una cifra separa.
///
/// Vision lee a veces la barra «/» escrita a mano como un 1, o como un 7: «01/10/25» llega como
/// «01/10125». Si faltan separadores, se prueba a tomar esas cifras como barras, primero las
/// menos posibles, y solo se acepta si sale una única fecha. Si sale más de una, no se adivina:
/// el panel pide elegirla con el selector.
enum FechaEscrita {
    static func leer(_ texto: String) -> Fecha? {
        let trozos = texto.split { !$0.isASCIIDigit }.map(String.init)
        guard !trozos.isEmpty else { return nil }
        for barras in [Set<Character>(["1"]), ["1", "7"]] {
            for cambios in 0...2 {
                let largo = 3 - cambios
                guard trozos.count >= largo else { continue }
                var fechas = Set<Fecha>()
                // Trozos seguidos que, con `cambios` barras de más, dan día, mes y año.
                for inicio in 0...(trozos.count - largo) {
                    for partes in partir(Array(trozos[inicio..<inicio + largo]), barras: cambios, posibles: barras) {
                        if let fecha = fecha(partes) { fechas.insert(fecha) }
                    }
                }
                if fechas.count == 1 { return fechas.first }
                if fechas.count > 1 { return nil }
            }
        }
        return nil
    }

    /// Las maneras de repartir `barras` cortes entre los trozos.
    private static func partir(_ trozos: [String], barras: Int, posibles: Set<Character>) -> [[String]] {
        guard let primero = trozos.first else { return barras == 0 ? [[]] : [] }
        var resultado: [[String]] = []
        for aqui in 0...barras {
            for piezas in cortes(primero, aqui, posibles) {
                for resto in partir(Array(trozos.dropFirst()), barras: barras - aqui, posibles: posibles) {
                    resultado.append(piezas + resto)
                }
            }
        }
        return resultado
    }

    /// Las maneras de cortar un trozo por `cuantos` de sus cifras que pueden ser una barra
    /// (nunca la primera ni la última: una barra separa dos números).
    private static func cortes(_ trozo: String, _ cuantos: Int, _ posibles: Set<Character>) -> [[String]] {
        guard cuantos > 0 else { return [[trozo]] }
        let cifras = Array(trozo)
        var resultado: [[String]] = []
        for i in cifras.indices where i > 0 && i < cifras.count - 1 && posibles.contains(cifras[i]) {
            for resto in cortes(String(cifras[(i + 1)...]), cuantos - 1, posibles) {
                resultado.append([String(cifras[..<i])] + resto)
            }
        }
        return resultado
    }

    private static func fecha(_ partes: [String]) -> Fecha? {
        guard partes.count == 3,
              (1...2).contains(partes[0].count), (1...2).contains(partes[1].count),
              partes[2].count == 2 || partes[2].count == 4,
              let dia = Int(partes[0]), let mes = Int(partes[1]), var año = Int(partes[2]) else { return nil }
        if año < 100 { año += 2000 }
        guard (1900...2099).contains(año) else { return nil }
        return Fecha(año: año, mes: mes, dia: dia)
    }
}
