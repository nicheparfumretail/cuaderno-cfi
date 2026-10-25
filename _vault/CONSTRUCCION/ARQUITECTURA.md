# Arquitectura (propuesta, 24-10-2026)

Restricción de partida: **Windows + iPad, sin Mac.** Swift nativo no se compila en Windows para iPad.

```
                 ┌──────────────────── GitHub (repo) ─────────────────────┐
 Claude Code     │  CuadernoCore/   Swift puro: Asiento, Apunte, Cuenta,   │
 (nube) ───────► │                  Diario, Mayor, Balance, Mapeo→KPIs     │
                 │                  + tests (se pueden ejecutar en Linux)  │
                 │  CuadernoApp.swiftpm/  SwiftUI + PencilKit + Vision     │
                 │                        (solo compila en macOS)          │
                 │  .github/workflows/  macOS: compila y pasa los tests    │
                 └──────────────┬──────────────────────────────────────────┘
                                │ copia a iCloud Drive (iCloud para Windows)
                                ▼
                 iPad: Swift Playgrounds abre CuadernoApp.swiftpm y la ejecuta
                                │ guarda el diario como JSON en iCloud Drive
                                ▼
                 PC: visor del diario leyendo ese JSON (por decidir)
```

## Piezas
- **Lienzo:** `PKCanvasView` + `PKToolPicker` (PencilKit). Es el mismo motor de tinta que usa Notas, con la paleta de Notas. Los gestos del Pencil van por `UIPencilInteraction`.
- **Reconocimiento de la escritura:** dos vías, por decidir (ver DECISIONES, abierta):
  - *Vision en el propio iPad* (`VNRecognizeTextRequest`): gratis y sin conexión; la letra a mano con números y códigos de cuenta puede fallar.
  - *Claude por API*: entiende mejor un asiento mal escrito y devuelve JSON ordenado; necesita conexión y una clave de API.
  - Truco común: **la posición dice el lado.** Plantilla en el lienzo con columnas Debe | Haber; lo que se escribe a la izquierda es Debe y a la derecha Haber.
- **Motor contable:** paquete Swift puro, sin interfaz. Cada asiento valida la partida doble (Debe = Haber).
- **Datos compartidos:** JSON en iCloud Drive. Sin servidor.

## Riesgos a comprobar el primer día
- Que Swift Playgrounds en el iPad abra un `.swiftpm` copiado por iCloud para Windows sin conflictos.
- Que el mismo proyecto compile con `xcodebuild` en GitHub Actions.
- Que `UIPencilInteraction` (doble toque y apretón del Pencil Pro) funcione dentro de una app de Playgrounds.
- Que el entorno de Claude Code en la nube pueda instalar Swift para pasar los tests del motor (aquí, en Cowork, `download.swift.org` está bloqueado).
