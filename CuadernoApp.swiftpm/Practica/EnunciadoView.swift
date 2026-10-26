import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// El panel de una práctica: el enunciado (capturas, fotos, PDF o Word, uno debajo de otro) con
/// las notas escritas encima. Mientras se practica no dice si los asientos cuadran: eso queda
/// para la vista «Solución».
struct EnunciadoView: View {
    @ObservedObject var editor: EditorHoja
    @EnvironmentObject private var interaccion: InteraccionHoja

    @State private var fotos: [PhotosPickerItem] = []
    @State private var eligiendoArchivo = false
    @State private var cargando = false
    @State private var fallo: String?
    @State private var paraQuitar: (id: UUID, nombre: String)?

    var body: some View {
        VStack(spacing: 0) {
            barra
            Divider()
            ZStack {
                LienzoNotasView(editor: editor, paleta: interaccion.paleta) { proveedores in
                    Task { await pegar(proveedores) }
                }
                if editor.hoja.enunciado.isEmpty && !cargando {
                    vacio
                }
                if cargando {
                    ProgressView("Preparando el enunciado…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .fileImporter(isPresented: $eligiendoArchivo, allowedContentTypes: ImportadorEnunciado.tipos,
                      allowsMultipleSelection: true) { resultado in
            guard case .success(let urls) = resultado else { return }
            Task { await añadir(archivos: urls) }
        }
        .onChange(of: fotos) { _, elegidas in
            guard !elegidas.isEmpty else { return }
            fotos = []
            Task { await añadir(fotos: elegidas) }
        }
        .alert("No se ha podido añadir", isPresented: Binding(get: { fallo != nil }, set: { if !$0 { fallo = nil } })) {
            Button("Vale", role: .cancel) {}
        } message: {
            Text(fallo ?? "")
        }
        .confirmationDialog("¿Quitar «\(paraQuitar?.nombre ?? "")»? Se borran también las notas escritas encima.",
                            isPresented: Binding(get: { paraQuitar != nil }, set: { if !$0 { paraQuitar = nil } }),
                            titleVisibility: .visible) {
            Button("Quitar", role: .destructive) {
                if let id = paraQuitar?.id { editor.quitarAdjunto(id) }
                paraQuitar = nil
            }
        }
    }

    private var barra: some View {
        HStack(spacing: 16) {
            Text("Enunciado").font(.headline)
            Spacer(minLength: 0)
            PhotosPicker(selection: $fotos, maxSelectionCount: 10, matching: .images) {
                Image(systemName: "photo.on.rectangle")
            }
            .accessibilityLabel("Añadir fotos o capturas")
            Button { eligiendoArchivo = true } label: {
                Image(systemName: "doc.badge.plus")
            }
            .accessibilityLabel("Añadir un PDF, un Word o una imagen de Archivos")
            PasteButton(supportedContentTypes: [.image, .pdf]) { proveedores in
                Task { await pegar(proveedores) }
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
            .font(.body)
            if !editor.adjuntos.isEmpty {
                Menu {
                    ForEach(editor.adjuntos, id: \.id) { adjunto in
                        Button(role: .destructive) {
                            paraQuitar = (id: adjunto.id, nombre: adjunto.nombre)
                        } label: {
                            Label("Quitar «\(adjunto.nombre)» · \(adjunto.paginas) pág.", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "paperclip")
                }
                .accessibilityLabel("Adjuntos del enunciado")
            }
        }
        .font(.title3)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .disabled(cargando)
    }

    private var vacio: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Añade el enunciado").font(.headline)
            Text("Copia una captura y mantén el dedo aquí → Pegar (o el botón Pegar de arriba). También puedes elegir fotos o un PDF o un Word. Van uno debajo de otro y escribes encima o en los márgenes con el Pencil.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: 380)
        .environment(\.colorScheme, .light)
        .allowsHitTesting(false)
    }

    // MARK: - Añadir

    private func añadir(archivos urls: [URL]) async {
        cargando = true
        defer { cargando = false }
        for url in urls {
            do {
                let paginas = try await ImportadorEnunciado.paginas(de: url)
                editor.añadirAdjunto(paginas, nombre: url.deletingPathExtension().lastPathComponent)
            } catch {
                fallo = error.localizedDescription
            }
        }
    }

    private func añadir(fotos elegidas: [PhotosPickerItem]) async {
        cargando = true
        defer { cargando = false }
        for foto in elegidas {
            guard let datos = try? await foto.loadTransferable(type: Data.self) else {
                fallo = "No he podido leer una de las fotos."
                continue
            }
            let paginas = await ImportadorEnunciado.paginas(deDatos: datos, tipo: .image)
            if paginas.isEmpty {
                fallo = "No he podido leer una de las fotos."
            } else {
                editor.añadirAdjunto(paginas, nombre: "Foto \(editor.adjuntos.count + 1)")
            }
        }
    }

    private func pegar(_ proveedores: [NSItemProvider]) async {
        cargando = true
        defer { cargando = false }
        if proveedores.isEmpty { fallo = "No hay nada copiado que pegar." }
        for proveedor in proveedores {
            guard let tipo = proveedor.registeredContentTypes.first(where: { $0.conforms(to: .pdf) || $0.conforms(to: .image) }),
                  let datos = await leerDatos(de: proveedor, tipo: tipo) else { continue }
            let paginas = await ImportadorEnunciado.paginas(deDatos: datos, tipo: tipo)
            if paginas.isEmpty {
                fallo = "Lo pegado no se puede leer como imagen."
            } else {
                editor.añadirAdjunto(paginas, nombre: "Captura \(editor.adjuntos.count + 1)")
            }
        }
    }

    private func leerDatos(de proveedor: NSItemProvider, tipo: UTType) async -> Data? {
        await withCheckedContinuation { continuacion in
            _ = proveedor.loadDataRepresentation(for: tipo) { datos, _ in
                continuacion.resume(returning: datos)
            }
        }
    }
}
