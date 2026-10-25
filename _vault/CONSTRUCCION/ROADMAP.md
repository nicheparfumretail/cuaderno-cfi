# Roadmap

## Paso 0 — montar el entorno (lo hace Iulian, con ayuda)
- [ ] iPad: instalar **Swift Playgrounds** y crear un proyecto «App» guardado en iCloud.
- [ ] PC: **iCloud para Windows** con iCloud Drive; comprobar que aparece la carpeta de Playgrounds.
- [ ] PC: instalar **GitHub CLI** (`gh`) e iniciar sesión.
- [ ] PC: instalar **Claude Code** (`npm install -g @anthropic-ai/claude-code`) o usarlo desde la web.
- [ ] Crear el repositorio `cuaderno-cfi` en GitHub y subir este esqueleto.
- [ ] Decidir público o privado (ver DECISIONES).

## Fase 1 — lienzo + asientos en limpio
1. CuadernoCore: Cuenta, Apunte, Asiento con validación de cuadre + tests. Primer test: el asiento de apertura de Túria.
2. App mínima: lienzo PencilKit a pantalla completa con la paleta de Notas.
3. Plantilla Debe | Haber y reconocimiento de lo escrito.
4. Diario en limpio al lado del lienzo; guardar en JSON.
5. Visor en el PC.

## Fase 2 en adelante
Mayor al mantener pulsada una cuenta · impacto en el EBITDA · flujos de caja.

## Orden con los estudios
Parcial de Contabilidad el **28-10**. La construcción va en los ratos de descanso del estudio, y los primeros datos de prueba son los propios asientos de Túria.

## Actualización 24-10-2026 — Paso 0 revisado (ver ADR-004)
- [x] ~~iCloud para Windows~~ → descartado; sustituido por Working Copy en el iPad.
- [x] `CLAUDE.md` en la raíz con las instrucciones para Claude Code.
- [ ] iPad: Swift Playgrounds → «+ App» → ▶ → ver «Hello, world!».
- [ ] iPad: instalar **Working Copy**.
- [ ] Crear el repo `cuaderno-cfi` en GitHub (recomendado público) y subir este esqueleto.
- [ ] Primera sesión de Claude Code: resolver cómo usa la app el motor (CLAUDE.md §4) + CI Linux y macOS en verde.

## Actualización 25-10-2026 — prototipo en código (rama `paso-0/prototipo`)
Escrito, pendiente del CI en verde y de la prueba en el iPad:
- [~] Fase 1.1 CuadernoCore + tests (con el caso Túria completo).
- [~] Fase 1.2 Lienzo PencilKit con la paleta de Notas.
- [~] Fase 1.3 Plantilla Debe | Cuenta | Haber + reconocimiento con Vision (ADR-007).
- [~] Fase 1.4 Diario en limpio al lado del lienzo; guardado en JSON.
- [~] Fase 1.5 Visor en el PC (ADR-006). Probado en el navegador con Túria.
- Extra adelantado de la fase 2: mayor en T al mantener pulsada una cuenta, e impacto en el EBITDA de cada asiento en el editor.

Lo que falta para cerrar el Paso 0, en orden:
1. Crear el repositorio `cuaderno-cfi` en GitHub y subir la rama.
2. CI en verde (Linux y macOS). Si falla, se lee el log y se arregla.
3. Working Copy: clonar el repositorio → abrir `CuadernoApp.swiftpm` en Swift Playgrounds → ▶.
4. Prueba en el iPad: ver [PRUEBAS/2026-10-25_primera_prueba_iPad.md](../PRUEBAS/2026-10-25_primera_prueba_iPad.md).
