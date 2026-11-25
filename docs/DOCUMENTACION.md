# Hell Music — Documentación del proyecto

**Proyecto:** Hell Music (reproductor de música tipo Spotify)
**Curso:** Bases de Datos — Universidad Nacional de Colombia, 2026-II
**Entregable:** modelo relacional, DDL, DCL, seed, consultas, pruebas y documentación
**Motor objetivo:** MySQL 8.0+ / MariaDB 10.5+ (SQL estándar, sin PostgreSQL)
**Fecha de corte del seed:** 2026-11-25

---

## 1. Resumen ejecutivo

Se construyó una base de datos relacional completa para Hell Music a partir de
las fichas F1–F12. El resultado corrige las incoherencias detectadas entre
fichas y agrega las entidades que faltaban para que las nueve preguntas de
negocio de F10 sean respondibles con SQL.

| Componente | Resultado |
|------------|-----------|
| Tablas | 20 |
| Vistas | 10 |
| Roles | 6 (`rol_publico`, `rol_oyente`, `rol_artista`, `rol_disquera`, `rol_analista`, `rol_admin`) |
| Índices de apoyo | 13 |
| Datos de demostración | 43 usuarios, 30 álbumes, 200 canciones, 20 playlists, 5.000 reproducciones |
| Consultas de negocio | 9 (P1–P9) |
| Pruebas de integridad | 14 consultas + 10 pruebas negativas + 6 pruebas positivas |
| Validación ejecutada | SQLite en memoria (esquema, seed, reglas y 9 consultas) |

La validación automatizada reportó:

- 0 violaciones de las 10 reglas de negocio verificadas.
- 0 filas huérfanas (`PRAGMA foreign_key_check`).
- Las 10 inserciones inválidas fueron rechazadas por el motor.
- Las 9 consultas devolvieron resultados no vacíos y coherentes.

---

## 2. Problemas e incoherencias encontradas

### 2.1. Tabla de hallazgos

| ID | Fuente | Problema | Impacto | Solución aplicada |
|----|--------|----------|---------|-------------------|
| P01 | F6 vs. F9 | F6 excluye la administración de contratos, pero F9 define `CONTRATO_DERECHOS`. | Contradicción de alcance. | Se conserva como tabla histórica de consulta; la gestión operativa queda fuera de alcance. |
| P02 | RF-5, RN-03 | No existía entidad para calificaciones. | RF-5 y RN-03 no se podían implementar. | Tabla `calificacion` con PK `(id_oyente, id_cancion)` y `valor` 1–5. |
| P03 | F6 | El proceso de favoritos no tenía entidad. | No se podía persistir qué marcaba un oyente. | Tres tablas: `favorito_cancion`, `favorito_album`, `favorito_artista`. |
| P04 | F10-Q5 | No se modelaban los seguidores de playlists. | La pregunta 5 no tenía datos. | Tabla `playlist_seguidor` con PK `(id_playlist, id_oyente)`. |
| P05 | F10-Q2/Q4 | "Premium" aparecía sin tabla de planes ni suscripciones. | No se podía comparar gratis vs. premium ni detectar usuarios que debían pagar. | Catálogo `plan` + historial `suscripcion`. |
| P06 | F10-Q3 | No se registraba el origen de cada reproducción. | No se podía calcular el porcentaje por origen. | Columnas `origen` e `id_playlist_origen` con `CHECK` de coherencia. |
| P07 | RF-6, RF-7 | No se registraba la canción previa. | No se podía analizar continuidad ni recomendaciones. | `reproduccion.id_cancion_previa` con FK a `cancion`. |
| P08 | RF-2, RN-01 | No se distinguía el origen externo de una canción. | Riesgo de duplicar canciones importadas. | `proveedor` + `id_externo` con `UNIQUE (proveedor, id_externo)`. |
| P09 | F1, F9 | Herencia inconsistente: `ARTISTA` usaba `id_artista` y `DISQUERA` se autenticaba sin ser subclase de usuario. | Tres identificadores distintos para el mismo concepto y autenticación incompleta. | Superclase `usuario`; subclases con PK = FK y FK compuesta `(id_usuario, tipo_usuario)`. |
| P10 | F11 vs. F10 | F11 dice 5 preguntas de negocio; F10 define 9. | Alcance ambiguo. | Se implementaron las 9 y se documentó la diferencia. |
| P11 | F2 vs. F5/RN-02 | F2 permitía que "los usuarios" subieran música; F5/RN-02 dice que solo artistas publican. | Conflicto de permisos. | Solo `artista`/`disquera` publican álbumes y canciones; el oyente crea playlists y califica. |
| P12 | F6 vs. RF-1 | F6 no menciona perfiles de disquera, pero RF-1 incluye su autenticación. | Perfil sin modelo. | `disquera` es subclase de `usuario` y puede autenticarse. |
| P13 | RN-01 | No se definía si el audio se guardaba en la base o por enlace. | Riesgo de diseñar una BD inviable por tamaño. | `ruta_archivo_audio` guarda URL/ruta; nunca binarios. |
| P14 | RN-06 vs. F9 | "Artista independiente" y "artista vinculado" no tenían regla de consistencia. | Estados contradictorios con contratos. | `tipo_artista` + validación contra `contrato_derechos` en pruebas. |
| P15 | F3, F6, F9 | Relaciones sin definir: dueño del álbum, canción–artista, canción–género. | El modelo no representaba colaboraciones ni géneros múltiples. | `album.id_artista` obligatorio; `cancion_artista` y `cancion_genero` como M:N. |
| P16 | F10 | "Premium" se usaba como etiqueta sin beneficios definidos. | No se sabía qué columnas cambiar según el plan. | `plan` y `suscripcion` modelan el estado; los beneficios concretos quedan como regla de aplicación. |
| P17 | F1 | Falta el código de Elian en la tabla de integrantes. | Trámite administrativo pendiente. | Se documenta como pendiente; no afecta el modelo. |
| P18 | F1–F12 | Terminología mixta: canción/tema/track, álbum/disco, oyente/usuario. | Ambigüedad en especificaciones y consultas. | Glosario único y nombres consistentes en el esquema. |

