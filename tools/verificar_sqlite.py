# -*- coding: utf-8 -*-
"""
Valida el esquema, el seed y las 9 consultas usando SQLite en memoria.
SQLite se usa solo como motor de prueba: el SQL entregado apunta a
MySQL 8+/MariaDB 10.5+. La unica traduccion es YEAR()/MONTH() -> strftime().
"""
import os
import re
import sqlite3

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def preprocess(sql):
    sql = re.sub(r"YEAR\(([^()]+)\)", r"CAST(strftime('%Y', \1) AS INTEGER)", sql)
    sql = re.sub(r"MONTH\(([^()]+)\)", r"CAST(strftime('%m', \1) AS INTEGER)", sql)
    return sql


def main():
    conn = sqlite3.connect(":memory:")
    conn.execute("PRAGMA foreign_keys = ON")

    conn.executescript(read(os.path.join(BASE, "sql", "01_schema.sql")))
    conn.executescript(read(os.path.join(BASE, "sql", "04_seed.sql")))

    print("=== CONTEOS ===")
    tables = [
        "plan", "genero", "usuario", "oyente", "artista", "disquera",
        "contrato_derechos", "album", "cancion", "cancion_artista",
        "cancion_genero", "playlist", "playlist_cancion", "playlist_seguidor",
        "suscripcion", "calificacion", "favorito_cancion", "favorito_album",
        "favorito_artista", "reproduccion",
    ]
    for t in tables:
        n = conn.execute("SELECT COUNT(*) FROM " + t).fetchone()[0]
        print(f"{t:22s} {n}")

    print("\n=== PRAGMA foreign_key_check ===")
    print(conn.execute("PRAGMA foreign_key_check").fetchall())

    checks = [
        ("RN-03 calificaciones duplicadas", """
            SELECT id_oyente, id_cancion, COUNT(*) FROM calificacion
            GROUP BY id_oyente, id_cancion HAVING COUNT(*) > 1"""),
        ("RN-04 canciones repetidas en playlist", """
            SELECT id_playlist, id_cancion, COUNT(*) FROM playlist_cancion
            GROUP BY id_playlist, id_cancion HAVING COUNT(*) > 1"""),
        ("RN-01 proveedor/id_externo duplicado", """
            SELECT proveedor, id_externo, COUNT(*) FROM cancion
            WHERE proveedor IS NOT NULL
            GROUP BY proveedor, id_externo HAVING COUNT(*) > 1"""),
        ("Usuario sin subtipo o con subtipo multiple", """
            SELECT u.id_usuario, u.tipo_usuario,
                   (SELECT COUNT(*) FROM oyente o WHERE o.id_usuario = u.id_usuario) AS oy,
                   (SELECT COUNT(*) FROM artista a WHERE a.id_usuario = u.id_usuario) AS art,
                   (SELECT COUNT(*) FROM disquera d WHERE d.id_usuario = u.id_usuario) AS dis
            FROM usuario u
            WHERE (u.tipo_usuario = 'OYENTE' AND (SELECT COUNT(*) FROM oyente o WHERE o.id_usuario = u.id_usuario) <> 1)
               OR (u.tipo_usuario = 'ARTISTA' AND (SELECT COUNT(*) FROM artista a WHERE a.id_usuario = u.id_usuario) <> 1)
               OR (u.tipo_usuario = 'DISQUERA' AND (SELECT COUNT(*) FROM disquera d WHERE d.id_usuario = u.id_usuario) <> 1)"""),
        ("Usuario con mas de una suscripcion activa", """
            SELECT id_usuario, COUNT(*) FROM suscripcion
            WHERE estado = 'ACTIVA' AND fecha_fin IS NULL
            GROUP BY id_usuario HAVING COUNT(*) > 1"""),
        ("Artista VINCULADO sin contrato vigente", """
            SELECT a.id_usuario, a.nombre_artistico FROM artista a
            WHERE a.tipo_artista = 'VINCULADO'
              AND NOT EXISTS (SELECT 1 FROM contrato_derechos c
                              WHERE c.id_artista = a.id_usuario AND c.estado_contrato = 'VIGENTE')"""),
        ("Artista INDEPENDIENTE con contrato vigente", """
            SELECT a.id_usuario, a.nombre_artistico FROM artista a
            WHERE a.tipo_artista = 'INDEPENDIENTE'
              AND EXISTS (SELECT 1 FROM contrato_derechos c
                          WHERE c.id_artista = a.id_usuario AND c.estado_contrato = 'VIGENTE')"""),
        ("Seguidor de su propia playlist", """
            SELECT ps.id_playlist, ps.id_oyente FROM playlist_seguidor ps
            JOIN playlist pl ON pl.id_playlist = ps.id_playlist
            WHERE ps.id_oyente = pl.id_oyente"""),
        ("Reproduccion con playlist que no contiene la cancion", """
            SELECT r.id_oyente, r.id_cancion, r.id_playlist_origen
            FROM reproduccion r
            WHERE r.origen = 'PLAYLIST'
              AND NOT EXISTS (SELECT 1 FROM playlist_cancion pc
                              WHERE pc.id_playlist = r.id_playlist_origen
                                AND pc.id_cancion = r.id_cancion)"""),
        ("Segundos escuchados mayores que la duracion", """
            SELECT r.id_oyente, r.id_cancion, r.segundos_escuchados, c.duracion_segundos
            FROM reproduccion r JOIN cancion c ON c.id_cancion = r.id_cancion
            WHERE r.segundos_escuchados > c.duracion_segundos"""),
    ]
    print("\n=== REGLAS DE NEGOCIO (deben salir vacias) ===")
    for name, sql in checks:
        rows = conn.execute(sql).fetchall()
        print(f"{name}: {len(rows)} violaciones")
        if rows:
            print("   ", rows[:5])

    # Pruebas negativas: cada INSERT debe ser rechazado por una restriccion.
    constraint_tests = [
        ("FK compuesta: usuario ARTISTA no puede ser OYENTE",
         "INSERT INTO oyente (id_usuario, apodo_publico, fecha_nacimiento) "
         "VALUES (4, 'x_test', '2000-01-01')"),
        ("FK compuesta: usuario OYENTE no puede ser ARTISTA",
         "INSERT INTO artista (id_usuario, nombre_artistico, biografia, tipo_artista, pais_origen) "
         "VALUES (14, 'x_test', 'x', 'INDEPENDIENTE', 'Colombia')"),
        ("CHECK tipo_usuario",
         "INSERT INTO usuario (id_usuario, correo, nombre_usuario, contrasena_hash, "
         "fecha_registro, pais, tipo_usuario, activo) "
         "VALUES (900, 'x_test@demo.com', 'x_test', 'hash', '2026-01-01', 'Colombia', 'ADMIN', 1)"),
        ("UNIQUE correo",
         "INSERT INTO usuario (id_usuario, correo, nombre_usuario, contrasena_hash, "
         "fecha_registro, pais, tipo_usuario, activo) "
         "VALUES (900, 'aurora.vega@demo.com', 'x_test', 'hash', '2026-01-01', 'Colombia', 'OYENTE', 1)"),
        ("CHECK calificacion 1..5",
         "INSERT INTO calificacion (id_oyente, id_cancion, valor, fecha_calificacion) "
         "VALUES (14, 1, 6, '2026-11-25')"),
        ("PK calificacion duplicada",
         "INSERT INTO calificacion (id_oyente, id_cancion, valor, fecha_calificacion) "
         "VALUES (14, 14, 4, '2026-11-25')"),
        ("UNIQUE proveedor/id_externo",
         "INSERT INTO cancion (id_cancion, titulo_cancion, num_pista, duracion_segundos, "
         "ruta_archivo_audio, es_explicita, id_album, proveedor, id_externo) "
         "VALUES (900, 'x_test', 8, 200, '/audio/x.mp3', 0, 1, 'JAMENDO', 'jam-001')"),
        ("CHECK anio de album",
         "INSERT INTO album (id_album, titulo_album, anio_lanzamiento, tipo_produccion, "
         "portada_url, id_artista, id_disquera) "
         "VALUES (900, 'x_test', 1800, 'LP', '/img/x.jpg', 4, 1)"),
        ("CHECK origen de reproduccion",
         "INSERT INTO reproduccion (id_oyente, id_cancion, fecha_hora_reproduccion, "
         "segundos_escuchados, dispositivo, id_cancion_previa, origen, id_playlist_origen) "
         "VALUES (14, 1, '2026-11-25 03:03:03', 100, 'Web', NULL, 'RADIO', NULL)"),
        ("CHECK playlist obligatoria para origen PLAYLIST",
         "INSERT INTO reproduccion (id_oyente, id_cancion, fecha_hora_reproduccion, "
         "segundos_escuchados, dispositivo, id_cancion_previa, origen, id_playlist_origen) "
         "VALUES (14, 1, '2026-11-25 03:03:03', 100, 'Web', NULL, 'PLAYLIST', NULL)"),
    ]
    print("\n=== PRUEBAS NEGATIVAS DE RESTRICCIONES (deben fallar) ===")
    for name, sql in constraint_tests:
        try:
            conn.execute(sql)
            print(f"FALLO: {name} (la insercion fue aceptada)")
        except sqlite3.IntegrityError as exc:
            print(f"OK: {name} -> {exc}")
    conn.rollback()

    # Consultas de negocio
    queries = read(os.path.join(BASE, "sql", "05_queries.sql"))
    parts = []
    for chunk in re.split(r";\s*\n", queries):
        up = chunk.upper()
        if "WITH" in up and "SELECT" in up:
            parts.append(chunk)

    results_md = ["# Resultados esperados (seed de demostracion)", ""]
    results_md.append("Fecha de corte del seed: 2026-11-25. "
                      "Generado ejecutando las consultas sobre SQLite con los mismos datos.")
    results_md.append("")

    for i, part in enumerate(parts, start=1):
        sql = preprocess(part)
        cur = conn.execute(sql)
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        print(f"\n=== CONSULTA {i} ({len(rows)} filas) ===")
        print(" | ".join(cols))
        for row in rows[:12]:
            print(" | ".join("" if v is None else str(v) for v in row))
        if len(rows) > 12:
            print(f"... ({len(rows) - 12} filas mas)")

        results_md.append(f"## Consulta {i}")
        results_md.append("")
        results_md.append("| " + " | ".join(cols) + " |")
        results_md.append("|" + "|".join(["---"] * len(cols)) + "|")
        for row in rows[:50]:
            results_md.append("| " + " | ".join("" if v is None else str(v) for v in row) + " |")
        if len(rows) > 50:
            results_md.append(f"| ... | ({len(rows) - 50} filas mas) |")
        results_md.append("")

    out = os.path.join(BASE, "docs", "resultados-esperados.md")
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(results_md))
    print("\nResultados guardados en:", out)


if __name__ == "__main__":
    main()
