# Prueba 001 · Entorno del PC (24-10-2026)

**Objetivo:** saber con qué herramientas se puede construir la app desde el perfil de Windows `learning`.
**Cómo:** consulta de comandos con PowerShell (`Get-Command` y `--version`), sin instalar nada.

| Herramienta | Resultado |
|---|---|
| VS Code | ✅ Instalado en el perfil `usuario`, accesible desde `learning` |
| Python | ✅ 3.14.4 con pip, **mediante `py`**. El comando `python` es el atajo de la Microsoft Store y falla |
| Node / npm | ✅ v24.14.0 / 11.9.0 |
| Git | ✅ 2.47.1 |
| Claude Code | ❌ No instalado |
| GitHub CLI (`gh`) | ❌ No instalado |
| Swift | ❌ No instalado (no hace falta en Windows: la app se compila en GitHub Actions y se ejecuta en el iPad) |

**Prueba extra:** desde el entorno de Cowork, `download.swift.org` está bloqueado por la lista de dominios permitidos. Hay que comprobar si en Claude Code en la nube se puede instalar Swift para los tests del motor.

**Resultado:** se puede construir. Faltan `gh` y Claude Code (Paso 0 del [ROADMAP](../CONSTRUCCION/ROADMAP.md)).