### 2.2. Alcance corregido

| Dentro de alcance | Fuera de alcance |
|-------------------|------------------|
| Registro y autenticación de oyentes, artistas y disqueras. | Pasarela de pagos y facturación. |
| Catálogo de álbumes, canciones, artistas y géneros. | Reproducción de audio desde la base (solo se guarda el enlace). |
| Playlists, favoritos, calificaciones y reproducciones. | Mensajería, notificaciones y redes sociales. |
| Historial de contratos artista–disquera. | Gestión operativa de contratos (altas, renovaciones, liquidación). |
| Planes gratuito/premium y suscripciones. | Beneficios concretos del plan premium (límites, calidad, descargas). |
| Consultas analíticas de F10. | Recomendador automático y machine learning. |
| Roles y permisos básicos. | Seguridad a nivel de fila portable (se resuelve en la aplicación). |

---

## 3. Arquitectura de datos

### 3.1. Dominios

| Dominio | Tablas |
|---------|--------|
| Identidad | `usuario`, `oyente`, `artista`, `disquera` |
| Catálogo musical | `album`, `cancion`, `genero`, `cancion_artista`, `cancion_genero` |
| Consumo | `playlist`, `playlist_cancion`, `playlist_seguidor`, `calificacion`, `favorito_cancion`, `favorito_album`, `favorito_artista`, `reproduccion` |
| Monetización | `plan`, `suscripcion` |
| Contratos | `contrato_derechos` |

### 3.2. Jerarquía de usuarios

```
usuario (id_usuario, correo, nombre_usuario, contrasena_hash, ...)
   ├── oyente   (id_usuario PK/FK, tipo_usuario='OYENTE', apodo_publico, ...)
   ├── artista  (id_usuario PK/FK, tipo_usuario='ARTISTA', nombre_artistico, ...)
   └── disquera (id_usuario PK/FK, tipo_usuario='DISQUERA', nit, ...)
```

Cada subclase tiene:

- `id_usuario` como PK y FK.
- `tipo_usuario` con `DEFAULT` y `CHECK` del valor que le corresponde.
- FK compuesta `(id_usuario, tipo_usuario)` → `usuario(id_usuario, tipo_usuario)`.

Esto garantiza que un usuario no pueda pertenecer a dos subclases distintas y
que el tipo declarado en `usuario` coincida con la subclase. Es una solución
sin triggers, portable a MySQL/MariaDB.

### 3.3. Relaciones M:N

| Relación | Tabla | PK compuesta | Atributos |
|----------|-------|--------------|-----------|
| Canción–artista | `cancion_artista` | `(id_cancion, id_artista)` | `rol` (`PRINCIPAL`, `FEATURING`) |
| Canción–género | `cancion_genero` | `(id_cancion, id_genero)` | — |
| Playlist–canción | `playlist_cancion` | `(id_playlist, id_cancion)` | `orden`, `fecha_agregado` |
| Playlist–seguidor | `playlist_seguidor` | `(id_playlist, id_oyente)` | `fecha_seguimiento` |

### 3.4. Acciones referenciales

| FK | Acción | Motivo |
|----|--------|--------|
| `oyente/artista/disquera` → `usuario` | `ON DELETE CASCADE` | Si se elimina la cuenta, se elimina su perfil. |
| `playlist` → `oyente` | `ON DELETE CASCADE` | Las playlists no tienen sentido sin su creador. |
| `playlist_cancion` → `playlist` | `ON DELETE CASCADE` | Al borrar una playlist se borra su contenido. |
| `playlist_seguidor` → `playlist`/`oyente` | `ON DELETE CASCADE` | Relación de seguimiento dependiente. |
| `calificacion` → `oyente`/`cancion` | `ON DELETE CASCADE` | La calificación depende de ambos. |
| `favorito_*` → `oyente`/entidad | `ON DELETE CASCADE` | El favorito depende de ambos. |
| `cancion_artista` → `cancion` | `ON DELETE CASCADE` | La colaboración depende de la canción. |
| `cancion_genero` → `cancion` | `ON DELETE CASCADE` | La clasificación depende de la canción. |
| `album` → `artista` | `RESTRICT` (implícito) | No se borra un artista con álbumes. |
| `cancion` → `album` | `RESTRICT` (implícito) | No se borra un álbum con canciones. |
| `reproduccion` → `oyente`/`cancion` | `RESTRICT` (implícito) | El historial no debe perderse por borrar una canción. |
| `suscripcion` → `usuario`/`plan` | `RESTRICT` (implícito) | El historial financiero no debe perderse. |
| `contrato_derechos` → `artista`/`disquera` | `RESTRICT` (implícito) | El historial contractual no debe perderse. |

### 3.5. Decisiones de compatibilidad

- No se usa `AUTO_INCREMENT`: los identificadores se suministran desde el seed
  o la aplicación. Esto facilita la reproducibilidad y evita dependencias del
  motor.
- No se usa `SERIAL`, `JSONB`, `ENUM` ni tipos propietarios de PostgreSQL.
- Los dominios cerrados se implementan con `VARCHAR` + `CHECK`, portables a
  MySQL 8.0.16+ y MariaDB 10.5+.
- Las fechas se escriben como literales `'YYYY-MM-DD'`; no se usa
  `DATE '...'` para mantener compatibilidad con SQLite en la validación.
- Los top-N se resuelven con `ROW_NUMBER()` en lugar de `LIMIT`/`TOP`, para
  que la consulta sea portable y permita particiones por país o plan.

---

## 4. Diccionario de datos

> Convención: `Nulo = No` significa `NOT NULL`. Las claves se indican como
> `PK` (primaria), `FK` (foránea) y `UK` (única). Los `CHECK` se resumen en la
> columna de descripción y se detallan en la sección 6.

