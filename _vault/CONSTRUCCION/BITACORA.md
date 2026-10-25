# Bitácora

## 2026-10-24 · Arranque
- Iulian describe la app (ver VISION) y pide montar el proyecto en `Desktop\Cuaderno-CFI` con vault de protocolos, construcción y código.
- Revisado el entorno del PC: ver [prueba del entorno](../PRUEBAS/2026-10-24_entorno_PC.md).
- Creado este esqueleto (sin código todavía). Sin repositorio git: se crea cuando esté `gh` instalado.
- Decisiones registradas: ADR-001 a ADR-003.

## 24-10-2026 (tarde) — iCloud descartado, CLAUDE.md escrito
- iCloud para Windows: Finalizar → Reparar → Restablecer → reinicio. Sigue fallando; causa en el registro: `iCloudCKKS.exe` colgado al arrancar. Se descarta como vía (ADR-004).
- Revisión de desinstalaciones de 14 días a petición de Iulian: no se perdió ninguna dependencia del sistema; solo desapareció OpenAI Codex (21-22/10). El espacio liberado lo explica el Sensor de almacenamiento.
- Escrito `CLAUDE.md`: entorno sin Mac, formato `.swiftpm`, reglas del motor (Decimal, partida doble, códigos PGC), bucle con CI, git por ramas y PR sin fusionar a `main` sin permiso, cierre de sesión en el vault.
- Lección: se perdió más de media hora peleando con iCloud cuando no era imprescindible. Ante una pieza de infraestructura que falla y tiene sustituto, probar el sustituto antes de depurar.

## 24-10-2026 (noche) — iCloud para Windows: diagnóstico a fondo (sin resolver)
- Causa 1, resuelta: `C:\ProgramData\Apple Computer\iTunes\adi` la creó en feb-2025 la cuenta de Windows «usuario»; «Learning» no podía modificarla, así que el registro del PC ante Apple (anisette) fallaba. Se movió con UAC a `Escritorio\_papelera\icloud-adi-2026-10-24\adi`; iCloud la recreó a nombre de Learning.
- Causa 2, sin resolver y del lado de Apple: con el registro de diagnóstico se vio que, al iniciar sesión, AuthKit pide un token push (`com.apple.idmsauth`). APSDaemon no tiene certificado; lo pide a `albert.apple.com/.../deviceActivation?device=Windows`, Apple responde **sin certificado** («Failed to get client cert»). Sin token, a los ~55 s sale `AKValidateAppleIDCredentials -9106` = «no se ha inicializado en su totalidad». Pasa igual por la wifi de casa y por el punto de acceso del iPhone: no es la red.
- Descartado: red/puertos/DNS/IPv6, almacén de certificados (escribible), raíz de Apple en Windows (no aplica), contraseña.
- Revertido lo que no ayudó: carpetas `SC Info` restauradas, registro de diagnóstico desactivado. La clave vieja `APNSDaemon` queda en la papelera (iCloud generó una nueva).
- Lección: sin registro de diagnóstico se probaron hipótesis a ciegas durante una hora. Para apps de Apple en Windows, activar primero `defaults write APSDaemon.exe ShouldLog YES` dentro del paquete (`Invoke-CommandInDesktopPackage`) y leer el log antes de tocar nada.
- iCloud no es necesario para este proyecto (ADR-004): código por GitHub + Working Copy; archivos sueltos por icloud.com.
- Prueba final desde la cuenta de Windows «usuario» (19:30, carpeta adi limpia a su nombre): APSDaemon vuelve a pedir el certificado a albert y no conecta nunca al servidor de avisos. **Mismo fallo con otro usuario y otra red → es del PC ante Apple, no del perfil.** Se cierra iCloud para Windows. La carpeta adi de Learning queda restaurada; la de «usuario» está en la papelera.
- Decisión: las notas del iPad pasan por **Google Drive** (carpeta compartida). Claude la lee directamente con el conector, aunque el PC esté apagado.
- 24-10 (20:10): caso abierto con Soporte de Apple (Kelvin y Kevin). Hechos sus pasos (desinstalar, Store sin sesión, reiniciar, reinstalar): la 13.4 responde «Update iCloud for Windows to the latest version to sign in»; actualizada a la 15.10 (la Store no actualizaba porque la 13.4 seguía abierta). **Llamada de Apple: domingo 25-10 a las 11:00** (en Google Calendar).

