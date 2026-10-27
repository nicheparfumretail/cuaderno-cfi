"""Copia el motor contable (Sources/CuadernoCore) dentro de la app (CuadernoApp.swiftpm/Core).

Swift Playgrounds solo abre la carpeta .swiftpm, así que el motor tiene que viajar dentro (ADR-005).
La fuente de verdad es Sources/CuadernoCore: Core/ no se edita a mano.

Uso:
    py scripts/sincronizar_core.py              copia el motor a la app
    py scripts/sincronizar_core.py --comprobar  solo comprueba que la copia está al día (lo usa el CI)
"""
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
ORIGEN = RAIZ / "Sources" / "CuadernoCore"
DESTINO = RAIZ / "CuadernoApp.swiftpm" / "Core"


def fuentes(carpeta: Path) -> dict[str, bytes]:
    if not carpeta.exists():
        return {}
    return {p.name: p.read_bytes() for p in sorted(carpeta.glob("*.swift"))}


def main() -> int:
    origen = fuentes(ORIGEN)
    destino = fuentes(DESTINO)

    if "--comprobar" in sys.argv:
        distintos = sorted(n for n in origen.keys() | destino.keys() if origen.get(n) != destino.get(n))
        if distintos:
            print("La copia del motor en la app no está al día:", ", ".join(distintos))
            print("Ejecuta: py scripts/sincronizar_core.py")
            return 1
        print(f"Copia del motor al día ({len(origen)} archivos).")
        return 0

    DESTINO.mkdir(parents=True, exist_ok=True)
    for nombre in destino.keys() - origen.keys():
        (DESTINO / nombre).unlink()
        print("borrado ", nombre)
    for nombre, contenido in origen.items():
        if destino.get(nombre) != contenido:
            (DESTINO / nombre).write_bytes(contenido)
            print("copiado ", nombre)
    return 0


if __name__ == "__main__":
    sys.exit(main())
