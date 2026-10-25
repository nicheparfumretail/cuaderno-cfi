# CLAUDE.md — instrucciones para Claude Code

Lo lees al empezar cada sesión. No son sugerencias.

## 1. Qué es esto y para quién

**Cuaderno CFI**: app nativa de iPad (SwiftUI + PencilKit) para estudiar contabilidad.
Iulian escribe asientos a mano con el Apple Pencil Pro en un lienzo como el de Notas y la app
los ordena en limpio en un libro diario que luego se abre en el PC.

- Dueño: Iulian, 2.º GS Administración y Finanzas. Escribe en español; responde en español,
  directo, con el porqué antes que el procedimiento.
- **La app sirve al estudio, no al revés.** Cada funcionalidad debe poder explicarse con un
  concepto contable (partida doble, mayor, saldo, PyG, EBITDA). Si no, no entra todavía.
- Por ahora es **autoestudio**: no hay usuarios externos, ni cuentas, ni servidor.

## 2. Antes de tocar nada (retrieval-first)

1. `_vault/INDEX.md` → punto de entrada.
2. `_vault/PROTOCOLOS/NORMAS.md` y `_vault/CONSTRUCCION/ROADMAP.md` → qué toca ahora.
3. `_vault/CODIGO/INDEX_CODIGO.md` → nota del módulo que vas a tocar.
4. `_vault/CONSTRUCCION/DECISIONES.md` → no reabras una decisión cerrada sin decirlo.

Jerarquía de verdad: lo que hace el código → el código y sus tests. Por qué es así →
DECISIONES y NORMAS. **Contabilidad → el PGC y los apuntes de clase, nunca la app.**

## 3. Restricciones de entorno (lo que hace este proyecto distinto)

- **No hay Mac.** Iulian tiene Windows + iPad. Nadie va a abrir Xcode.
- La app se ejecuta en el iPad con **Swift Playgrounds** (formato `.swiftpm` con
  `AppleProductTypes` / `.iOSApplication`). **Nada de `.xcodeproj`.** Todo lo que uses tiene
  que funcionar dentro de Swift Playgrounds: sin build phases, sin scripts de compilación, sin
  Storyboards, sin dependencias que Playgrounds no resuelva.
- El código llega al iPad así (ADR-009): el CI, en verde, publica `CuadernoApp.zip` en la
  publicación fija `ultima` → un **Atajo** del iPad lo descarga y sustituye el proyecto en la
  carpeta Playgrounds. **No uses Working Copy**: abrir el proyecto desde su carpeta cuelga Swift
  Playgrounds. Iulian no sube cambios desde el iPad. (iCloud para Windows no funciona en su PC.)
  La rama que se publica está en el job `publicar` de `.github/workflows/ci.yml`.
- **La única prueba real de la interfaz es Iulian con el Pencil.** Tú no puedes verla. Por eso
  la lógica tiene que vivir fuera de la interfaz y estar cubierta por tests.

## 4. Estructura del repositorio

```
Package.swift            → paquete CuadernoCore (Swift puro, sin UIKit/SwiftUI)
Sources/CuadernoCore/    → Cuenta, Apunte, Asiento, Diario, Mayor, Balance, mapeo→KPIs
Tests/CuadernoCoreTests/ → tests del motor (corren en Linux: `swift test`)
CuadernoApp.swiftpm/     → la app: SwiftUI + PencilKit (+ Vision más adelante)
.github/workflows/       → CI: Linux para el motor, macOS para compilar la app
_vault/                  → conocimiento del proyecto (ver §8)
```

**Cómo usa la app el motor (ADR-005, 25-10-2026):** el motor se edita SOLO en
`Sources/CuadernoCore/`. Después de tocarlo, ejecuta `py scripts/sincronizar_core.py` (o `python3`
en Linux) para copiarlo a `CuadernoApp.swiftpm/Core/`. El CI falla si la copia no está al día.
Nunca edites `Core/` a mano. `CasoTuria.swift` se genera a partir de la nota del caso Túria; no lo
edites a mano.
Otras piezas: `scripts/` (utilidades) y `visor-pc/index.html` (visor del diario en el PC, ADR-006).

