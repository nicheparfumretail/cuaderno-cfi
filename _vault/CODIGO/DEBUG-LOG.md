# Debug log

Cada bug resuelto deja una entrada. La columna importante es la última: qué concepto contable quedó claro al arreglarlo.

| Fecha | Síntoma | Causa | Arreglo | Concepto contable aprendido |
|---|---|---|---|---|
| 2026-10-25 | En el iPad, «430 1000» en el Haber salía como «No leo»; el Debe «1000,00 572» sí se leía | Sin paréntesis, el lector solo aceptaba la cuenta si en la fila había un importe con coma | La posición decide: el número pegado al centro es la cuenta (el último en el Debe, el primero en el Haber) y el del borde es el importe | En el diario, la cuenta va junto a la «a» del centro y el importe en el borde de su columna: el lado lo da la posición, no un signo |
| 2026-10-25 | Asiento 2 de Túria a mano: «compros (600)» y «4.900,00 merraderics» salían como «solo leo un número» | «Compras / mercaderías» en dos renglones: la cuenta quedó en uno y el importe en el otro, y cada renglón se leía por separado | Dos renglones seguidos que solos no son apunte y juntos sí se unen, si no hay una raya entre ellos | Un apunte es una cuenta y un importe en el mismo lado: el nombre de la cuenta es solo una ayuda y puede ocupar varias líneas sin cambiar el apunte |
| 2026-10-25 | Las fechas escritas con «/» no se leían; con «-» sí | Vision lee la barra inclinada escrita a mano como un 1 («10/01/25» → «10101125») | Con 8 o 10 cifras y un 1 donde irían las barras, se lee como fecha; si no, el panel recomienda elegirla a mano | — |
