import SwiftUI

/// Arriba de la «Solución» de una práctica: cuántos asientos están bien y si el diario cuadra
/// en total (en partida doble, la suma del Debe y la del Haber tienen que coincidir).
struct ResumenSolucion: View {
    let resueltos: [AsientoResuelto]

    var body: some View {
        let porRevisar = resueltos.filter { !$0.revision.isEmpty }.count
        let apuntes = resueltos.flatMap(\.leido.apuntes)
        let debe = apuntes.reduce(Decimal(0)) { $0 + $1.debe }
        let haber = apuntes.reduce(Decimal(0)) { $0 + $1.haber }
        VStack(alignment: .leading, spacing: 10) {
            Text("Corrección").font(.title2.bold())
            if resueltos.isEmpty {
                Text("Escribe los asientos en el lienzo y vuelve aquí para corregirlos.")
                    .foregroundStyle(.secondary)
            } else if porRevisar == 0 {
                Label(resueltos.count == 1
                      ? "El asiento cuadra y sus cuentas existen en el PGC."
                      : "Los \(resueltos.count) asientos cuadran y sus cuentas existen en el PGC.",
                      systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Label("\(porRevisar) de \(resueltos.count) asientos por revisar: lo tienes debajo de cada uno.",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            if !apuntes.isEmpty {
                Label(debe == haber
                      ? "Sumas del diario iguales: Debe \(Importe.formatear(debe)) = Haber \(Importe.formatear(haber))."
                      : "Sumas del diario distintas: Debe \(Importe.formatear(debe)), Haber \(Importe.formatear(haber)) (diferencia \(Importe.formatear(abs(debe - haber)))).",
                      systemImage: "sum")
                    .foregroundStyle(debe == haber ? Color.secondary : Color.orange)
            }
            Text("Comprueba la partida doble de cada asiento, que sus cuentas existan en el cuadro del PGC y lo que no se ha podido leer. Si una cuenta es la que pedía el enunciado, la app no lo puede saber sin la solución.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.system(.body, design: .default))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.08)))
    }
}

/// Debajo de cada asiento en la «Solución»: bien, o la lista de lo que hay que revisar.
struct RevisionAsiento: View {
    let revision: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if revision.isEmpty {
                Label("Bien: cuadra y sus cuentas existen en el PGC.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                ForEach(revision, id: \.self) { texto in
                    Label(texto, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
