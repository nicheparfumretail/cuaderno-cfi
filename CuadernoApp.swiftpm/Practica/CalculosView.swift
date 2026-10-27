import SwiftUI
import PencilKit

/// La mitad de cálculos de una práctica: la hoja cuadriculada para las cuentas que no son asientos
/// (cuotas de IVA, prorratas, amortizaciones), con sus acciones rápidas en la barra: deshacer,
/// rehacer, borrar todo (se puede deshacer), cambiar de mitad con el enunciado y minimizar.
struct CalculosView: View {
    @ObservedObject var editor: EditorHoja
    let plegado: Bool
    let alPlegar: () -> Void
    let alIntercambiar: () -> Void
    @EnvironmentObject private var interaccion: InteraccionHoja
    @StateObject private var mando = MandoLienzo()

    var body: some View {
        VStack(spacing: 0) {
            barra
            if !plegado {
                Divider()
                LienzoCalculosView(editor: editor, paleta: interaccion.paleta, mando: mando)
            }
        }
    }

    private var barra: some View {
        HStack(spacing: 16) {
            Button(action: alPlegar) {
                Text("Cálculos").font(.headline)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            if !plegado {
                Button { mando.deshacer() } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .accessibilityLabel("Deshacer")
                Button { mando.rehacer() } label: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .accessibilityLabel("Rehacer")
                Button { mando.borrarTodo() } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Borrar todos los cálculos")
            }
            Button(action: alIntercambiar) {
                Image(systemName: "arrow.up.arrow.down")
            }
            .accessibilityLabel("Cambiar de mitad con el enunciado")
            Button(action: alPlegar) {
                Image(systemName: plegado ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
            }
            .accessibilityLabel(plegado ? "Abrir los cálculos" : "Minimizar los cálculos")
        }
        .font(.title3)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// Lo que hacen los botones de la barra sobre la hoja de cálculos.
@MainActor
final class MandoLienzo: ObservableObject {
    weak var canvas: PKCanvasView?

    func deshacer() {
        canvas?.undoManager?.undo()
    }

    func rehacer() {
        canvas?.undoManager?.redo()
    }

    /// Deja la hoja en blanco; «Deshacer» la recupera.
    func borrarTodo() {
        guard let canvas = canvas, !canvas.drawing.strokes.isEmpty else { return }
        poner(PKDrawing(), en: canvas)
    }

    private func poner(_ dibujo: PKDrawing, en canvas: PKCanvasView) {
        let antes = canvas.drawing
        canvas.undoManager?.registerUndo(withTarget: self) { mando in
            MainActor.assumeIsolated { mando.poner(antes, en: canvas) }
        }
        canvas.drawing = dibujo
    }
}
