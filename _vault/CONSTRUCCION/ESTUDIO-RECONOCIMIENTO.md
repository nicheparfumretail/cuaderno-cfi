# Estudio de reconocimiento del lienzo (25-10-2026)

Pedido por Iulian tras la captura de las 20:49: retoques pequeños (mover un par de caracteres, reescribir, cambiar la «/» de la fecha por un «-») descuadraban toda la hoja.

## Qué fallaba y por qué

| Síntoma en la captura | Causa |
|---|---|
| «210,00 HP. IVA soportado (472)» llegó como «0,00 HJA oportado (472)» → «no encuentro una cuenta válida» y «Faltan 210 en el Debe» | Vision leyó la **página entera de una vez** y perdió las dos primeras cifras. El importe quedó en 0 y la fila se descartó. Además el aviso era el equivocado: la cuenta (472) sí estaba. |
| 819,00 leído como **814,00** → «Faltan 5 en el Debe» | Confusión 9 ↔ 4 típica de la letra a mano. Solo se usaba la **primera** candidata de Vision, aunque Vision suele traer la buena entre las siguientes. |
| Un retoque mínimo cambia toda la hoja | 1) Cada lectura relee la página entera, y Vision corta las líneas de otra manera cada vez. 2) Las cajas por palabra que da Vision en letra a mano son imprecisas: una línea que cruza el centro reparte mal las palabras entre Debe y Haber. 3) Las filas se agrupaban por la altura de esas cajas. |

## Qué se puede y qué no

- **«Fuerza bruta con todas las letras»**: entrenar un modelo propio exige un Mac (Create ML) y miles de muestras etiquetadas de su letra. Vision ya es una red neuronal entrenada con escritura a mano de mucha gente. Lo que sí se puede hacer por fuerza bruta es **leer varias veces y de varias maneras** y quedarse con la lectura que tiene sentido.
- **«Patrones»**: el mejor patrón que tenemos es la **partida doble**. Un asiento tiene que cuadrar. Esa es una prueba (como el dígito de control de un IBAN) para elegir entre lecturas dudosas.
- **IA externa (Claude por API, con visión)**: lee bien la letra difícil, pero necesita conexión, cuesta dinero por lectura y una clave que se pegaría en el iPad (nunca en el repositorio). Se deja como opción para lo que siga sin cuadrar, **si Iulian lo decide**.

## Qué se ha hecho (capa 1, ADR-011)

1. **Renglones por la tinta, no por Vision** (`AgrupadorTrazos`, en el motor y con tests): los trazos de PencilKit se agrupan en renglones por su geometría, de izquierda a derecha. Así se sigue un renglón algo torcido, las comas y los puntos se pegan a su renglón y nada cruza el centro.
2. **Cada renglón se lee aparte** (recorte en negro sobre blanco), **dos veces** (trazo normal y engordado) y con las **5 mejores candidatas** de cada trozo.
3. **Memoria por renglón**: si los trazos de un renglón no cambian, no se vuelve a leer. Un retoque solo cambia su renglón.
4. **La partida doble elige** (`LectorAsientos.cuadrar`):
   - Si Vision dudó y una de sus candidatas hace cuadrar el asiento, se toma **y se avisa** («dudaba entre 814 y 819: tomo 819… Compruébalo»).
   - Si la cifra parecida (4/9, 1/7, 3/8…) no la propuso Vision, **solo se pregunta** («¿pone 819 y no 814?»). No se corrige solo porque podría ser un error de verdad al escribir, y eso es lo que hay que ver al estudiar.
   - Si una fila trae la cuenta pero no el importe, se dice **cuánto haría falta** («la 472 tendría que llevar 210»).
5. Aviso corregido: «leo la cuenta 472 pero no un importe» en vez de «no encuentro una cuenta válida».

## Siguientes capas (por decidir)

- **Capa 2: corrección rápida.** Tocar un importe o una cuenta en el panel y escribir encima con Scribble. Se guarda como corrección de ese renglón y nunca bloquea.
- **Capa 3: Claude por API** para los asientos que sigan sin cuadrar, con clave puesta en el iPad. Necesita el visto bueno de Iulian (coste y privacidad).
- **Medir**: guardar (en local) las capturas de renglones mal leídos para tener un banco de pruebas con su letra real.
