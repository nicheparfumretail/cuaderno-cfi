import SwiftUI
import PencilKit

/// Lo que pasa en la pantalla de una hoja y no se guarda: la rueda abierta, el apunte que se
/// corrige, el mayor que se mira, el apunte que se arrastra y el asiento al que se salta
/// (resaltado un momento en amarillo).
@MainActor
final class InteraccionHoja: ObservableObject {
    /// El espacio de coordenadas de la hoja: ahí se miden los asientos y el dedo al arrastrar.
    static let espacio = "hoja"

    /// La rueda de opciones de un apunte, centrada en un punto de la pantalla.
    struct Rueda {
        let fila: FilaEditable
        let centro: CGPoint
    }

    /// Un salto a un asiento. Cada salto es distinto aunque sea al mismo número.
    struct Salto: Equatable {
        let numero: Int
        let id = UUID()
    }

    @Published var rueda: Rueda?
    /// El apunte (`FilaEditable.id`) con la mini ventana de corrección abierta.
    @Published var editando: String?
    @Published var cuentaMayor: CuentaSeleccionada?
    @Published private(set) var salto: Salto?
    @Published private(set) var resaltado: Int?

    /// El apunte que se arrastra. Va aparte: sus cambios no redibujan la hoja entera.
    let arrastre = ArrastreApunte()

    /// La paleta del Pencil, compartida por el lienzo y las notas del enunciado: la herramienta
    /// elegida vale para los dos.
    let paleta = PKToolPicker()

    /// Lleva al asiento y lo resalta en amarillo: un segundo y medio después de llegar
    /// (el desplazamiento hasta él tarda unas décimas).
    func saltar(a numero: Int) {
        salto = Salto(numero: numero)
        resaltado = numero
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            if self?.resaltado == numero { self?.resaltado = nil }
        }
    }
}