### 4.1. `plan`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_plan` | INTEGER | No | PK. Identificador del plan. |
| `nombre_plan` | VARCHAR(20) | No | UK. `GRATUITO` o `PREMIUM`. |
| `precio_mensual` | NUMERIC(10,2) | No | Precio mensual; `>= 0`. |

### 4.2. `genero`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_genero` | INTEGER | No | PK. Identificador del género. |
| `nombre_genero` | VARCHAR(50) | No | UK. Nombre del género. |
| `descripcion` | VARCHAR(300) | Sí | Descripción libre. |

### 4.3. `usuario`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_usuario` | INTEGER | No | PK. Identificador único. |
| `correo` | VARCHAR(120) | No | UK. Correo de autenticación. |
| `nombre_usuario` | VARCHAR(50) | No | UK. Nombre de usuario. |
| `contrasena_hash` | VARCHAR(255) | No | Hash de contraseña; nunca texto plano. |
| `fecha_registro` | DATE | No | Fecha de alta. |
| `pais` | VARCHAR(60) | No | País del usuario. |
| `tipo_usuario` | VARCHAR(10) | No | `OYENTE`, `ARTISTA` o `DISQUERA`. |
| `activo` | BOOLEAN | No | Estado de la cuenta; por defecto `TRUE`. |

**Claves:** PK `id_usuario`; UK `correo`, `nombre_usuario`, `(id_usuario, tipo_usuario)`.
**Regla:** `tipo_usuario` debe pertenecer al dominio.

### 4.4. `oyente`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_usuario` | INTEGER | No | PK/FK a `usuario`. |
| `tipo_usuario` | VARCHAR(10) | No | Discriminador; por defecto `OYENTE`. |
| `apodo_publico` | VARCHAR(50) | No | UK. Nombre visible en playlists. |
| `fecha_nacimiento` | DATE | Sí | Fecha de nacimiento. |

**Claves:** PK `id_usuario`; FK compuesta `(id_usuario, tipo_usuario)`; UK `apodo_publico`.
**Regla:** `tipo_usuario = 'OYENTE'`.

### 4.5. `artista`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_usuario` | INTEGER | No | PK/FK a `usuario`. |
| `tipo_usuario` | VARCHAR(10) | No | Discriminador; por defecto `ARTISTA`. |
| `nombre_artistico` | VARCHAR(80) | No | UK. Nombre público. |
| `biografia` | VARCHAR(500) | Sí | Biografía. |
| `tipo_artista` | VARCHAR(15) | No | `INDEPENDIENTE` o `VINCULADO`. |
| `pais_origen` | VARCHAR(60) | No | País de origen. |

**Claves:** PK `id_usuario`; FK compuesta `(id_usuario, tipo_usuario)`; UK `nombre_artistico`.
**Regla:** `tipo_usuario = 'ARTISTA'`; `tipo_artista` en el dominio; consistencia con contrato validada en pruebas.

### 4.6. `disquera`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_usuario` | INTEGER | No | PK/FK a `usuario`. |
| `tipo_usuario` | VARCHAR(10) | No | Discriminador; por defecto `DISQUERA`. |
| `nit` | VARCHAR(20) | No | UK. Identificación tributaria. |
| `razon_social` | VARCHAR(120) | No | UK. Nombre legal. |
| `pais_sede` | VARCHAR(60) | No | País de la sede. |
| `correo_contacto` | VARCHAR(120) | No | Correo de contacto. |

**Claves:** PK `id_usuario`; FK compuesta `(id_usuario, tipo_usuario)`; UK `nit`, `razon_social`.
**Regla:** `tipo_usuario = 'DISQUERA'`.

### 4.7. `contrato_derechos`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_contrato` | INTEGER | No | PK. Identificador del contrato. |
| `id_artista` | INTEGER | No | FK a `artista`. |
| `id_disquera` | INTEGER | No | FK a `disquera`. |
| `fecha_inicio` | DATE | No | Inicio del contrato. |
| `fecha_fin` | DATE | Sí | Fin; `NULL` si está vigente. |
| `porcentaje_regalias` | NUMERIC(5,2) | No | Porcentaje 0–100. |
| `estado_contrato` | VARCHAR(12) | No | `VIGENTE`, `FINALIZADO` o `SUSPENDIDO`. |

**Claves:** PK `id_contrato`; FK `id_artista`, `id_disquera`; UK `(id_artista, id_disquera, fecha_inicio)`.
**Reglas:** regalías 0–100; `fecha_fin > fecha_inicio` si existe; estado en el dominio.

### 4.8. `album`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_album` | INTEGER | No | PK. Identificador del álbum. |
| `titulo_album` | VARCHAR(120) | No | Título. |
| `anio_lanzamiento` | INTEGER | No | Año 1900–2100. |
| `tipo_produccion` | VARCHAR(10) | No | `LP`, `EP` o `SENCILLO`. |
| `portada_url` | VARCHAR(255) | Sí | URL de la portada. |
| `id_artista` | INTEGER | No | FK al artista dueño. |
| `id_disquera` | INTEGER | Sí | FK a la disquera; `NULL` si es independiente. |

**Claves:** PK `id_album`; FK `id_artista`, `id_disquera`; UK `(id_artista, titulo_album, anio_lanzamiento)`.
**Reglas:** año en rango; tipo en el dominio.

### 4.9. `cancion`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_cancion` | INTEGER | No | PK. Identificador de la canción. |
| `titulo_cancion` | VARCHAR(150) | No | Título. |
| `num_pista` | INTEGER | Sí | Número de pista; `> 0`. |
| `duracion_segundos` | INTEGER | No | Duración; `> 0`. |
| `ruta_archivo_audio` | VARCHAR(500) | No | URL o ruta del audio; nunca el binario. |
| `es_explicita` | BOOLEAN | No | Contenido explícito; por defecto `FALSE`. |
| `id_album` | INTEGER | Sí | FK al álbum; `NULL` para sencillos sueltos. |
| `proveedor` | VARCHAR(10) | Sí | `PROPIO`, `JAMENDO` o `AUDIUS`. |
| `id_externo` | VARCHAR(100) | Sí | Identificador en el proveedor. |

