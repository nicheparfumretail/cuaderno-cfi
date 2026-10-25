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

## ADR-010 · Hojas guardadas, rayas que separan asientos y fecha elegida a mano (25-10-2026)
- Pedido por Iulian tras la primera prueba con su letra (Vision leyó bien «1000,00 572 | 430 1000»).
- **Inicio** sin nada cargado: botón «+» con un arco de opciones (Añadir asiento, Ver histórico), como la paleta del Pencil Pro. «Añadir asiento» pregunta si es el asiento de apertura.
- **Cada hoja se guarda** aparte (`Documentos/hojas/<id>.json`: tinta, datos y lo último leído) y se reabre desde el histórico.
- **Una raya horizontal** (trazo largo y plano) separa un asiento del siguiente. La fecha escrita también separa, pero ya no hace falta.
- **La fecha la elige Iulian** en el panel (su letra para fechas no se lee bien). Si no la elige, se usa la leída y, si tampoco hay, **la del asiento anterior**.
- **Página de ancho fijo** (1000 puntos) que la pantalla escala: la tinta no se descoloca al plegar el panel. Zoom hasta 1,8×. Las zonas Debe | centro | Haber se ensanchan con asas y se guardan en cada hoja.
- **Nunca bloquea:** lo que no se entiende sale como recomendación («falta el Haber», «solo leo un número») y se puede seguir escribiendo.
- **Apertura:** si el primer asiento lleva cuentas de los grupos 6 a 9, se avisa (la apertura solo reabre cuentas de balance). Es un aviso y no impide guardar el asiento.
- Vista **«En limpio»**: la hoja con letra de apuntes, en el formato de clase.

## ADR-011 · Se lee por renglones de tinta y la partida doble elige entre lecturas (25-10-2026)
- Pedido por Iulian tras la captura de las 20:49: un retoque pequeño descuadraba la hoja. El estudio completo está en [ESTUDIO-RECONOCIMIENTO](ESTUDIO-RECONOCIMIENTO.md).
- Los renglones se deciden con la geometría de los trazos (`AgrupadorTrazos`, en el motor), no con las cajas de Vision. Cada renglón se lee aparte, dos veces y con varias candidatas, y la lectura se guarda por renglón.
- Si un asiento no cuadra: la candidata de Vision que lo hace cuadrar se toma avisando; una cifra parecida que Vision no propuso solo se pregunta (puede ser un error real de Iulian, y eso no se tapa); a una fila con cuenta y sin importe se le dice cuánto falta.
- Claude por API queda como capa opcional para lo que siga sin cuadrar, pendiente de que Iulian lo apruebe.

## ADR-012 · Fechas de cualquier forma y correcciones a mano en el panel (25-10-2026)
- Pedido por Iulian tras la captura de las 21:18 («01/10/25» se leyó «01/10125»).
- **Fecha:** siempre día, mes y año, en ese orden. El día y el mes llevan una o dos cifras y el año dos o cuatro. Cualquier cosa que no sea cifra separa. Si faltan separadores, se prueba a tomar un 1 (o un 7) como barra; solo se acepta si sale **una única** fecha válida. Si no, se pide con el selector.
- **Capa 2 del estudio de reconocimiento:** tocar un apunte o una fila sin entender abre «Corregir apunte» (lado, cuenta, importe; Scribble o teclado). Se puede descartar algo que no era un apunte y volver a lo leído.
- La corrección se guarda en la hoja (`DatosHoja.correcciones`) junto a lo que se leyó y la tinta no se toca. Si se reescribe y se lee otra cosa, deja de aplicarse sola. Como las fechas a mano, va por la posición del asiento en la hoja.

## ADR-013 · Corregir en línea, en el panel y en En limpio; el nombre escrito confirma la cuenta (25-10-2026)
- Sustituye la hoja «Corregir apunte» de ADR-012. A Iulian le resultaba incómoda, y además abría con el lado equivocado.
- **Corregir donde está:** la cifra y la cuenta de cada apunte son campos. Se tocan y se escribe encima con el Pencil (el texto queda seleccionado, así que lo nuevo lo sustituye). Al salir del campo se guarda. Si lo escrito no es una cuenta o un importe válidos, vuelve lo que había.
- Manteniendo pulsado: pasar al otro lado, ver el mayor, volver a lo leído o descartar. Las filas sin entender son editables en naranja.
- **Bidireccional:** el panel del lienzo y En limpio usan el mismo componente y guardan en `DatosHoja.correcciones`. Lo corregido en una vista sale en la otra.
- **Lectura por trozos:** cada renglón se corta por sus huecos (importe, nombre, código) y cada trozo se lee aparte. Un número suelto se lee mejor solo («819 … (472)» salía «89»).
- **El nombre confirma el código:** si el nombre escrito encaja mejor con otra cuenta del PGC a una cifra parecida del código leído, se toma esa y se avisa («leo la 608, pero pone mercaderías: tomo la 600»).

## ADR-014 · Mini ventana para corregir, arrastrar apuntes entre asientos y cuadro de cuentas completo (25-10-2026)
- Pedido por Iulian a las 23:11. Corregir escribiendo en los propios campos le resultaba incómodo, sobre todo cuando el reconocimiento dudaba.
- **Mini ventana** al tocar o mantener pulsado un apunte (sustituye la edición en línea de ADR-013). Lleva: Debe/Haber, número de cuenta (el nombre sale solo), importe y ✓. Viene rellena con lo leído, también en una fila sin entender (la cuenta y el primer número que puede ser importe). Si no se sabe el número, se toca el nombre: se escribe una parte del nombre o del número, o se elige del cuadro de cuentas. Abajo: mayor, volver a lo leído y descartar.
- **Arrastrar:** cada apunte tiene un asa (≡). Se suelta en cualquier asiento: en la mitad izquierda va al Debe y en la derecha al Haber. Funciona en el panel y en En limpio. Se guarda como corrección con `destino` en el asiento donde se leyó: «volver a lo leído» lo devuelve a su sitio. Si el asiento destino desaparece, vuelve al suyo.
- **Cuadro de cuentas del PGC** (`PlanDeCuentasPGC.swift`): las cuentas de tres cifras de los grupos 1 a 7, más las de cuatro cifras de IVA y amortización acumulada. Los nombres de los apuntes de clase mandan cuando hay los dos. Los nombres se han escrito de memoria: si alguno no coincide con el PGC oficial o con los apuntes de Gema, se corrige la fila.
- **Fecha editable también en En limpio**, con el mismo selector que el panel.
