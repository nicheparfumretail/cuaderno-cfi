# Prueba 003 · Rueda, mayor con diagrama, En limpio en PDF y modo práctica (pendiente)

**Lo que dijo Iulian de la versión anterior (mini ventana, ADR-014):** le gustan la mini ventana, el libro mayor y el histórico (rescató una hoja). Pidió lo de ADR-015.

**Requisito:** CI en verde y el zip `ultima` instalado con el Atajo.

| # | Qué hacer | Qué debería pasar | Resultado |
|---|---|---|---|
| 1 | En una hoja con asientos, mantener pulsado un apunte (p. ej. Proveedores) | Sale la rueda: Modificar, Libro mayor, Al Debe/Al Haber, Lo leído (si estaba corregido) y Descartar | |
| 2 | Rueda → Modificar | Se abre la mini ventana de siempre | |
| 3 | Rueda → Libro mayor | Arriba, el recorrido de la cuenta (paradas Nº 1, Nº 4…); debajo, la tabla con el saldo | |
| 4 | En el mayor, tocar una parada o una fila | Se cierra, la vista va a ese asiento y lo resalta en amarillo un segundo y medio | |
| 5 | Coger el asa ≡ de un apunte y moverlo, sin esperar, a la mitad derecha de otro asiento | Se ve «Al Debe \| Al Haber» encima del asiento; al soltar, el apunte pasa al Haber de ese asiento | |
| 6 | En limpio: pellizcar, y luego − / + | La hoja se amplía y se reduce (60 %–300 %); el número del centro vuelve al 100 % | |
| 7 | En limpio → botón de compartir → Guardar en Archivos | Se guarda «Diario <fecha>.pdf» con los asientos en el formato de clase y las sumas | |
| 8 | Inicio → + → Practicar ejercicio | Hoja con el panel «Enunciado» vacío y tres botones: Fotos, Archivo y Pegar | |
| 9 | Hacer una captura, «Copiar y eliminar», y pulsar Pegar | La captura aparece en el panel | |
| 10 | Añadir un PDF de varias páginas y un Word | Van uno debajo de otro; el Word se pasa a PDF (si no puede, lo dice) | |
| 11 | Escribir con el Pencil encima de la captura y en el margen; mover con el dedo y ampliar | La tinta se queda pegada a la página al mover y ampliar | |
| 12 | Botón de pantalla completa del enunciado; luego volver | El enunciado ocupa toda la pantalla y vuelve el lienzo | |
| 13 | Escribir un asiento que no cuadre en el lienzo de la práctica | En limpio no dice que no cuadra; «Solución» sí, debajo del asiento | |
| 14 | Cerrar y reabrir la práctica desde el histórico | Siguen el enunciado y las notas | |

## Resultado (26-10-2026)
- 1 a 4 ✅ con matices: la cuenta del centro de la rueda se mezclaba con el texto de detrás; el mayor tenía que abrirse en T y nombrar las contrapartidas.
- 7: el PDF salía, pero con otro aspecto (él quiere el de En limpio, con su fondo oscuro), tardaba sin avisar y no dejaba compartir con Freenotes.
- 8 a 11 ❌ El enunciado se quedaba en blanco al pegar una captura, subir una foto o un PDF. Mantener el dedo no ofrecía «Pegar».
- Pidió además todos los importes con dos decimales. Arreglado en ADR-016.

## Prueba 003b · Tras ADR-016 (pendiente)

| # | Qué hacer | Qué debería pasar | Resultado |
|---|---|---|---|
| 1 | Mantener pulsado un apunte | La rueda tapa lo de detrás (esmerilado) y la cuenta del centro se lee bien | |
| 2 | Mirar cualquier importe (panel, En limpio, mayor, avisos) | Siempre con dos decimales: 1.000,00 | |
| 3 | Practicar ejercicio → copiar una captura → mantener el dedo en el panel → Pegar | La captura sale en el panel | |
| 4 | Botón Pegar de arriba, Fotos y Archivo (un PDF) | Cada cosa sale debajo de la anterior | |
| 5 | En limpio → Exportar en PDF | Sale una rueda de espera y luego la hoja de compartir | |
| 6 | En la hoja de compartir, elegir Freenotes | El PDF se abre en Freenotes con el aspecto de En limpio (fondo negro si el iPad está en oscuro) | |
| 7 | Abrir el mayor de la 400 | Sale en T con «Saldo acreedor …» bajo el Haber; en «Contrapartida», «600 Compras de mercaderías» y «472 HP, IVA soportado» | |
