# Prueba 002 · Primera prueba del prototipo en el iPad (pendiente)

**Objetivo:** comprobar que el prototipo de la rama `paso-0/prototipo` funciona en el iPad con el Pencil.
**Requisito:** CI en verde y `CuadernoApp.swiftpm` abierto en Swift Playgrounds desde Working Copy.

Rellena la columna «Resultado» con ✅, ❌ o lo que hayas visto.

| # | Qué hacer | Qué debería pasar | Resultado |
|---|---|---|---|
| 1 | Pulsar ▶ en Swift Playgrounds | Se abre la app: lienzo a la izquierda con columnas Debe · Cuenta · Haber, diario vacío a la derecha | |
| 2 | Escribir con el Pencil | Trazo como en Notas y paleta de herramientas abajo | |
| 3 | Doble toque y apretón del Pencil Pro | Cambian de herramienta o abren la paleta, como en Notas | |
| 4 | Escribir `1.000` en la columna Debe y `572` en la del centro; debajo, `a 700` en el centro y `1.000` en la columna Haber. Pulsar «Pasar a limpio» | Se abre el editor con 572 al Debe y 700 al Haber, «Cuadra», y «Mueve el EBITDA: +1.000» | |
| 5 | Pulsar «Al diario» | Aparece como asiento nº 1 en el diario | |
| 6 | Pulsar «+», poner 572 Debe 100 y 700 Haber 90 | Avisa «No cuadra… Faltan 10 en el Haber» y no deja guardar | |
| 7 | Más → Cargar el caso Túria | El diario muestra los 63 asientos de Túria | |
| 8 | Mantener pulsada la cuenta (572) en cualquier asiento | Se abre el mayor en T. Saldo deudor: 36.775,20 | |
| 9 | Más → Balance de comprobación | «Cuadra» en verde | |
| 10 | Más → Exportar diario → Guardar en Archivos → iCloud Drive | Se guarda `diario.json` | |
| 11 | En el PC: descargar `diario.json` desde icloud.com y abrirlo con `visor-pc/index.html` | El mismo diario, con su mayor y su balance | |
| 12 | Cerrar la app y volver a abrirla | El lienzo y el diario siguen ahí | |

**Qué apuntar si algo falla:** el número de la fila, una foto o captura y el texto exacto del error. Con eso, Claude Code lo arregla.
