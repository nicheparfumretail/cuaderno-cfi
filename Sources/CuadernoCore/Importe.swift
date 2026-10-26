import Foundation

/// Utilidades de importes. Todo importe es `Decimal`: con `Double`, 0,1 + 0,2 no da 0,3
/// y un asiento podría descuadrar por céntimos que no existen.
public enum Importe {
    private static let posix = Locale(identifier: "en_US_POSIX")

    /// Redondeo a céntimos, mitad hacia arriba (0,105 → 0,11), como se hace a mano en clase.
    public static func redondear(_ valor: Decimal) -> Decimal {
        var entrada = valor
        var salida = Decimal()
        NSDecimalRound(&salida, &entrada, 2, .plain)
        return salida
    }

    /// Cuota de un impuesto o una retención: base × tipo %, redondeada a céntimos.
    /// Ejemplo: base 4.850 al 21 % → 1.018,50 de IVA.
    public static func cuota(base: Decimal, tipo: Decimal) -> Decimal {
        redondear(base * tipo / 100)
    }

    /// Lee un importe escrito a la española ("1.185,80", "1.000") o con punto decimal ("1185.80").
    public static func leer(_ texto: String) -> Decimal? {
        var s = texto
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "€", with: "")
        guard !s.isEmpty else { return nil }
        // "1,185.80" (formato inglés) se rechaza: leerlo a la española daría 1,1858.
        if let coma = s.lastIndex(of: ","), let punto = s.lastIndex(of: "."), punto > coma { return nil }
        if s.contains(",") {
            // Con coma decimal, los puntos son separadores de miles.
            s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else if let ultimo = s.lastIndex(of: "."), s.distance(from: ultimo, to: s.endIndex) == 4 {
            // "1.000" o "81.153": tres cifras detrás del punto → son miles, no decimales.
            s = s.replacingOccurrences(of: ".", with: "")
        }
        let permitidos = Set("0123456789.-")
        guard s.allSatisfy({ permitidos.contains($0) }),
              s.filter({ $0 == "." }).count <= 1,
              s.lastIndex(of: "-").map({ $0 == s.startIndex }) ?? true,
              s.contains(where: { $0.isNumber }),
              let valor = Decimal(string: s, locale: posix),
              // Un importe en euros no tiene más de dos decimales: "1,234" no es un importe válido.
              redondear(valor) == valor else { return nil }
        return valor
    }

    /// Formato del cuaderno: "1.185,80", "1.000,00", "-24,20". Siempre con los dos decimales
    /// de los céntimos, también cuando son cero (lo pidió Iulian: todos los importes iguales).
    public static func formatear(_ valor: Decimal) -> String {
        let redondeado = redondear(valor)
        let negativo = redondeado < 0
        let texto = "\(negativo ? -redondeado : redondeado)"
        let partes = texto.split(separator: ".", omittingEmptySubsequences: false)

        var grupos: [String] = []
        var resto = Substring(partes[0])
        while resto.count > 3 {
            grupos.insert(String(resto.suffix(3)), at: 0)
            resto = resto.dropLast(3)
        }
        grupos.insert(String(resto), at: 0)
        var resultado = grupos.joined(separator: ".")

        var decimales = partes.count > 1 ? String(partes[1]) : ""
        while decimales.count < 2 { decimales += "0" }
        resultado += "," + decimales
        return (negativo ? "-" : "") + resultado
    }
}
