import Foundation

/// La corrección de un ejercicio (vista «Solución» del modo práctica). Mientras se practica no se
/// enseña si los asientos cuadran; al corregir se enseña todo junto: si cuadra, las cuentas que
/// no existen en el cuadro del PGC y lo que no se ha entendido o se ha deducido al leer.
extension AsientoResuelto {
    /// Lo que hay que mirar en este asiento. Vacío: está bien hasta donde la app puede saberlo
    /// (cuadra y sus cuentas existen). Sin la solución del ejercicio no se puede saber si es la
    /// cuenta que tocaba.
    public var revision: [String] {
        var lista: [String] = []
        if case .failure(let error) = resultado, !leido.apuntes.isEmpty {
            lista.append((error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
        for cuenta in cuentasFueraDelPGC {
            lista.append("La \(cuenta) no está en el cuadro de cuentas del PGC: revisa el número.")
        }
        return lista + avisos + sugerencias
    }

    /// Cuentas de los grupos 1 a 7 que no están en el cuadro de cuentas, ni ellas ni la cuenta
    /// de tres cifras de la que serían subcuenta (la 5720 sí vale: es una subcuenta de la 572).
    public var cuentasFueraDelPGC: [String] {
        var vistas: [String] = []
        for apunte in leido.apuntes where !vistas.contains(apunte.cuenta) {
            vistas.append(apunte.cuenta)
        }
        return vistas.filter { codigo in
            guard let cuenta = Cuenta(codigo), (1...7).contains(cuenta.grupo) else { return false }
            return PlanDeCuentas.nombre(de: codigo) == nil && PlanDeCuentas.nombre(de: String(codigo.prefix(3))) == nil
        }
    }
}
