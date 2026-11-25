# Hell Music — Base de Datos

Proyecto de Bases de Datos (UNAL, 2026-II): modelo relacional, DDL, DCL, seed,
consultas analíticas y pruebas para un reproductor de música tipo Spotify.

**Motor objetivo:** MySQL 8.0.16+ / MariaDB 10.5+ (SQL estándar, sin PostgreSQL).

---

## Contenido

| Archivo | Descripción |
|---------|-------------|
| `sql/01_schema.sql` | DDL de las 20 tablas, claves, `CHECK`, `UNIQUE` e índices. |
| `sql/02_views.sql` | 10 vistas de privacidad y apoyo analítico. |
| `sql/03_roles.sql` | 6 roles y sus privilegios. |
| `sql/04_seed.sql` | Datos de demostración (5.000 reproducciones, 200 canciones, etc.). |
| `sql/05_queries.sql` | 9 consultas de negocio (P1–P9). |
| `sql/06_tests.sql` | 14 consultas de integridad, 30 pruebas negativas y 6 positivas. |
| `tools/generar_seed.py` | Generador reproducible del seed. |
| `tools/verificar_sqlite.py` | Arnés de validación en SQLite. |
| `docs/DOCUMENTACION.md` | Documento principal: problemas, soluciones, diccionario, normalización, ejecución. |
| `docs/modelo-er.md` | Modelo entidad-relación en Mermaid y decisiones de diseño. |
| `docs/resultados-esperados.md` | Resultados de las 9 consultas con el seed. |

---

## Inicio rápido

### 1. Crear la base

```sql
CREATE DATABASE hell_music
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```

### 2. Cargar los scripts en orden

```bash
mysql -u root -p hell_music < sql/01_schema.sql
mysql -u root -p hell_music < sql/02_views.sql
mysql -u root -p hell_music < sql/03_roles.sql
mysql -u root -p hell_music < sql/04_seed.sql
mysql -u root -p hell_music < sql/05_queries.sql
mysql -u root -p hell_music < sql/06_tests.sql
```

En PowerShell use `Get-Content ... -Raw | mysql ...` o, dentro del cliente,
`SOURCE C:/ruta/sql/01_schema.sql;`.

### 3. Verificar

```sql
USE hell_music;
SELECT COUNT(*) FROM usuario;       -- 43
SELECT COUNT(*) FROM cancion;       -- 200
SELECT COUNT(*) FROM reproduccion;  -- 5000
```

---

## Validación sin MySQL

Requiere Python 3.9+ (solo biblioteca estándar).

```bash
python tools/generar_seed.py
python tools/verificar_sqlite.py
```

El arnés carga el esquema y el seed en memoria, verifica las reglas de negocio,
ejecuta 10 pruebas negativas de restricciones y corre las 9 consultas. Escribe
`docs/resultados-esperados.md` con los resultados.

---

## Documentación

- **Problemas encontrados y soluciones:** `docs/DOCUMENTACION.md`, sección 2.
- **Modelo ER y decisiones de diseño:** `docs/modelo-er.md`.
- **Diccionario de datos y normalización:** `docs/DOCUMENTACION.md`, secciones 4 y 5.
- **Reglas de negocio y pruebas:** `docs/DOCUMENTACION.md`, secciones 6 y 11.
- **Resultados de las consultas:** `docs/resultados-esperados.md`.

---

## Notas de compatibilidad

- Los `CHECK` se aplican en MySQL 8.0.16+ y MariaDB 10.2+.
- Los roles nativos requieren MySQL 8.0+ o MariaDB 10.5+.
- No se usa `AUTO_INCREMENT`, `SERIAL`, `JSONB`, `ENUM` ni tipos de PostgreSQL.
- Los identificadores se suministran explícitamente desde el seed o la aplicación.
- La base guarda rutas/URLs de audio, nunca archivos binarios.
