import SwiftUI

/// Qué se está corrigiendo: un apunte leído o una fila que no se entendió.
struct EdicionApunte: Identifiable {
    let id = UUID()
    /// Posición del asiento en la hoja (0 = el primero).
    let asiento: Int
    let leido: Correccion.Leido
    let lado: Lado
    let cuenta: String
    let importe: String
    let corregida: Bool

    /// Lo que se leyó, para enseñarlo arriba.
    var textoLeido: String {
        switch leido {
        case .apunte(let apunte):
            return "\(apunte.lado == .debe ? "Debe" : "Haber") · \(apunte.cuenta) · \(Importe.formatear(apunte.importe))"
        case .fila(let texto):
            return "«\(texto)»"
        }
    }
}

/// Corrige un apunte sin reescribir la tinta: cuenta e importe se escriben encima con el Pencil
/// (Scribble) o con el teclado. La tinta no se toca; si luego se reescribe y se lee otra cosa, la
/// corrección deja de aplicarse.
struct CorregirApunteView: View {
    let edicion: EdicionApunte
    let guardar: (Apunte?) -> Void
    let volverALoLeido: () -> Void

    @Environment(\.dismiss) private var cerrar
    @State private var lado: Lado
    @State private var cuenta: String
    @State private var importe: String

    init(edicion: EdicionApunte, guardar: @escaping (Apunte?) -> Void, volverALoLeido: @escaping () -> Void) {
        self.edicion = edicion
        self.guardar = guardar
        self.volverALoLeido = volverALoLeido
        _lado = State(initialValue: edicion.lado)
        _cuenta = State(initialValue: edicion.cuenta)
        _importe = State(initialValue: edicion.importe)
    }

    /// El apunte, si la cuenta es un código del PGC y el importe es positivo.
    private var apunte: Apunte? {
        let codigo = cuenta.trimmingCharacters(in: .whitespaces)
        guard Cuenta(codigo) != nil, let valor = Importe.leer(importe), valor > 0 else { return nil }
        return Apunte(lado, codigo, valor)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Leído en la tinta") {
                    Text(edicion.textoLeido).font(.body.monospacedDigit())
                }
                Section {
                    Picker("Lado", selection: $lado) {
                        Text("Debe").tag(Lado.debe)
                        Text("Haber").tag(Lado.haber)
                    }
                    .pickerStyle(.segmented)
                    TextField("Cuenta (572, 4751.1…)", text: $cuenta)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.title3.monospacedDigit())
                    TextField("Importe (1.000,00)", text: $importe)
                        .keyboardType(.decimalPad)
                        .font(.title3.monospacedDigit())
                } header: {
                    Text("Lo bueno")
                } footer: {
                    if let apunte {
                        Text("\(Cuenta(apunte.cuenta)?.description ?? apunte.cuenta) · \(Importe.formatear(apunte.importe))")
                    } else {
                        Text("Escribe encima con el Pencil o con el teclado. La cuenta tiene 3 cifras o más y el importe es mayor que 0.")
                    }
                }
                Section {
                    Button("Descartar: no es un apunte", role: .destructive) {
                        guardar(nil)
                        cerrar()
                    }
                    if edicion.corregida {
                        Button("Volver a lo leído en la tinta") {
                            volverALoLeido()
                            cerrar()
                        }
                    }
                }
            }
            .navigationTitle("Corregir apunte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guardar(apunte)
                        cerrar()
                    }
                    .disabled(apunte == nil)
                }
            }
        }
    }
}
