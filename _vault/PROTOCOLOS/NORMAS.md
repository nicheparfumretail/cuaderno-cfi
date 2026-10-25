# Normas de trabajo

1. **La app sirve al estudio.** Cada funcionalidad tiene que poder explicarse con un concepto contable (partida doble, mayor, saldo, PyG, EBITDA...). Si no, no entra todavía.
2. **Retrieval-first.** Antes de tocar nada se lee [INDEX](../INDEX.md) y la nota del módulo en [CODIGO](../CODIGO/INDEX_CODIGO.md).
3. **Fuente única por dato.** Nada se duplica a mano entre notas: se enlaza. Ningún recuento (archivos, tests, líneas) se escribe a mano; se ejecuta y se mira.
4. **Escritura aditiva en el vault.** No se borran notas ni entradas; se añade sección con fecha.
5. **Cierre de cada sesión de construcción:** entrada en [BITACORA](../CONSTRUCCION/BITACORA.md); decisión nueva → [DECISIONES](../CONSTRUCCION/DECISIONES.md); bug resuelto → [DEBUG-LOG](../CODIGO/DEBUG-LOG.md) con **el concepto contable que se aprendió**; prueba hecha → nota en [PRUEBAS](../PRUEBAS/).
6. **Claude Code en la nube** trabaja sobre el repositorio de GitHub. Antes de cada sesión: leer este archivo y el ROADMAP. Nunca subir secretos (claves de API) al repositorio.
7. **El motor contable no depende de la interfaz.** Los asientos son el único dato; diario, mayor, balance, PyG y KPIs son vistas derivadas.
8. **Archivos de código compartimentados**, menos de 500 líneas cada uno.
