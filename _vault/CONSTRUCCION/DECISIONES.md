# Decisiones

## ADR-001 · App nativa de iPad, no web (30-09-2026, confirmada 24-10-2026)
- Contexto: el prototipo web (artefacto) se descartó porque no llegan los gestos del Pencil y no se siente como Notas.
- Decisión: SwiftUI + PencilKit en Swift Playgrounds.

## ADR-002 · El motor contable va aparte de la interfaz (30-09-2026)
- Los asientos son el único dato; todo lo demás son vistas derivadas. Mapeo cuenta → línea de PyG/KPI como tabla, no como código. Dimensión `empresa` en cada asiento desde el día 1.

## ADR-003 · Repositorio en GitHub desde el principio (24-10-2026)
- Motivo: Iulian tiene créditos de **Claude Code en la nube** que caducan el **5-11-2026**, y esas sesiones trabajan sobre un repositorio de GitHub.

## Abiertas
- **Reconocimiento:** Vision en el iPad o Claude por API. Propuesta: empezar con Vision + plantilla Debe | Haber, y probar Claude con los asientos que Vision no entienda.
- **Visor del PC:** página web, app de escritorio o script. Depende de cómo se sincronice el JSON.
- **Repositorio público o privado:** público = minutos de macOS gratis en GitHub Actions; privado = minutos limitados.

## ADR-004 · El código llega al iPad por GitHub + Working Copy, no por iCloud (24-10-2026)
- Contexto: iCloud para Windows 15.10 no inicia sesión en el PC de Iulian («no se ha inicializado en su totalidad»). Reparado, restablecido y reiniciado sin éxito; el registro muestra que su componente de llavero (`iCloudCKKS.exe`) se queda colgado. No es la contraseña ni la red ni la hora.
- Decisión: GitHub → **Working Copy** en el iPad (clonar y actualizar gratis) → Archivos → Swift Playgrounds. Ventaja añadida: en el iPad solo entra código que ya pasó el CI.
- Fallback puntual: subir archivos desde icloud.com en el navegador.
- Instrucciones para Claude Code: `CLAUDE.md` en la raíz.

## ADR-005 · El motor viaja copiado dentro de la app (25-10-2026, propuesta: confirmar en el iPad)
- Contexto: CLAUDE.md §4 prefería que la app usara `CuadernoCore` como dependencia por URL del propio repositorio.
- Problema de esa vía: la app usaría el motor publicado en `main` (o una etiqueta), no el de la rama en curso. El CI de una rama compilaría la app contra el motor viejo, así que el verde no demostraría nada, y en el iPad no se verían los cambios del motor hasta fusionar a `main`.
- Decisión: la fuente de verdad es `Sources/CuadernoCore`, y `scripts/sincronizar_core.py` la copia a `CuadernoApp.swiftpm/Core/`. El CI falla si la copia no está al día. `Core/` no se edita a mano.
- Coste: hay dos copias en el repositorio, pero el CI vigila que sean idénticas.

## ADR-006 · Visor del PC: página HTML local que lee el JSON exportado (25-10-2026)
- Cierra la pregunta abierta «Visor del PC».
- El iPad exporta `diario.json` (Más → Exportar diario → Guardar en Archivos → iCloud Drive o Google Drive). En el PC se descarga desde icloud.com o Drive y se abre con `visor-pc/index.html`. No hace falta iCloud para Windows (ADR-004), ni servidor, ni instalar nada.
- El JSON lleva los importes como texto («1185.8») y el visor suma en céntimos enteros: ningún paso usa coma flotante.
- Fase siguiente posible: sincronización automática. No hace falta para estudiar.

## ADR-007 · Reconocimiento: Vision en el iPad con la plantilla por columnas (25-10-2026)
- Cierra, para la fase 1, la pregunta abierta «Reconocimiento».
- La posición dice el lado: lo escrito en la columna izquierda es Debe; en la central, la cuenta; en la derecha, Haber. Cada fila es un apunte. Lo que Vision no entiende no se inventa: se enseña en el editor para corregirlo a mano.
- Claude por API queda para cuando se vea en la práctica qué falla con Vision.

## ADR-008 · El lienzo se lee en el formato de Gema y se pasa a limpio solo (25-10-2026)
- Sustituye la plantilla de tres columnas de ADR-007 (lo de usar Vision en el iPad se mantiene).
- Formato (foto de Iulian): la **fecha en el centro abre cada asiento**; **mitad izquierda = Debe** («1.000,00 Proveedores (400)»); **mitad derecha = Haber** («(572) Bancos 1.000,00»); la «a» va en el centro. El código de cuenta va entre paréntesis; el nombre se ignora porque manda el código.
- La lectura (posiciones → asientos) vive en el motor (`LectorAsientos`) y tiene tests; la app solo pasa la tinta por Vision.
- Sin botón: la hoja se relee entera 1,2 s después del último trazo. Los asientos que cuadran forman el diario; lo que no se entiende sale en rojo y se corrige reescribiendo en la tinta.

## ADR-009 · El código llega al iPad con un Atajo que descarga un zip, no con Working Copy (25-10-2026)
- Sustituye la vía de ADR-004 (GitHub → Working Copy → Swift Playgrounds).
- Contexto: abrir `CuadernoApp.swiftpm` desde la carpeta de Working Copy cuelga Swift Playgrounds («Se ha producido un error al mostrar los documentos»), incluso después de reinstalarlo. Al desactivar la ubicación de Working Copy en Archivos, Swift Playgrounds vuelve a funcionar.
- Decisión: cuando el CI sale en verde en la rama de prueba, publica `CuadernoApp.zip` en la publicación fija `ultima`. Un Atajo del iPad lo descarga, lo descomprime y sustituye el proyecto en la carpeta Playgrounds. Se puede lanzar al abrir Swift Playgrounds (automatización).
- Límite: el enlace solo funciona con el repositorio **público**. Si pasa a privado, el Atajo necesita una clave de GitHub de solo lectura, que se pega en el iPad y nunca en el repositorio.
- La app de GitHub para iPad no sirve: no descarga repositorios a Archivos.
