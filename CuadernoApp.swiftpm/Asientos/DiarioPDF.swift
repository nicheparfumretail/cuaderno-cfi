import SwiftUI
import UniformTypeIdentifiers

/// La hoja en limpio como PDF (A4), para guardarla, mandarla o imprimirla. Cada asiento va
/// entero en una página: si no cabe en la que va, empieza en la siguiente. Con `solucion`, cada
/// asiento lleva debajo lo que hay que revisar (la corrección del modo práctica).
struct DiarioPDF: Transferable {
    let resueltos: [AsientoResuelto]
    let creada: Date
    let practica: Bool
    let solucion: Bool

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .pdf) { pdf in
            let datos = await pdf.datos()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(pdf.nombreArchivo)
            try datos.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    var nombreArchivo: String {
        let dia = Fecha(creada).description.replacingOccurrences(of: "/", with: "-")
        return solucion ? "Solución \(dia).pdf" : (practica ? "Práctica \(dia).pdf" : "Diario \(dia).pdf")
    }

    private static let pagina = CGRect(x: 0, y: 0, width: 595, height: 842)  // A4 en puntos
    private static let margen: CGFloat = 40

    @MainActor
    func datos() -> Data {
        let pagina = DiarioPDF.pagina
        let margen = DiarioPDF.margen
        let ancho = pagina.width - margen * 2
        let datos = NSMutableData()
        var caja = pagina
        guard let consumidor = CGDataConsumer(data: datos as CFMutableData),
              let pdf = CGContext(consumer: consumidor, mediaBox: &caja, nil) else { return Data() }

        var y = margen
        var abierta = false
        func colocar<V: View>(_ vista: V) {
            let renderer = ImageRenderer(content: vista
                .frame(width: ancho, alignment: .leading)
                .environment(\.colorScheme, .light)
                .environment(\.locale, Locale(identifier: "es_ES")))
            renderer.proposedSize = ProposedViewSize(width: ancho, height: nil)
            renderer.render { tamaño, dibujar in
                if !abierta || y + tamaño.height > pagina.height - margen {
                    if abierta { pdf.endPDFPage() }
                    pdf.beginPDFPage(nil)
                    abierta = true
                    y = margen
                }
                // El PDF cuenta desde abajo: el bloque se pone `y` puntos por debajo del borde de arriba.
                pdf.saveGState()
                pdf.translateBy(x: margen, y: pagina.height - y - tamaño.height)
                dibujar(pdf)
                pdf.restoreGState()
                y += tamaño.height + 16
            }
        }

        colocar(CabeceraImpresa(creada: creada, practica: practica, solucion: solucion, resueltos: resueltos))
        for resuelto in resueltos {
            colocar(AsientoImpreso(resuelto: resuelto, solucion: solucion))
        }
        colocar(SumasImpresas(resueltos: resueltos))
        if abierta { pdf.endPDFPage() }
        pdf.closePDF()
        return datos as Data
    }
}

private struct CabeceraImpresa: View {
    let creada: Date
    let practica: Bool
    let solucion: Bool
    let resueltos: [AsientoResuelto]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(solucion ? "Solución de la práctica" : "Libro diario")
                .font(.system(size: 20, weight: .bold, design: .serif))
            Text("Cuaderno CFI · \(practica ? "práctica" : "hoja") del \(Fecha(creada).description) · \(resueltos.count) asiento\(resueltos.count == 1 ? "" : "s")")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            if solucion {
                let porRevisar = resueltos.filter { !$0.revision.isEmpty }.count
                Text(porRevisar == 0
                     ? "Todos los asientos cuadran y sus cuentas existen en el PGC."
                     : "\(porRevisar) asiento\(porRevisar == 1 ? "" : "s") por revisar.")
                    .font(.system(size: 11, weight: .semibold))
                Text("La app comprueba la partida doble, que las cuentas existan en el cuadro del PGC y lo que no se ha podido leer. Si es la cuenta que pedía el enunciado, no lo puede saber sin la solución.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Rectangle().fill(Color.black).frame(height: 1).padding(.top, 4)
        }
    }
}

/// Un asiento con el formato de clase:
///
///     Nº 3 ———————————— 01/12/2024 ————————————
///     1.000,00  Proveedores  (400)   a   (572)  Bancos  1.000,00
private struct AsientoImpreso: View {
    let resuelto: AsientoResuelto
    let solucion: Bool

    var body: some View {
        let apuntes = resuelto.lineas.map(\.apunte)
        let debe = apuntes.filter { $0.lado == .debe }
        let haber = apuntes.filter { $0.lado == .haber }
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Nº \(resuelto.numero)").bold()
                raya
                Text(resuelto.fecha.description)
                raya
            }
            if !resuelto.concepto.isEmpty {
                Text(resuelto.concepto).font(.system(size: 9)).foregroundStyle(.secondary)
            }
            ForEach(0..<max(debe.count, haber.count), id: \.self) { fila in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    lado(fila < debe.count ? debe[fila] : nil, esDebe: true)
                    Text(fila == 0 ? "a" : "").italic().frame(width: 14)
                    lado(fila < haber.count ? haber[fila] : nil, esDebe: false)
                }
            }
            ForEach(resuelto.leido.noEntendido, id: \.self) { texto in
                Text("Sin leer: «\(texto)»").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            if solucion {
                let revision = resuelto.revision
                if revision.isEmpty {
                    Text("✓ Cuadra y sus cuentas existen en el PGC.").font(.system(size: 9, weight: .semibold))
                } else {
                    ForEach(revision, id: \.self) { texto in
                        Text("✗ \(texto)").font(.system(size: 9, weight: .semibold))
                    }
                }
            }
        }
        .font(.system(size: 11, design: .serif).monospacedDigit())
    }

    private var raya: some View {
        Rectangle().fill(Color.gray).frame(height: 0.5)
    }

    /// Debe: importe · nombre · (nº). Haber: (nº) · nombre · importe.
    @ViewBuilder
    private func lado(_ apunte: Apunte?, esDebe: Bool) -> some View {
        if let apunte {
            let nombre = PlanDeCuentas.nombre(de: apunte.cuenta) ?? ""
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                if esDebe {
                    Text(Importe.formatear(apunte.importe)).frame(width: 70, alignment: .trailing)
                    Text(nombre).lineLimit(2)
                    Spacer(minLength: 2)
                    Text("(\(apunte.cuenta))")
                } else {
                    Text("(\(apunte.cuenta))")
                    Text(nombre).lineLimit(2)
                    Spacer(minLength: 2)
                    Text(Importe.formatear(apunte.importe)).frame(width: 70, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity)
        } else {
            Spacer().frame(maxWidth: .infinity)
        }
    }
}

/// Las sumas del diario: en partida doble, el total del Debe y el del Haber tienen que coincidir.
private struct SumasImpresas: View {
    let resueltos: [AsientoResuelto]

    var body: some View {
        let apuntes = resueltos.flatMap(\.leido.apuntes)
        let debe = apuntes.reduce(Decimal(0)) { $0 + $1.debe }
        let haber = apuntes.reduce(Decimal(0)) { $0 + $1.haber }
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(Color.black).frame(height: 1)
            HStack {
                Text("Sumas del diario").bold()
                Spacer()
                Text("Debe \(Importe.formatear(debe))")
                Text("Haber \(Importe.formatear(haber))")
            }
            .font(.system(size: 11, design: .serif).monospacedDigit())
        }
    }
}