**Claves:** PK `id_cancion`; FK `id_album`; UK `(proveedor, id_externo)`.
**Reglas:** duración `> 0`; pista `> 0`; si hay álbum debe haber pista; proveedor e `id_externo` van juntos o ambos `NULL`.

### 4.10. `cancion_artista`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_cancion` | INTEGER | No | PK/FK a `cancion`. |
| `id_artista` | INTEGER | No | PK/FK a `artista`. |
| `rol` | VARCHAR(12) | No | `PRINCIPAL` o `FEATURING`. |

**Claves:** PK `(id_cancion, id_artista)`; FK a ambas tablas.
**Regla:** rol en el dominio.

### 4.11. `cancion_genero`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_cancion` | INTEGER | No | PK/FK a `cancion`. |
| `id_genero` | INTEGER | No | PK/FK a `genero`. |

**Claves:** PK `(id_cancion, id_genero)`; FK a ambas tablas.

### 4.12. `playlist`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_playlist` | INTEGER | No | PK. Identificador de la playlist. |
| `id_oyente` | INTEGER | No | FK al creador. |
| `nombre_playlist` | VARCHAR(100) | No | Nombre. |
| `tematica` | VARCHAR(100) | Sí | Temática libre. |
| `fecha_creacion` | DATE | No | Fecha de creación. |
| `es_publica` | BOOLEAN | No | Visibilidad; por defecto `TRUE`. |

**Claves:** PK `id_playlist`; FK `id_oyente`; UK `(id_oyente, nombre_playlist)`.

### 4.13. `playlist_cancion`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_playlist` | INTEGER | No | PK/FK a `playlist`. |
| `id_cancion` | INTEGER | No | PK/FK a `cancion`. |
| `orden` | INTEGER | No | Posición; `> 0`. |
| `fecha_agregado` | DATE | No | Fecha de inclusión. |

**Claves:** PK `(id_playlist, id_cancion)`; UK `(id_playlist, orden)`; FK a ambas tablas.
**Regla:** no se repite una canción en la misma playlist (PK); no se repite el orden (UK).

### 4.14. `playlist_seguidor`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_playlist` | INTEGER | No | PK/FK a `playlist`. |
| `id_oyente` | INTEGER | No | PK/FK a `oyente`. |
| `fecha_seguimiento` | DATE | No | Fecha en que empezó a seguirla. |

**Claves:** PK `(id_playlist, id_oyente)`; FK a ambas tablas.
**Regla:** un oyente no debe seguir su propia playlist (validado en pruebas).

### 4.15. `suscripcion`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_suscripcion` | INTEGER | No | PK. Identificador del contrato de suscripción. |
| `id_usuario` | INTEGER | No | FK al usuario. |
| `id_plan` | INTEGER | No | FK al plan. |
| `fecha_inicio` | DATE | No | Inicio. |
| `fecha_fin` | DATE | Sí | Fin; `NULL` si está activa. |
| `estado` | VARCHAR(10) | No | `ACTIVA`, `CANCELADA` o `VENCIDA`. |

**Claves:** PK `id_suscripcion`; FK `id_usuario`, `id_plan`.
**Reglas:** `fecha_fin >= fecha_inicio` si existe; estado en el dominio; una sola suscripción `ACTIVA` por usuario (regla de aplicación validada en pruebas).

### 4.16. `calificacion`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_oyente` | INTEGER | No | PK/FK a `oyente`. |
| `id_cancion` | INTEGER | No | PK/FK a `cancion`. |
| `valor` | INTEGER | No | Calificación 1–5. |
| `fecha_calificacion` | DATE | No | Fecha de la calificación. |

**Claves:** PK `(id_oyente, id_cancion)`; FK a ambas tablas.
**Regla:** una calificación por oyente/canción (PK); valor 1–5.

### 4.17. `favorito_cancion`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_oyente` | INTEGER | No | PK/FK a `oyente`. |
| `id_cancion` | INTEGER | No | PK/FK a `cancion`. |
| `fecha_marcado` | DATE | No | Fecha en que se marcó. |

**Claves:** PK `(id_oyente, id_cancion)`; FK a ambas tablas.

### 4.18. `favorito_album`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_oyente` | INTEGER | No | PK/FK a `oyente`. |
| `id_album` | INTEGER | No | PK/FK a `album`. |
| `fecha_marcado` | DATE | No | Fecha en que se marcó. |

**Claves:** PK `(id_oyente, id_album)`; FK a ambas tablas.

### 4.19. `favorito_artista`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_oyente` | INTEGER | No | PK/FK a `oyente`. |
| `id_artista` | INTEGER | No | PK/FK a `artista`. |
| `fecha_marcado` | DATE | No | Fecha en que se marcó. |

**Claves:** PK `(id_oyente, id_artista)`; FK a ambas tablas.

### 4.20. `reproduccion`

| Columna | Tipo | Nulo | Descripción |
|---------|------|------|-------------|
| `id_oyente` | INTEGER | No | PK/FK a `oyente`. |
| `id_cancion` | INTEGER | No | PK/FK a `cancion`. |
| `fecha_hora_reproduccion` | TIMESTAMP | No | PK. Instante exacto. |
| `segundos_escuchados` | INTEGER | No | Segundos escuchados; 0–86.400. |
| `dispositivo` | VARCHAR(50) | Sí | Dispositivo de escucha. |
| `id_cancion_previa` | INTEGER | Sí | FK a la canción anterior. |
| `origen` | VARCHAR(16) | No | `PLAYLIST`, `RECOMENDACION`, `BUSQUEDA`, `ALBUM` u `OTRO`. |
| `id_playlist_origen` | INTEGER | Sí | FK a la playlist de origen. |

