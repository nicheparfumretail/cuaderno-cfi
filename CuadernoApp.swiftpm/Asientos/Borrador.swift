import Foundation

/// Un apunte mientras se escribe: todo es texto hasta que el asiento se valida.
struct FilaBorrador: Identifiable, Hashable {
    let id = UUID()
    var lado: Lado
    var cuenta = ""
    var importe = ""
    var detalle = ""
}

struct ErrorBorrador: LocalizedError {
    let errorDescription: String?
}

/// Asiento a medio escribir (a mano en el formulario, o lo que ha leído el reconocedor).
/// Solo se convierte en `Asiento` si cumple las reglas del motor.
struct Borrador: Identifiable {
    let id = UUID()
    /// Si se está corrigiendo un asiento del diario, el original (conserva id y número).
    var original: Asiento?
    var fecha = Date()
    var concepto = ""
    var filas: [FilaBorrador] = [FilaBorrador(lado: .debe), FilaBorrador(lado: .haber)]
    var noEntendido: [String] = []
    /// Si viene del lienzo: hasta qué trazo queda pasado a limpio al guardarlo.
    var trazosHasta: Int?

    init() {}

    init(asiento: Asiento) {
        original = asiento
        fecha = asiento.fecha.date
        concepto = asiento.concepto
        filas = asiento.apuntesOrdenados.map {
            FilaBorrador(lado: $0.lado, cuenta: $0.cuenta, importe: Importe.formatear($0.importe),
                         detalle: $0.detalle ?? "")
        }
    }

    init(reconocido: Reconocimiento, trazosHasta: Int) {
        if let fecha = reconocido.fecha { self.fecha = fecha.date }
        if !reconocido.apuntes.isEmpty {
            filas = reconocido.apuntes.map {
                FilaBorrador(lado: $0.lado, cuenta: $0.cuenta, importe: Importe.formatear($0.importe))
            }
        }
        noEntendido = reconocido.noEntendido
        self.trazosHasta = trazosHasta
    }

    /// Filas con algo escrito. Las vacías no cuentan (son huecos para seguir escribiendo).
    private var filasEscritas: [FilaBorrador] {
        filas.filter { !$0.cuenta.trimmingCharacters(in: .whitespaces).isEmpty || !$0.importe.isEmpty }
    }

    var sumas: (debe: Decimal, haber: Decimal) {
        var debe: Decimal = 0
        var haber: Decimal = 0
        for fila in filasEscritas {
            let importe = Importe.leer(fila.importe) ?? 0
            if fila.lado == .debe { debe += importe } else { haber += importe }
        }
        return (debe, haber)
    }

    func construir(empresa: String) -> Result<Asiento, Error> {
        var apuntes: [Apunte] = []
        for fila in filasEscritas {
            guard let importe = Importe.leer(fila.importe) else {
                let cuenta = fila.cuenta.isEmpty ? "sin cuenta" : "de la \(fila.cuenta)"
                return .failure(ErrorBorrador(errorDescription: "No entiendo el importe «\(fila.importe)» \(cuenta)."))
            }
            let detalle = fila.detalle.trimmingCharacters(in: .whitespaces)
            apuntes.append(Apunte(fila.lado, fila.cuenta, importe, detalle: detalle.isEmpty ? nil : detalle))
        }
        return Result {
            try Asiento(id: original?.id ?? UUID(),
                        empresa: original?.empresa ?? empresa,
                        numero: original?.numero ?? 0,
                        fecha: Fecha(fecha),
                        concepto: concepto.trimmingCharacters(in: .whitespaces),
                        apuntes: apuntes)
        }
    }
}

extension Fecha {
    init(_ date: Date) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        self = Fecha(año: c.year ?? 2025, mes: c.month ?? 1, dia: c.day ?? 1) ?? Fecha.hoy()
    }

    var date: Date {
        Calendar.current.date(from: DateComponents(year: año, month: mes, day: dia)) ?? Date()
    }
}