## 25-10-2026 — Prototipo inicial en código (Claude Code en el PC)
- Iulian pide montar el prototipo mientras come. Hecho en la rama `paso-0/prototipo` (sin repositorio en GitHub todavía).
- **Motor `CuadernoCore`** (Swift puro): Cuenta, Apunte, Asiento con partida doble, Diario, Mayor, Balance de comprobación, mapeo a EBITDA como tabla, importes en `Decimal` con redondeo mitad hacia arriba y formato del cuaderno («1.185,80»).
- **Datos de prueba = el caso Túria completo** (63 asientos), generados desde `Vault-Iulian/Contabilidad/CFI_Caso_repaso_Turia_libro_diario.md`. Antes de generarlos se comprobó con un script que los 63 cuadran y que los saldos finales coinciden con la «Comprobación final» de la nota (572 = 36.775,20; 4315 = 8.591; 4751.1 = 992,50 acreedor…).
- **App `CuadernoApp.swiftpm`**: lienzo PencilKit con la paleta de Notas, plantilla Debe | Cuenta | Haber, botón «Pasar a limpio» (Vision lee lo escrito y lo convierte en apuntes para revisar), editor que avisa del descuadre y del impacto en el EBITDA, diario en limpio, mayor en T al mantener pulsada una cuenta, balance de comprobación, exportar JSON y «Cargar el caso Túria».
- **Visor del PC** (`visor-pc/index.html`): abre el `diario.json` exportado; Diario, Mayor y Balance. Probado en el navegador con el caso Túria: saldos y cuadre iguales que en la nota.
- **CI** (`.github/workflows/ci.yml`): Linux pasa los tests del motor; macOS compila la app; un paso comprueba que la copia del motor en la app está al día.
- **Sin verificar:** no hay compilador de Swift en el PC (ni WSL ni Docker). Nada está «hecho» hasta que el CI salga en verde (CLAUDE.md §6) y Iulian lo pruebe en el iPad.
- Decisiones nuevas: ADR-005, ADR-006 y ADR-007.

## 25-10-2026 (tarde) — Repositorio en GitHub y primer CI en verde
- Creado `nicheparfumretail/cuaderno-cfi` (público) desde el Chrome de Iulian; subidos `main` (esqueleto) y `paso-0/prototipo`.
- Primer CI (run 40205942121) en verde a la primera: tests del motor en Linux, copia del motor al día y compilación de la app en macOS. Queda resuelto el riesgo de que `AppleProductTypes` no compilase con `xcodebuild`.
- Pendiente: pull request de `paso-0/prototipo` → `main`, y la primera prueba en el iPad ([PRUEBAS](../PRUEBAS/2026-10-25_primera_prueba_iPad.md)).
- El conector de GitHub de Claude no conecta (su servidor no admite el registro de clientes) y `gh` no está instalado: la subida se hizo con git + Git Credential Manager.

## 25-10-2026 (noche) — Primera prueba en el iPad y lienzo rehecho
- **La app arrancó en el iPad** (Working Copy → Swift Playgrounds → ▶).
- Lo que no funcionó: la plantilla de tres columnas no se parecía al papel de clase, el reconocimiento no leyó «1000 / 572» («no lo he entendido») y el botón «Pasar a limpio» + formulario sobraban. Swift Playgrounds se colgó al cerrarlo a la fuerza.
- Iulian mandó una foto del formato que usa siempre (apuntes de Gema): fecha en el centro sobre la raya; Debe a la izquierda «importe · nombre · (nº)»; «a» en el centro; Haber a la derecha «(nº) · nombre · importe».
- Rehecho (ADR-008): `LectorAsientos` en el motor, con tests construidos a partir de la foto; la app lee la hoja al dejar de escribir y enseña el diario en vivo a la derecha.
- Pendiente: decidir la rama fija `ipad` + automatización de Atajos para que Working Copy actualice solo al abrir Swift Playgrounds.

