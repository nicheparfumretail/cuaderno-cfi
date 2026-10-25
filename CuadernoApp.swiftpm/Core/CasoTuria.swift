import Foundation

// Caso repaso Túria Distribucions, SL — libro diario del 1T 2025 (CFI, apuntes de Gema).
// Generado a partir de la nota del vault de estudio; no se edita a mano.
// Sirve de datos de prueba del motor y de diario de ejemplo en la app.
public enum CasoTuria {
    public static let empresa = "Túria Distribucions, SL"

    public static func diario() -> Diario {
        var diario = Diario()
        for asiento in asientos() { try! diario.añadir(asiento) }
        return diario
    }

    public static func asientos() -> [Asiento] {
        [
            a(1, "2025-01-01", "Apertura", [
                d("216", "10000"),
                d("211", "20000", "local propio"),
                d("300", "6000"),
                d("430", "3630", "Nord"),
                d("4310", "2420", "Mar, vto. 23/03"),
                d("572", "45000"),
                d("570", "1000"),
                h("100", "81153"),
                h("400", "4840", "Delta"),
                h("401", "1815", "Envapack, vto. 26/03"),
                h("410", "242", "transportista"),
            ]),
            a(2, "2025-01-10", "Op. 1 — Factura del anticipo", [
                d("407", "1000", "Ponent"),
                d("472", "210"),
                h("400", "1210", "Ponent"),
            ]),
            a(3, "2025-01-10", "Op. 1 — Pago del anticipo", [
                d("400", "1210", "Ponent"),
                h("572", "1210"),
            ]),
            a(4, "2025-01-20", "Op. 2 — Factura de compra", [
                d("600", "4900"),
                d("472", "819"),
                h("407", "1000", "Ponent"),
                h("400", "4719", "Ponent"),
            ]),
            a(5, "2025-01-20", "Op. 2 — Pago del resto", [
                d("400", "4719", "Ponent"),
                h("572", "4719"),
            ]),
            a(6, "2025-01-22", "Op. 3", [
                d("600", "2000"),
                d("472", "420"),
                h("400", "2420", "Llevant"),
            ]),
            a(7, "2025-01-24", "Op. 4 — Factura rectificativa (devolución)", [
                d("400", "605", "Llevant"),
                h("608", "500"),
                h("472", "105"),
            ]),
            a(8, "2025-01-24", "Op. 4 — Pago del saldo", [
                d("400", "1815", "Llevant"),
                h("572", "1815"),
            ]),
            a(9, "2025-01-25", "Op. 5", [
                d("600", "1500"),
                d("406", "200"),
                d("472", "357"),
                h("400", "2057", "Garbí"),
            ]),
            a(10, "2025-01-27", "Op. 6 — Rectificativa por envases devueltos", [
                d("400", "121", "Garbí"),
                h("406", "100"),
                h("472", "21"),
            ]),
            a(11, "2025-01-27", "Op. 6 — Envases que se queda", [
                d("602", "100"),
                h("406", "100"),
            ]),
            a(12, "2025-01-27", "Op. 6 — Pago del saldo", [
                d("400", "1936", "Garbí"),
                h("572", "1936"),
            ]),
            a(13, "2025-01-30", "Op. 7", [
                d("600", "1000"),
                d("472", "210"),
                h("400", "1210", "Mestral"),
            ]),
            a(14, "2025-02-01", "Op. 8 — Rectificativa por pronto pago", [
                d("400", "24.2", "Mestral"),
                h("606", "20"),
                h("472", "4.2"),
            ]),
            a(15, "2025-02-01", "Op. 8 — Pago del saldo", [
                d("400", "1185.8", "Mestral"),
                h("572", "1185.8"),
            ]),
            a(16, "2025-02-03", "Op. 9 — Factura del anticipo", [
                d("430", "1210", "Serra"),
                h("438", "1000"),
                h("477", "210"),
            ]),
            a(17, "2025-02-03", "Op. 9 — Cobro del anticipo", [
                d("572", "1210"),
                h("430", "1210", "Serra"),
            ]),
            a(18, "2025-02-10", "Op. 10 — Factura de venta", [
                d("430", "5868.5", "Serra"),
                d("438", "1000"),
                h("700", "5700"),
                h("759", "150"),
                h("477", "1018.5"),
            ]),
            a(19, "2025-02-10", "Op. 10 — Cobro del resto", [
                d("572", "5868.5"),
                h("430", "5868.5", "Serra"),
            ]),
            a(20, "2025-02-12", "Op. 11", [
                d("430", "2783", "Alba"),
                h("700", "2000"),
                h("437", "300"),
                h("477", "483"),
            ]),
            a(21, "2025-02-14", "Op. 12 — Rectificativa por envases devueltos", [
                d("437", "200"),
                d("477", "42"),
                h("430", "242", "Alba"),
            ]),
            a(22, "2025-02-14", "Op. 12 — Envases que se queda", [
                d("437", "100"),
                h("704", "100"),
            ]),
            a(23, "2025-02-14", "Op. 12 — Cobro del saldo", [
                d("572", "2541"),
                h("430", "2541", "Alba"),
            ]),
            a(24, "2025-02-15", "Op. 13", [
                d("430", "1815", "Vernissa"),
                h("700", "1500"),
                h("477", "315"),
            ]),
            a(25, "2025-02-17", "Op. 14 — Rectificativa (bonificación)", [
                d("708", "100"),
                d("477", "21"),
                h("430", "121", "Vernissa"),
            ]),
            a(26, "2025-02-17", "Op. 14 — Cobro del saldo", [
                d("572", "1694"),
                h("430", "1694", "Vernissa"),
            ]),
            a(27, "2025-02-20", "Op. 15", [
                d("4310", "3630", "Flor"),
                h("700", "3000"),
                h("477", "630"),
            ]),
            a(28, "2025-02-21", "Op. 16 — Entrega en gestión de cobro", [
                d("4312", "2420", "Mar"),
                h("4310", "2420", "Mar"),
            ]),
            a(29, "2025-02-24", "Op. 17 — Recepción del pagaré", [
                d("4310", "3630", "Nord"),
                h("430", "3630", "Nord"),
            ]),
            a(30, "2025-02-24", "Op. 17 — Entrega al descuento", [
                d("4311", "3630", "Nord"),
                h("4310", "3630", "Nord"),
            ]),
            a(31, "2025-02-24", "Op. 17 — Ingreso del descuento", [
                d("572", "3570"),
                d("665", "40"),
                d("626", "20"),
                h("5208", "3630"),
            ]),
            a(32, "2025-02-26", "Op. 18", [
                d("460", "300", "Laura Vidal"),
                h("570", "300"),
            ]),
            a(33, "2025-02-28", "Op. 19 — Nómina de Laura Vidal", [
                d("640", "6000"),
                d("642", "1800"),
                h("4751.1", "600", "IRPF"),
                h("476", "2180"),
                h("460", "300"),
                h("465", "4720"),
            ]),
            a(34, "2025-02-28", "Op. 19 — Nómina de Pedro Argente", [
                d("640", "1310"),
                d("471", "430"),
                d("642", "395"),
                h("4751.1", "355", "IRPF"),
                h("476", "481"),
                h("465", "1299"),
            ]),
            a(35, "2025-03-01", "Op. 20", [
                d("4310", "4961", "Bosc"),
                h("700", "4000"),
                h("704", "100"),
                h("477", "861"),
            ]),
            a(36, "2025-03-03", "Op. 21", [
                d("624", "180"),
                d("472", "37.8"),
                h("410", "217.8", "transportista"),
            ]),
            a(37, "2025-03-05", "Op. 22", [
                d("465", "6019"),
                h("572", "6019"),
            ]),
            a(38, "2025-03-10", "Op. 23", [
                d("410", "459.8", "transportista"),
                h("572", "459.8"),
            ]),
            a(39, "2025-03-12", "Op. 24 — Factura del alquiler", [
                d("621", "700"),
                d("472", "147"),
                h("4751.3", "133", "arrendamientos"),
                h("410", "714"),
            ]),
            a(40, "2025-03-12", "Op. 24 — Pago", [
                d("410", "714"),
                h("572", "714"),
            ]),
            a(41, "2025-03-15", "Op. 25 — Factura del asesor", [
                d("623", "250"),
                d("472", "52.5"),
                h("4751.1", "37.5", "IRPF"),
                h("410", "265"),
            ]),
            a(42, "2025-03-15", "Op. 25 — Pago", [
                d("410", "265"),
                h("572", "265"),
            ]),
            a(43, "2025-03-18", "Op. 26", [
                d("440", "510", "Centre"),
                d("473", "95"),
                h("752", "500"),
                h("477", "105"),
            ]),
            a(44, "2025-03-20", "Op. 27 — Factura de electricidad", [
                d("628", "240"),
                d("472", "50.4"),
                h("410", "290.4"),
            ]),
            a(45, "2025-03-25", "Op. 27 — Cargo en cuenta", [
                d("410", "290.4"),
                h("572", "290.4"),
            ]),
            a(46, "2025-03-21", "Op. 28", [
                d("572", "510"),
                h("440", "510", "Centre"),
            ]),
            a(47, "2025-03-22", "Op. 29 — Concesión", [
                d("4708", "2000"),
                h("740", "2000"),
            ]),
            a(48, "2025-03-22", "Op. 30 — Cobro", [
                d("572", "2000"),
                h("4708", "2000"),
            ]),
            a(49, "2025-03-22", "Op. 31", [
                d("572", "97.2"),
                d("473", "22.8"),
                h("769", "120"),
            ]),
            a(50, "2025-03-23", "Op. 32", [
                d("572", "2383.7"),
                d("626", "30"),
                d("472", "6.3"),
                h("4312", "2420", "Mar"),
            ]),
            a(51, "2025-03-24", "Op. 33 — Cargo del banco", [
                d("5208", "3630"),
                d("626", "35"),
                h("572", "3665"),
            ]),
            a(52, "2025-03-24", "Op. 33 — Reclasificación como impagado", [
                d("4315", "3630", "Nord"),
                h("4311", "3630", "Nord"),
            ]),
            a(53, "2025-03-25", "Op. 34", [
                d("572", "3630"),
                h("4310", "3630", "Flor"),
            ]),
            a(54, "2025-03-26", "Op. 35 — Recibo del agua", [
                d("628", "80"),
                d("472", "8"),
                h("410", "88"),
            ]),
            a(55, "2025-03-26", "Op. 35 — Pago en efectivo", [
                d("410", "88"),
                h("570", "88"),
            ]),
            a(56, "2025-03-26", "Op. 36", [
                d("401", "1815", "Envapack"),
                h("572", "1815"),
            ]),
            a(57, "2025-03-27", "Op. 37", [
                d("400", "4840", "Delta"),
                h("572", "4840"),
            ]),
            a(58, "2025-03-28", "Op. 38", [
                d("631", "360"),
                h("572", "360"),
            ]),
            a(59, "2025-03-28", "Op. 39 — Entrega en gestión de cobro", [
                d("4312", "4961", "Bosc"),
                h("4310", "4961", "Bosc"),
            ]),
            a(60, "2025-03-29", "Op. 39 — Reclasificación como impagado", [
                d("4315", "4961", "Bosc"),
                h("4312", "4961", "Bosc"),
            ]),
            a(61, "2025-03-29", "Op. 39 — Comisión del banco", [
                d("626", "20"),
                d("472", "4.2"),
                h("572", "24.2"),
            ]),
            a(62, "2025-03-31", "Op. 40", [
                d("476", "2661"),
                h("471", "430"),
                h("572", "2231"),
            ]),
            a(63, "2025-03-31", "Op. 41", [
                d("649", "180"),
                h("572", "180"),
            ]),
        ]
    }

    private static func a(_ numero: Int, _ fecha: String, _ concepto: String, _ apuntes: [Apunte]) -> Asiento {
        try! Asiento(empresa: empresa, numero: numero, fecha: Fecha(iso: fecha)!, concepto: concepto, apuntes: apuntes)
    }

    private static func d(_ cuenta: String, _ importe: String, _ detalle: String? = nil) -> Apunte {
        Apunte(.debe, cuenta, Decimal(string: importe)!, detalle: detalle)
    }

    private static func h(_ cuenta: String, _ importe: String, _ detalle: String? = nil) -> Apunte {
        Apunte(.haber, cuenta, Decimal(string: importe)!, detalle: detalle)
    }
}
