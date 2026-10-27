import Foundation

/// Nombres de cuentas del PGC. Es una tabla de datos, no lógica: se amplía añadiendo filas.
/// `cuentas` son las del caso Túria, con los nombres de los apuntes; el resto del cuadro de
/// cuentas está en `pgc` (PlanDeCuentasPGC.swift).
public enum PlanDeCuentas {
    public static let grupos: [Int: String] = [
        1: "Financiación básica",
        2: "Activo no corriente",
        3: "Existencias",
        4: "Acreedores y deudores por operaciones comerciales",
        5: "Cuentas financieras",
        6: "Compras y gastos",
        7: "Ventas e ingresos",
        8: "Gastos imputados al patrimonio neto",
        9: "Ingresos imputados al patrimonio neto",
    ]

    public static let cuentas: [String: String] = [
        "100": "Capital social",
        "211": "Construcciones",
        "216": "Mobiliario",
        "300": "Mercaderías",
        "400": "Proveedores",
        "401": "Proveedores, efectos comerciales a pagar",
        "406": "Envases y embalajes a devolver a proveedores",
        "407": "Anticipos a proveedores",
        "410": "Acreedores por prestaciones de servicios",
        "430": "Clientes",
        "4310": "Clientes, efectos comerciales en cartera",
        "4311": "Clientes, efectos comerciales descontados",
        "4312": "Clientes, efectos comerciales en gestión de cobro",
        "4315": "Clientes, efectos comerciales impagados",
        "437": "Envases y embalajes a devolver por clientes",
        "438": "Anticipos de clientes",
        "440": "Deudores",
        "460": "Anticipos de remuneraciones",
        "465": "Remuneraciones pendientes de pago",
        "4708": "HP, deudora por subvenciones concedidas",
        "471": "Organismos de la Seguridad Social, deudores",
        "472": "HP, IVA soportado",
        "473": "HP, retenciones y pagos a cuenta",
        "4751.1": "HP, acreedora por retenciones practicadas (IRPF)",
        "4751.3": "HP, acreedora por retenciones (arrendamientos)",
        "476": "Organismos de la Seguridad Social, acreedores",
        "477": "HP, IVA repercutido",
        "5208": "Deudas por efectos descontados",
        "570": "Caja",
        "572": "Bancos",
        "600": "Compras de mercaderías",
        "602": "Compras de otros aprovisionamientos",
        "606": "Descuentos sobre compras por pronto pago",
        "608": "Devoluciones de compras y operaciones similares",
        "621": "Arrendamientos y cánones",
        "623": "Servicios de profesionales independientes",
        "624": "Transportes",
        "626": "Servicios bancarios y similares",
        "628": "Suministros",
        "631": "Otros tributos",
        "640": "Sueldos y salarios",
        "642": "Seguridad Social a cargo de la empresa",
        "649": "Otros gastos sociales",
        "665": "Intereses por descuento de efectos",
        "700": "Ventas de mercaderías",
        "704": "Ventas de envases y embalajes",
        "708": "Devoluciones de ventas y operaciones similares",
        "740": "Subvenciones, donaciones y legados a la explotación",
        "752": "Ingresos por arrendamientos",
        "759": "Ingresos por servicios diversos",
        "769": "Otros ingresos financieros",
    ]

    /// El nombre de los apuntes de clase y, si no está, el del cuadro de cuentas del PGC.
    public static func nombre(de codigo: String) -> String? {
        cuentas[codigo] ?? pgc[codigo]
    }

    /// Todas las cuentas con nombre, en el orden del cuadro de cuentas (430 < 4310 < 437).
    public static let todas: [(codigo: String, nombre: String)] =
        pgc.merging(cuentas) { _, deClase in deClase }
            .map { (codigo: $0.key, nombre: $0.value) }
            .sorted { $0.codigo < $1.codigo }

    /// Las cuentas cuyo código empieza por lo buscado o cuyo nombre lo contiene (sin tildes ni
    /// mayúsculas): «mercad» → 300, 600, 700…; «47» → 470, 4700, 471…
    public static func buscar(_ texto: String) -> [(codigo: String, nombre: String)] {
        let buscado = normalizar(texto).trimmingCharacters(in: .whitespaces)
        guard !buscado.isEmpty else { return todas }
        return todas.filter { $0.codigo.hasPrefix(buscado) || normalizar($0.nombre).contains(buscado) }
    }

    private static func normalizar(_ texto: String) -> String {
        texto.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_ES"))
    }
}