**Claves:** PK `(id_oyente, id_cancion, fecha_hora_reproduccion)`; FK `id_oyente`, `id_cancion`, `id_cancion_previa`, `id_playlist_origen`.
**Reglas:** segundos 0–86.400; origen en el dominio; `id_playlist_origen` existe si y solo si `origen = 'PLAYLIST'`.

---

## 5. Normalización

### 5.1. Primera forma normal (1NF)

Todas las columnas son atómicas. No hay listas ni arreglos embebidos:

- Los géneros de una canción se modelan en `cancion_genero`.
- Los artistas de una canción se modelan en `cancion_artista`.
- Las canciones de una playlist se modelan en `playlist_cancion`.
- Los seguidores de una playlist se modelan en `playlist_seguidor`.

### 5.2. Segunda forma normal (2NF)

En las tablas con PK compuesta, los atributos no clave dependen de toda la
clave, no de una parte:

- `cancion_artista.rol` depende de `(id_cancion, id_artista)`.
- `playlist_cancion.orden` y `fecha_agregado` dependen de `(id_playlist, id_cancion)`.
- `calificacion.valor` y `fecha_calificacion` dependen de `(id_oyente, id_cancion)`.
- `playlist_seguidor.fecha_seguimiento` depende de `(id_playlist, id_oyente)`.
- `reproduccion.segundos_escuchados`, `dispositivo`, `origen` y
  `id_playlist_origen` dependen del evento completo
  `(id_oyente, id_cancion, fecha_hora_reproduccion)`.

### 5.3. Tercera forma normal (3NF)

No hay dependencias transitivas:

- `usuario` no almacena el nombre del plan; el plan se deriva de `suscripcion`.
- `album` no almacena el nombre del artista ni de la disquera; usa FKs.
- `cancion` no almacena el título del álbum ni el nombre del artista; usa FKs.
- `playlist` no almacena el apodo del creador; usa FK a `oyente`.
- `reproduccion` no almacena el título de la canción ni el apodo del oyente.

La única redundancia deliberada es `tipo_usuario` en las subclases. No es una
dependencia transitiva: es un discriminador constante por subclase, necesario
para la FK compuesta que impide subtipos cruzados. Su valor está restringido
por `CHECK` y debe coincidir con `usuario.tipo_usuario`.

`tipo_artista` también es un estado deliberado: no se deriva automáticamente
de `contrato_derechos` porque un artista puede haber sido vinculado y ahora ser
independiente. La consistencia se valida con las consultas A06/A07.

### 5.4. Forma normal de Boyce-Codd (BCNF)

Todos los determinantes son claves candidatas:

- `usuario`: `id_usuario`, `correo`, `nombre_usuario`.
- `plan`: `id_plan`, `nombre_plan`.
- `genero`: `id_genero`, `nombre_genero`.
- `artista`: `id_usuario`, `nombre_artistico`.
- `disquera`: `id_usuario`, `nit`, `razon_social`.
- `oyente`: `id_usuario`, `apodo_publico`.
- `album`: `id_album`, `(id_artista, titulo_album, anio_lanzamiento)`.
- `cancion`: `id_cancion`, `(proveedor, id_externo)` cuando no es `NULL`.

No se identificaron dependencias funcionales donde un atributo no clave
determine otro atributo no clave.

---

## 6. Reglas de negocio y su implementación

| Regla | Descripción | Implementación | Prueba |
|-------|-------------|----------------|--------|
| RN-01 | Sin canciones duplicadas por proveedor; audio por enlace. | `UNIQUE (proveedor, id_externo)`; `ruta_archivo_audio`; `CHECK` de proveedor/id_externo juntos. | A04, B08, B09 |
| RN-02 | Solo artistas/disqueras publican. | `album.id_artista` FK a `artista`; `cancion.id_album` FK a `album`; permisos por rol. | C02, C03 |
| RN-03 | Una calificación por oyente/canción. | PK `(id_oyente, id_cancion)`. | A02, B11 |
| RN-04 | Sin canciones repetidas en una playlist. | PK `(id_playlist, id_cancion)`. | A03, B19 |
| RN-05 | Reproducción única por oyente/canción/instante. | PK `(id_oyente, id_cancion, fecha_hora_reproduccion)`. | A10, C06 |
| RN-06 | Artista independiente vs. vinculado. | `artista.tipo_artista`; consistencia con `contrato_derechos`. | A06, A07 |
| R-EXT-01 | Un usuario = un subtipo. | FK compuesta `(id_usuario, tipo_usuario)`. | A01, B04, B05 |
| R-EXT-02 | Un solo plan activo por usuario. | Regla de aplicación; consulta A05. | A05 |
| R-EXT-03 | No seguir la propia playlist. | Regla de aplicación; consulta A08. | A08 |
| R-EXT-04 | Origen PLAYLIST debe contener la canción. | `CHECK` de coherencia + regla de aplicación; consulta A09. | A09, B22, B23 |
| R-EXT-05 | Segundos escuchados ≤ duración. | `CHECK` 0–86.400 + consulta A10. | A10, B20 |
| R-EXT-06 | Artista principal = dueño del álbum. | Consulta A11. | A11 |
| R-EXT-07 | Canción con artista principal. | Consulta A12. | A12 |
| R-EXT-08 | Álbum con disquera y contrato histórico. | Consulta A13. | A13 |
| R-EXT-09 | Suscripción solo para oyentes. | Consulta A14. | A14 |

---

## 7. Vistas

