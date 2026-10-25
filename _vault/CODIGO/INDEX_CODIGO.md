# Índice de código

Una nota por módulo cuando exista. Por ahora, el plan:

| Módulo | Qué hará | Estado |
|---|---|---|
| `CuadernoCore/Cuenta` | Código y nombre de cuenta del PGC, grupo, naturaleza | por hacer |
| `CuadernoCore/Asiento` | Fecha, apuntes Debe/Haber, validación Debe = Haber | por hacer |
| `CuadernoCore/Diario` | Lista ordenada de asientos | por hacer |
| `CuadernoCore/Mayor` | Movimientos y saldo de una cuenta | por hacer |
| `CuadernoCore/MapeoKPI` | Tabla cuenta → línea de PyG / EBITDA | por hacer |
| `CuadernoApp/Lienzo` | PencilKit + paleta de Notas + gestos del Pencil | por hacer |
| `CuadernoApp/Reconocedor` | Escritura → apuntes (Vision o Claude) | por hacer |
| `CuadernoApp/VistaDiario` | Asientos en limpio junto al lienzo | por hacer |

## Actualización 25-10-2026 — módulos que ya existen

| Archivo | Qué hace |
|---|---|
| `Sources/CuadernoCore/Importe.swift` | Redondeo a céntimos (mitad hacia arriba), cuota de IVA y retenciones, leer y formatear importes a la española |
| `Sources/CuadernoCore/Fecha.swift` | Fecha contable sin hora («2025-03-31» en JSON, «31/03/2025» en pantalla) |
| `Sources/CuadernoCore/Cuenta.swift` | Código PGC como texto, grupo, subgrupo, validación (≥ 3 dígitos) |
| `Sources/CuadernoCore/PlanDeCuentas.swift` | Tabla de nombres de cuentas y de grupos |
| `Sources/CuadernoCore/Apunte.swift` | Lado (Debe/Haber), cuenta, importe y detalle (tercero) |
| `Sources/CuadernoCore/Asiento.swift` | Asiento + validación de la partida doble; el error dice cuánto falta y en qué lado |
| `Sources/CuadernoCore/Diario.swift` | Lista numerada por empresa; JSON de entrada y salida |
| `Sources/CuadernoCore/Mayor.swift` | Movimientos de una cuenta con saldo acumulado; deudor, acreedor o saldado |
| `Sources/CuadernoCore/BalanceComprobacion.swift` | Sumas y saldos; comprueba que cuadra |
| `Sources/CuadernoCore/MapeoKPI.swift` | KPI como tabla de prefijos de cuenta; EBITDA |
| `Sources/CuadernoCore/CasoTuria.swift` | Los 63 asientos del caso Túria (generado, no se edita a mano) |
| `Tests/CuadernoCoreTests/` | Tests: Túria de punta a punta, reglas del asiento, importes, KPIs |
| `CuadernoApp.swiftpm/App/` | Arranque, estado (`Cuaderno`: diario + lienzo, guardado en Documentos) y pantalla principal |
| `CuadernoApp.swiftpm/Lienzo/` | Lienzo PencilKit, plantilla Debe \| Cuenta \| Haber, reconocedor con Vision |
| `CuadernoApp.swiftpm/Asientos/` | Borrador, editor, diario en limpio, mayor en T y balance |
| `CuadernoApp.swiftpm/Core/` | Copia del motor (ADR-005); se regenera con `py scripts/sincronizar_core.py` |
| `visor-pc/index.html` | Visor del diario en el PC (ADR-006) |
| `.github/workflows/ci.yml` | CI: tests del motor en Linux, copia al día y compilación de la app en macOS |

## Actualización 25-10-2026 (noche) — ADR-008