## 25-10-2026 (noche, 2) — Working Copy cuelga Swift Playgrounds
- Swift Playgrounds daba «error al mostrar los documentos» incluso tras reinstalarlo y borrar sus datos. La causa era la ubicación de Working Copy en Archivos: desactivándola, vuelve a funcionar. Se descarta Working Copy (ADR-009).
- Nueva vía: el CI publica `CuadernoApp.zip` en `releases/download/ultima/` y un Atajo lo instala en Playgrounds.
- Lección: cuando una app de Apple falla al listar documentos, sospechar antes de las ubicaciones de terceros en Archivos (File Providers) que de la propia app.

## 25-10-2026 (noche, 3) — Primera lectura buena de su letra y rediseño de la app
- Captura de las 19:59: Vision leyó bien `1000,00 572 | 430 1000`. Fallaba la regla del Haber sin paréntesis; ahora la cuenta es el número pegado al centro (DEBUG-LOG).
- Iulian pidió el rediseño completo (ADR-010): inicio con «+» y menú circular, histórico, apertura, panel plegable y redimensionable, zoom, zonas ajustables, rayas como separador, fecha a mano heredable, vista En limpio y recomendaciones sin bloquear.
- Todo en `paso-0/prototipo`; el CI publica el zip para el iPad. Pendiente: que Iulian lo pruebe.

## 25-10-2026 (noche, 4) — Estudio de reconocimiento
- Captura de las 20:49: «210,00 … (472)» leído como «0,00 HJA oportado (472)» y 819 leído como 814. Además, cualquier retoque movía toda la hoja.
- Estudio en [ESTUDIO-RECONOCIMIENTO](ESTUDIO-RECONOCIMIENTO.md) y capa 1 hecha (ADR-011): renglones por la tinta, lectura por renglón con candidatas y memoria, y la partida doble como prueba.
- Pendiente: que Iulian lo pruebe con su letra; decidir la capa 2 (corrección con Scribble) y la 3 (Claude por API).

## 25-10-2026 (noche, 5) — Fechas y corrección a mano
- Prueba de las 21:18: el asiento de anticipo (407 + 472 / 400) se leyó y cuadró; la fecha «01/10/25» llegó como «01/10125».
- Hecho (ADR-012): lectura de fechas con una o dos cifras y barras leídas como 1 o 7, y capa 2 (corregir apuntes tocándolos en el panel).
- Pendiente: que Iulian pruebe la corrección con Scribble y decidir la capa 3 (Claude por API).

## 25-10-2026 (noche, 6) — Corrección en línea
- Prueba de las 22:48: la hoja de corregir era incómoda y abría con «Debe» en un apunte del Haber. «(600)» se leyó «(608)» y «819» se leyó «89» al cerrar el paréntesis de la (472).
- Hecho (ADR-013): corrección en línea en el panel y en En limpio, lectura por trozos y el nombre escrito como prueba del código.
- Pendiente: que Iulian lo pruebe; decidir la capa 3 (Claude por API).

## 25-10-2026 (noche, 7) — Mini ventana, arrastrar apuntes y PGC
- Prueba de las 23:11: la edición en línea funcionaba pero era incómoda.
- Hecho (ADR-014): mini ventana de corrección con el cuadro de cuentas del PGC, apuntes que se arrastran entre asientos y lados, y fecha editable en En limpio. CI en verde.
- Pendiente: que Iulian lo pruebe y revise los nombres del cuadro de cuentas; decidir la capa 3 (Claude por API).