| Vista | Propósito | Columnas principales |
|-------|-----------|----------------------|
| `vw_usuario_publico` | Perfil público sin datos sensibles. | `id_usuario`, `nombre_usuario`, `pais`, `fecha_registro`, `tipo_usuario` |
| `vw_oyente_publico` | Perfil público de oyente. | `id_usuario`, `apodo_publico`, `pais`, `fecha_registro` |
| `vw_artista_publico` | Perfil público de artista. | `id_usuario`, `nombre_artistico`, `biografia`, `tipo_artista`, `pais_origen` |
| `vw_disquera_publica` | Perfil público de disquera. | `id_usuario`, `nit`, `razon_social`, `pais_sede`, `correo_contacto` |
| `vw_album_detalle` | Álbum con artista y disquera. | `id_album`, `titulo_album`, `anio_lanzamiento`, `tipo_produccion`, `portada_url`, `nombre_artistico`, `disquera` |
| `vw_catalogo_canciones` | Catálogo con álbum y artista principal. | `id_cancion`, `titulo_cancion`, `duracion_segundos`, `es_explicita`, `ruta_archivo_audio`, `id_album`, `titulo_album`, `anio_lanzamiento`, `artista_principal` |
| `vw_cancion_genero` | Canción con sus géneros. | `id_cancion`, `titulo_cancion`, `id_genero`, `nombre_genero` |
| `vw_playlist_publica` | Playlists públicas con contadores. | `id_playlist`, `nombre_playlist`, `tematica`, `fecha_creacion`, `creador`, `num_canciones`, `num_seguidores` |
| `vw_suscripcion_actual` | Suscripción activa sin datos de pago. | `id_usuario`, `nombre_usuario`, `nombre_plan`, `fecha_inicio`, `estado` |
| `vw_reproduccion_analitica` | Historial detallado para analistas. | `id_oyente`, `apodo_publico`, `id_cancion`, `titulo_cancion`, `fecha_hora_reproduccion`, `segundos_escuchados`, `dispositivo`, `origen`, `id_playlist_origen` |

**Privacidad:** las vistas públicas ocultan `correo`, `contrasena_hash` y
`fecha_nacimiento`. El filtrado por fila (por ejemplo, que un oyente solo vea
su historial) se resuelve en la aplicación con
`WHERE id_oyente = :usuario_actual`, porque el SQL estándar no ofrece
seguridad a nivel de fila portable.

---

## 8. Roles y permisos

| Rol | Alcance |
|-----|---------|
| `rol_publico` | `SELECT` sobre las 8 vistas públicas. |
| `rol_oyente` | Vistas públicas + `SELECT` de `plan`/`suscripcion` + CRUD de sus playlists, favoritos y calificaciones + `INSERT` de reproducciones. |
| `rol_artista` | Vistas públicas + `SELECT` de `genero`/`contrato_derechos` + CRUD de álbumes, canciones, colaboraciones y géneros. |
| `rol_disquera` | Vistas públicas + `SELECT` de `genero`/`contrato_derechos` + CRUD de álbumes, canciones, colaboraciones y géneros. |
| `rol_analista` | `SELECT` sobre todas las tablas y vistas (9 consultas de negocio). |
| `rol_admin` | `ALL PRIVILEGES` sobre la base (DBA). |

**Nota:** los roles no implementan seguridad a nivel de fila. La aplicación
debe restringir cada operación con el `id` del usuario autenticado. Los
ejemplos de creación de usuarios de aplicación están comentados al final de
`03_roles.sql`.

---

## 9. Seed de demostración

El archivo `sql/04_seed.sql` se genera con `tools/generar_seed.py` y es
reproducible: usa `random.seed(20261125)`.

| Entidad | Filas |
|---------|------:|
| `plan` | 2 |
| `genero` | 8 |
| `usuario` | 43 |
| `oyente` | 30 |
| `artista` | 10 |
| `disquera` | 3 |
| `contrato_derechos` | 8 |
| `album` | 30 |
| `cancion` | 200 |
| `cancion_artista` | 225 |
| `cancion_genero` | 286 |
| `playlist` | 20 |
| `playlist_cancion` | 200 |
| `playlist_seguidor` | 48 |
| `suscripcion` | 39 |
| `calificacion` | 1.070 |
| `favorito_cancion` | 295 |
| `favorito_album` | 112 |
| `favorito_artista` | 104 |
| `reproduccion` | 5.000 |

**Datos especialmente diseñados para las consultas:**

- 3 usuarios gratuitos con ~600 reproducciones en un solo mes (junio, julio y
  agosto de 2026) para superar las 20 horas y activar la pregunta 4.
- 7 usuarios premium activos y 1 suscripción premium vencida para comparar
  rankings gratis vs. premium.
- 12 países de oyentes para las preguntas 2, 6, 7, 8 y 9.
- 8 géneros, 3 disqueras y 10 artistas con distintos niveles de popularidad.
- 20 playlists, 48 relaciones de seguimiento y 200 canciones en playlists.
- 5.000 reproducciones distribuidas entre el último año y los últimos 60 días,
  con origen, dispositivo, canción previa y playlist de origen.

**Regenerar:**

```bash
python tools/generar_seed.py
```

El generador imprime los conteos y sobrescribe `sql/04_seed.sql`.

---

## 10. Consultas de negocio

| # | Pregunta | Técnica principal |
|---|----------|-------------------|
| P1 | Top 10 canciones más reproducidas en los últimos 30 días y oyentes únicos. | `ROW_NUMBER()`, `COUNT(DISTINCT)`, ventana de fechas. |
| P2 | Artistas con más reproducciones por país y plan; cambio de ranking gratis vs. premium. | Rankings separados con `ROW_NUMBER()`, `JOIN` a `suscripcion`/`plan`. |
| P3 | Porcentaje de reproducciones por origen: playlists propias, de otros, recomendaciones y otras fuentes. | Agregación condicional (`SUM(CASE ...)`), comparación con el dueño de la playlist. |
| P4 | Usuarios gratuitos con más de 20 horas en un mes que nunca pagaron premium. | Agregación mensual, `HAVING`, `NOT EXISTS` sobre suscripciones premium. |
| P5 | Playlists públicas con más seguidores y cantidad de artistas distintos. | Subconsultas correlacionadas, `COUNT(DISTINCT)`, filtro `es_publica`. |
| P6 | Top 5 artistas con más oyentes mensuales en cada país y cuántos son del mismo país. | `ROW_NUMBER()` particionado por país, `COUNT(DISTINCT)`. |
| P7 | Países con más artistas por encima de un umbral y género predominante. | Agregación por artista/país, `ROW_NUMBER()` para el género top. |
| P8 | Artistas con audiencia en 10+ países y país donde más crecen (mes anterior vs. actual). | Agregación por país/mes, `NULLIF` para porcentajes, `ROW_NUMBER()`. |
| P9 | Artista más escuchado en un país y porcentaje de reproducciones desde el exterior. | Rankings por país, agregación condicional, `ROW_NUMBER()`. |