| Archivo | Qué hace |
|---|---|
| `Sources/CuadernoCore/LectorAsientos.swift` | Palabras con posición → asientos en el formato de Gema (fecha, Debe/Haber por mitad, código entre paréntesis, importe) |
| `Tests/CuadernoCoreTests/LectorAsientosTests.swift` | El ejemplo de la foto de Iulian y confusiones típicas de la letra (S→5, o→0, fecha troceada) |
| `CuadernoApp.swiftpm/Asientos/HojaView.swift` | Diario en limpio de la hoja, en vivo, con cuadre y lo no leído en rojo |
| `CuadernoApp.swiftpm/Lienzo/Reconocedor.swift` | Ahora solo convierte tinta en palabras con posición (Vision) |
| ~~`Asientos/Borrador.swift`, `Asientos/EditorAsientoView.swift`~~ | Eliminados: ya no hay formulario |

## Actualización 25-10-2026 (noche, 3) — ADR-010

| Archivo | Qué hace |
|---|---|
| `Sources/CuadernoCore/DatosHoja.swift` | Zonas ajustables, fechas (a mano → leída → la del anterior), apertura con aviso y recomendaciones |
| `Sources/CuadernoCore/LectorAsientos.swift` | Ahora también separa asientos por rayas (`esSeparador`) y lee con zonas a medida |
| `Tests/CuadernoCoreTests/DatosHojaTests.swift` | Rayas, fechas heredadas, zonas, apertura (con la de Túria) y recomendaciones |
| `CuadernoApp.swiftpm/App/Archivo.swift` | Hojas guardadas (una por archivo) |
| `CuadernoApp.swiftpm/Inicio/` | Inicio con menú circular e histórico |
| `CuadernoApp.swiftpm/Hoja/` | Hoja abierta: lectura en segundo plano, panel plegable, modo En limpio |
| `CuadernoApp.swiftpm/Lienzo/` | Página de ancho fijo con zoom, cabecera con asas de las zonas, rayas fuera de Vision |
| `CuadernoApp.swiftpm/Asientos/` | Panel de lo reconocido, vista En limpio, apuntes, mayor y balance |
| `Sources/CuadernoCore/AgrupadorTrazos.swift` | Cajas de los trazos → renglones por franja (Debe, centro, Haber), siguiendo renglones torcidos y pegando comas y puntos |
| `Sources/CuadernoCore/LectorAsientos.swift` | Ahora lee varias candidatas por renglón y usa la partida doble para elegir (`cuadrar`, `seConfunden`, `cuentaSinImporte`) |
| `CuadernoApp.swiftpm/Lienzo/Reconocedor.swift` | Ahora lee cada renglón aparte (dos imágenes, 5 candidatas) y guarda lo leído por renglón |
| `Tests/CuadernoCoreTests/ReconocimientoTests.swift` | La captura de las 20:49 (814/819, «0,00 … (472)»), renglones de tinta torcidos, comas y puntos |
| `Sources/CuadernoCore/FechaEscrita.swift` | La fecha del centro: día, mes y año con una o dos cifras; barras leídas como 1 o 7 |
| `Sources/CuadernoCore/LectorAsientos+Cuadrar.swift` | La partida doble como prueba de la lectura (sacado de `LectorAsientos` para que no pase de 500 líneas) |
| `Sources/CuadernoCore/Correccion.swift` | Apuntes corregidos o descartados a mano en el panel y cómo se aplican al resolver la hoja |
| `CuadernoApp.swiftpm/Asientos/CorregirApunteView.swift` | Hoja «Corregir apunte»: lado, cuenta e importe con Scribble o teclado |
| `Tests/CuadernoCoreTests/CorreccionesTests.swift` | Fechas de la captura de las 21:18 y correcciones (aplicar, sustituir, descartar, recuperar, hojas viejas) |
| `Sources/CuadernoCore/NombreCuenta.swift` | El nombre escrito como prueba del código: palabras del PGC, parecido entre palabras y códigos a una cifra parecida |
| `Sources/CuadernoCore/AgrupadorTrazos.swift` | Ahora también corta cada renglón en trozos por los huecos |
| `CuadernoApp.swiftpm/Asientos/ApunteEditable.swift` | El apunte corregible en línea (cifra y cuenta como campos, menú al mantener pulsado), igual en el panel y en En limpio. Sustituye a `ApuntesView` y `CorregirApunteView` |