## 5. Reglas del motor contable (CuadernoCore)

- **El asiento es el único dato.** Diario, mayor, balance, PyG y KPIs son vistas derivadas;
  nunca se guardan por separado.
- **Importes en `Decimal`, jamás `Double`.** Redondeo a 2 decimales, half-up, solo al mostrar
  o al calcular cuotas (IVA, retenciones).
- Cuentas por **código del PGC como `String`** (`"572"`, `"4720"`, `"40000001"`). El grupo
  se deduce del primer dígito. Naturaleza deudora/acreedora por grupo y subgrupo, en una tabla.
- **Partida doble obligatoria:** un asiento que no cuadra (Σ Debe ≠ Σ Haber) no se acepta; se
  devuelve el error con la diferencia, que es información de estudio.
- Cada asiento lleva `empresa` desde el día 1 (ADR-002), además de fecha, número, concepto y
  apuntes.
- Mapeo cuenta → línea de PyG / KPI como **tabla de datos**, no como `switch` en el código.
- **Datos de prueba:** los asientos del caso «Túria» del curso. El primer test es su asiento de
  apertura. Si dudas de un tratamiento contable, **pregunta**; no lo inventes.

## 6. Bucle de trabajo y verificación

1. Lee (§2) → propone el cambio en 2-3 líneas → impleméntalo.
2. Motor: `swift test` tiene que pasar. Test nuevo por cada regla contable nueva.
3. App: el workflow de macOS tiene que compilar `CuadernoApp.swiftpm` en verde
   (`xcodebuild ... -destination 'generic/platform=iOS Simulator' build`).
4. **No digas «hecho» sin CI en verde.** Si el CI falla, lee el log y arréglalo tú.
5. Termina siempre con: qué tiene que probar Iulian en el iPad, en pasos concretos
   («dibuja un asiento con 572 al Debe y 700 al Haber; debería aparecer a la derecha cuadrado»).

## 7. Git

- Trabaja en una **rama** por tarea y abre **pull request**. **No fusiones a `main`** ni
  hagas push a `main` hasta que Iulian lo diga explícitamente.
- Mensajes de commit en español, cortos, en imperativo.
- **Nunca** subas secretos: claves de API, tokens, `.env`. Si en el futuro se usa la API de
  Claude para reconocer escritura, la clave se introduce en el iPad en tiempo de ejecución.

## 8. Cierre de cada sesión (sin que te lo pida)

Escritura **aditiva**: se añade con fecha, nunca se borra.

- `_vault/CONSTRUCCION/BITACORA.md` → entrada del día: qué se hizo, qué falló, qué queda.
- Decisión nueva → `_vault/CONSTRUCCION/DECISIONES.md` (ADR numerado).
- Bug resuelto → `_vault/CODIGO/DEBUG-LOG.md` con la columna **«Concepto contable
  aprendido»** rellena cuando aplique. Es la parte que convierte el código en estudio.
- Módulo nuevo o cambiado → su fila en `_vault/CODIGO/INDEX_CODIGO.md`.
- Prueba de Iulian en el iPad → nota en `_vault/PRUEBAS/AAAA-MM-DD_<tema>.md`.
- Ningún recuento escrito a mano (tests, archivos, líneas): se ejecuta y se enlaza.

## 9. Estilo de código

- Archivos de **menos de 500 líneas**, un concepto por archivo.
- Nombres del dominio en español (`Asiento`, `Apunte`, `debe`, `haber`); el resto, Swift
  idiomático. Comentarios en español, explicando el porqué contable cuando lo haya.
- Sin dependencias externas salvo que sean imprescindibles y funcionen en Swift Playgrounds.

## 10. Contexto de calendario

Los créditos de Claude Code caducan el **5-11-2026**. Parcial de Contabilidad el **28-10**:
la construcción va en los ratos libres del estudio. Prioridad: Fase 1 del ROADMAP en orden.