Los resultados completos del seed están en `docs/resultados-esperados.md`.
Resumen de la última ejecución:

- **P1:** 10 filas; líder "Agua Alto" con 15 reproducciones y 10 oyentes únicos.
- **P2:** 85 filas (12 países × planes con datos; 5 posiciones por combinación).
- **P3:** 30 filas; los usuarios con playlists propias muestran entre 18% y 35%
  de reproducciones desde sus propias listas.
- **P4:** 3 filas; los tres usuarios "power" superan las 31 horas en su mes.
- **P5:** 10 filas; "Road trip 01" lidera con 10 seguidores, 12 canciones y 9 artistas.
- **P6:** 60 filas (12 países × 5 artistas).
- **P7:** 4 filas; Colombia (3 artistas, Pop), México (2, Hip Hop), España (1,
  Electrónica) y Perú (1, Electrónica).
- **P8:** 10 filas; el mayor crecimiento absoluto es Nico Flow en España (+18).
- **P9:** 1 fila; Aurora Vega en Colombia, con 44 reproducciones locales y 936
  desde el exterior (95,51% exterior).

---

## 11. Pruebas

### 11.1. Cómo ejecutar

```bash
# MySQL / MariaDB, con la base y el seed cargados
mysql -u root -p hell_music < sql/06_tests.sql
```

El archivo tiene cuatro partes:

- **Parte A:** 14 consultas de integridad; todas deben devolver 0 filas.
- **Parte B:** 30 pruebas negativas comentadas; se descomponen una por una y se
  confirma el error esperado.
- **Parte C:** 6 pruebas positivas dentro de `START TRANSACTION` + `ROLLBACK`.
- **Parte D:** matriz de cobertura caso → regla.

### 11.2. Resultados de la validación automatizada

La validación con SQLite (`tools/verificar_sqlite.py`) reportó:

- 0 violaciones en las 10 reglas de negocio verificadas.
- 0 filas huérfanas en `PRAGMA foreign_key_check`.
- 10/10 pruebas negativas rechazadas correctamente:
  - FK compuesta: un artista no puede ser oyente.
  - FK compuesta: un oyente no puede ser artista.
  - `CHECK` de `tipo_usuario`.
  - `UNIQUE` de correo.
  - `CHECK` de calificación 1–5.
  - PK de calificación duplicada.
  - `UNIQUE` de proveedor/`id_externo`.
  - `CHECK` de año de álbum.
  - `CHECK` de origen de reproducción.
  - `CHECK` de playlist obligatoria para origen `PLAYLIST`.
- Las 9 consultas se ejecutaron sin errores y devolvieron resultados.

### 11.3. Limitaciones de la validación

SQLite se usa como motor de verificación rápida, no como sustituto de
MySQL/MariaDB. Las diferencias relevantes:

- SQLite no aplica `CHECK` con la misma semántica de tipos que MySQL.
- SQLite no tiene roles ni privilegios equivalentes.
- Las funciones `YEAR()`/`MONTH()` se traducen a `strftime()` en el arnés.
- La validación de `TIMESTAMP` y `NUMERIC` es más laxa en SQLite.

Por eso, antes de la entrega final se recomienda ejecutar los scripts en una
instancia real de MySQL 8.0.16+ o MariaDB 10.5+.

---

## 12. Guía de ejecución

### 12.1. Crear la base

```sql
CREATE DATABASE hell_music
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```

### 12.2. Cargar los scripts en orden

```bash
mysql -u root -p hell_music < sql/01_schema.sql
mysql -u root -p hell_music < sql/02_views.sql
mysql -u root -p hell_music < sql/03_roles.sql
mysql -u root -p hell_music < sql/04_seed.sql
mysql -u root -p hell_music < sql/05_queries.sql
mysql -u root -p hell_music < sql/06_tests.sql
```

En PowerShell, la redirección `<` no funciona; use:

```powershell
Get-Content sql\01_schema.sql -Raw | mysql -u root -p hell_music
```

O dentro del cliente MySQL:

```sql
SOURCE C:/ruta/al/proyecto/sql/01_schema.sql;
```

### 12.3. Verificar la carga

```sql
USE hell_music;
SELECT COUNT(*) FROM usuario;       -- 43
SELECT COUNT(*) FROM cancion;       -- 200
SELECT COUNT(*) FROM reproduccion;  -- 5000
```

### 12.4. Ejecutar una consulta de negocio

```sql
-- Pegue el contenido de P1 desde sql/05_queries.sql
```

### 12.5. Validación alternativa con SQLite

Requisitos: Python 3.9+ (solo biblioteca estándar).

```bash
python tools/generar_seed.py
python tools/verificar_sqlite.py
```

El arnés crea una base en memoria, carga el esquema y el seed, ejecuta las
reglas, las pruebas negativas y las 9 consultas, y escribe
`docs/resultados-esperados.md`.

---

## 13. Compatibilidad y consideraciones del motor

| Tema | MySQL 8.0+ | MariaDB 10.5+ |
|------|------------|---------------|
| `CHECK` | Se aplica desde 8.0.16. | Se aplica desde 10.2. |
| Roles | Nativos. | Nativos desde 10.0.5. |
| `BOOLEAN` | Alias de `TINYINT(1)`. | Alias de `TINYINT(1)`. |
| `TIMESTAMP` | Rango 1970–2038. | Rango 1970–2038. |
| `NUMERIC` | Exacto. | Exacto. |
| `ROW_NUMBER()` | Disponible. | Disponible desde 10.2. |
| `NULLS LAST` | No soportado; se usa `ORDER BY ... IS NULL`. | No soportado; se usa `ORDER BY ... IS NULL`. |

**Nota:** si se usa MySQL 8.0.15 o anterior, los `CHECK` se parsean pero no se
aplican; actualice a 8.0.16+ para que las pruebas negativas fallen como se
espera.

---

## 14. Decisiones y tradeoffs

1. **Claves naturales vs. subrogadas.** `reproduccion` usa una PK natural
   compuesta porque el evento es el que define la identidad. Las demás tablas
   usan identificadores explícitos para facilitar el seed y las referencias.
2. **Sin `AUTO_INCREMENT`.** Permite reproducibilidad y evita que el seed
   dependa del estado del motor. La aplicación debe generar los IDs o usar una
   secuencia externa.
3. **Favoritos en tres tablas.** Más tablas, pero integridad referencial real y
   consultas más simples. Una tabla polimórfica habría requerido validaciones
   manuales.
4. **Contratos como historial.** Se conserva la trazabilidad sin invadir el
   alcance operativo de F6.
5. **Premium como historial.** Permite responder "¿cuándo cambió de plan?" y
   "¿nunca pagó?" sin duplicar el plan actual en `usuario`.
6. **Audio por enlace.** La base no almacena binarios; eso mantiene el tamaño
   manejable y separa el almacenamiento de objetos de la base relacional.
7. **Reglas cruzadas en pruebas, no en triggers.** Se priorizó la portabilidad
   y la claridad; las consultas de `06_tests.sql` documentan las reglas y
   pueden migrarse a triggers si el equipo lo requiere.
8. **Roles amplios por perfil.** `rol_artista` y `rol_disquera` comparten
   privilegios de catálogo; en producción se pueden separar por artista
   específico con vistas o seguridad a nivel de fila.

---

## 15. Limitaciones y trabajo futuro

- Implementar triggers o procedimientos para las reglas cruzadas (una sola
  suscripción activa, consistencia artista–contrato, auto-seguimiento,
  coherencia de origen de reproducción).
- Agregar una tabla de auditoría para cambios de plan y contratos.
- Particionar `reproduccion` por rango de fechas cuando el volumen crezca.
- Normalizar `pais` en una tabla con código ISO.
- Evaluar `FULLTEXT` para búsquedas por título/artista.
- Definir política de retención y anonimización de datos personales.
- Agregar un módulo de pagos si se requiere facturación real.
- Revisar los privilegios de `rol_disquera` sobre `correo_contacto` en
  `vw_disquera_publica`; en producción conviene ocultarlo o maskearlo.
- Completar el código de Elian en la tabla de integrantes de F1 (trámite
  administrativo).

---

## 16. Conclusiones

El modelo cubre los requisitos funcionales y las reglas de negocio de F1–F12,
resuelve las incoherencias entre fichas y agrega las entidades que faltaban
para las nueve preguntas de negocio. La solución es SQL estándar, portable a
MySQL 8.0+ y MariaDB 10.5+, y no depende de PostgreSQL ni de tipos
propietarios.

La separación entre superclase y subclases, las PK compuestas para las reglas
RN-03/RN-04/RN-05 y la FK compuesta `(id_usuario, tipo_usuario)` permiten que
el motor impida la mayoría de los errores de integridad sin triggers. Las
reglas que involucran varias filas quedaron documentadas y probadas; el
siguiente paso natural es llevarlas a triggers o a la capa de aplicación.

La validación automatizada con SQLite confirmó que el esquema, el seed y las
nueve consultas funcionan, y que las restricciones rechazan los casos inválidos.
Antes de la entrega final se recomienda repetir la carga en MySQL/MariaDB para
confirmar el comportamiento de `CHECK`, roles y `TIMESTAMP` en el motor
objetivo.

---

## 17. Anexos

### 17.1. Estructura de archivos

```
Proyecto/
├── README.md
├── docs/
│   ├── DOCUMENTACION.md
│   ├── modelo-er.md
│   └── resultados-esperados.md
├── sql/
│   ├── 01_schema.sql
│   ├── 02_views.sql
│   ├── 03_roles.sql
│   ├── 04_seed.sql
│   ├── 05_queries.sql
│   └── 06_tests.sql
└── tools/
    ├── generar_seed.py
    └── verificar_sqlite.py
```

### 17.2. Equipo (F1)

| Integrante | Rol |
|------------|-----|
| Estefany | Coordinadora |
| Santiago | Diseñador lógico |
| Vanessa | Modelador conceptual |
| Hanna | Implementación SQL |
| Daniel | Analista de requerimientos |
| Elian | Calidad y documentación (código pendiente en F1) |

### 17.3. Glosario

| Término | Definición |
|---------|------------|
| Oyente | Usuario que consume música, crea playlists y califica. |
| Artista | Usuario que publica álbumes y canciones. |
| Disquera | Usuario que representa artistas y distribuye álbumes. |
| Canción | Unidad de audio con metadatos y enlace. |
| Álbum | Agrupación de canciones de un artista. |
| Playlist | Lista ordenada de canciones creada por un oyente. |
| Reproducción | Evento de escucha con oyente, canción, instante, origen y duración escuchada. |
| Plan | `GRATUITO` o `PREMIUM`. |
| Suscripción | Contrato histórico de un usuario con un plan. |
| Contrato de derechos | Vínculo histórico entre artista y disquera. |

### 17.4. Comandos rápidos

```bash
# Regenerar seed
python tools/generar_seed.py

# Validar todo en SQLite
python tools/verificar_sqlite.py

# Cargar en MySQL (CMD)
mysql -u root -p hell_music < sql/01_schema.sql
mysql -u root -p hell_music < sql/02_views.sql
mysql -u root -p hell_music < sql/03_roles.sql
mysql -u root -p hell_music < sql/04_seed.sql
mysql -u root -p hell_music < sql/05_queries.sql
mysql -u root -p hell_music < sql/06_tests.sql
```

---

**Fin del documento.**
