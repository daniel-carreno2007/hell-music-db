-- ============================================================================
-- Proyecto : Hell Music
-- Archivo  : 05_queries.sql
-- Contenido: Las 9 preguntas de negocio de F10
-- Motor    : MySQL 8.0+ / MariaDB 10.5+ (CTE y funciones de ventana)
-- Nota     : Se usa una fecha de corte fija ('2026-11-25') para que los
--            resultados sean reproducibles con el seed. En produccion,
--            reemplace las fechas del CTE params por CURRENT_DATE y la
--            aritmetica de intervalos del motor.
--            No se usa LIMIT/TOP: el top-N se resuelve con ROW_NUMBER().
-- ============================================================================


-- ============================================================================
-- P1. Top 10 canciones mas reproducidas en los ultimos 30 dias y cuantos
--     oyentes unicos tiene cada una.
-- ============================================================================
WITH params AS (
    SELECT '2026-10-27' AS inicio_30d,
           '2026-11-26' AS fin_30d
),
recientes AS (
    SELECT r.id_cancion, r.id_oyente
    FROM reproduccion r
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_30d
      AND r.fecha_hora_reproduccion <  p.fin_30d
),
resumen AS (
    SELECT c.id_cancion,
           c.titulo_cancion,
           COUNT(*) AS total_reproducciones,
           COUNT(DISTINCT r.id_oyente) AS oyentes_unicos
    FROM recientes r
    JOIN cancion c ON c.id_cancion = r.id_cancion
    GROUP BY c.id_cancion, c.titulo_cancion
),
ranking AS (
    SELECT resumen.*,
           ROW_NUMBER() OVER (ORDER BY total_reproducciones DESC, titulo_cancion) AS posicion
    FROM resumen
)
SELECT posicion,
       id_cancion,
       titulo_cancion,
       total_reproducciones,
       oyentes_unicos
FROM ranking
WHERE posicion <= 10
ORDER BY posicion;


-- ============================================================================
-- P2. Artistas con mas reproducciones por pais y cambio de ranking entre
--     usuarios con plan gratuito y Premium.
-- ============================================================================
WITH params AS (
    SELECT '2025-11-26' AS inicio_anio,
           '2026-11-26' AS fin_anio
),
plan_actual AS (
    SELECT s.id_usuario,
           p.nombre_plan
    FROM suscripcion s
    JOIN plan p ON p.id_plan = s.id_plan
    WHERE s.estado = 'ACTIVA'
      AND s.fecha_fin IS NULL
),
base AS (
    SELECT u.pais AS pais_oyente,
           pa.nombre_plan,
           ca.id_artista,
           ar.nombre_artistico,
           COUNT(*) AS reproducciones
    FROM reproduccion r
    JOIN oyente o ON o.id_usuario = r.id_oyente
    JOIN usuario u ON u.id_usuario = o.id_usuario
    JOIN plan_actual pa ON pa.id_usuario = r.id_oyente
    JOIN cancion_artista ca ON ca.id_cancion = r.id_cancion AND ca.rol = 'PRINCIPAL'
    JOIN artista ar ON ar.id_usuario = ca.id_artista
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_anio
      AND r.fecha_hora_reproduccion <  p.fin_anio
    GROUP BY u.pais, pa.nombre_plan, ca.id_artista, ar.nombre_artistico
),
ranking AS (
    SELECT base.*,
           ROW_NUMBER() OVER (PARTITION BY pais_oyente, nombre_plan
                              ORDER BY reproducciones DESC, nombre_artistico) AS posicion
    FROM base
)
SELECT pais_oyente,
       nombre_plan,
       posicion,
       nombre_artistico,
       reproducciones
FROM ranking
WHERE posicion <= 5
ORDER BY pais_oyente, nombre_plan, posicion;


-- ============================================================================
-- P3. Porcentaje de reproducciones de cada usuario segun el origen:
--     playlists propias, playlists de otros, recomendaciones y otras fuentes.
-- ============================================================================
WITH params AS (
    SELECT '2025-11-26' AS inicio_anio,
           '2026-11-26' AS fin_anio
),
clasificada AS (
    SELECT r.id_oyente,
           CASE
               WHEN r.origen = 'PLAYLIST' AND pl.id_oyente = r.id_oyente THEN 'PROPIA'
               WHEN r.origen = 'PLAYLIST' THEN 'OTRA'
               WHEN r.origen = 'RECOMENDACION' THEN 'RECOMENDACION'
               ELSE 'OTRA_FUENTE'
           END AS categoria
    FROM reproduccion r
    LEFT JOIN playlist pl ON pl.id_playlist = r.id_playlist_origen
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_anio
      AND r.fecha_hora_reproduccion <  p.fin_anio
)
SELECT c.id_oyente,
       o.apodo_publico,
       COUNT(*) AS total_reproducciones,
       SUM(CASE WHEN c.categoria = 'PROPIA' THEN 1 ELSE 0 END) AS desde_propias,
       SUM(CASE WHEN c.categoria = 'OTRA' THEN 1 ELSE 0 END) AS desde_otras,
       SUM(CASE WHEN c.categoria = 'RECOMENDACION' THEN 1 ELSE 0 END) AS desde_recomendacion,
       SUM(CASE WHEN c.categoria = 'OTRA_FUENTE' THEN 1 ELSE 0 END) AS desde_otras_fuentes,
       ROUND(100.0 * SUM(CASE WHEN c.categoria = 'PROPIA' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_propias,
       ROUND(100.0 * SUM(CASE WHEN c.categoria = 'OTRA' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_otras,
       ROUND(100.0 * SUM(CASE WHEN c.categoria = 'RECOMENDACION' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_recomendacion,
       ROUND(100.0 * SUM(CASE WHEN c.categoria = 'OTRA_FUENTE' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_otras_fuentes
FROM clasificada c
JOIN oyente o ON o.id_usuario = c.id_oyente
GROUP BY c.id_oyente, o.apodo_publico
ORDER BY c.id_oyente;


-- ============================================================================
-- P4. Usuarios con plan gratuito que escuchan mas de 20 horas al mes y
--     nunca han tenido una suscripcion Premium (candidatos a conversion).
-- ============================================================================
WITH params AS (
    SELECT '2025-11-26' AS inicio_anio,
           '2026-11-26' AS fin_anio
),
nunca_premium AS (
    SELECT u.id_usuario
    FROM usuario u
    WHERE NOT EXISTS (
        SELECT 1
        FROM suscripcion s
        JOIN plan p ON p.id_plan = s.id_plan
        WHERE s.id_usuario = u.id_usuario
          AND p.nombre_plan = 'PREMIUM'
    )
),
plan_actual AS (
    SELECT s.id_usuario
    FROM suscripcion s
    JOIN plan p ON p.id_plan = s.id_plan
    WHERE s.estado = 'ACTIVA'
      AND s.fecha_fin IS NULL
      AND p.nombre_plan = 'GRATUITO'
),
consumo AS (
    SELECT r.id_oyente,
           YEAR(r.fecha_hora_reproduccion) AS anio,
           MONTH(r.fecha_hora_reproduccion) AS mes,
           SUM(r.segundos_escuchados) AS segundos,
           SUM(r.segundos_escuchados) / 3600.0 AS horas
    FROM reproduccion r
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_anio
      AND r.fecha_hora_reproduccion <  p.fin_anio
    GROUP BY r.id_oyente,
             YEAR(r.fecha_hora_reproduccion),
             MONTH(r.fecha_hora_reproduccion)
    HAVING SUM(r.segundos_escuchados) > 20 * 3600
)
SELECT c.id_oyente,
       o.apodo_publico,
       u.pais,
       c.anio,
       c.mes,
       c.segundos,
       ROUND(c.horas, 2) AS horas
FROM consumo c
JOIN nunca_premium np ON np.id_usuario = c.id_oyente
JOIN plan_actual pa ON pa.id_usuario = c.id_oyente
JOIN oyente o ON o.id_usuario = c.id_oyente
JOIN usuario u ON u.id_usuario = c.id_oyente
ORDER BY c.horas DESC;


-- ============================================================================
-- P5. Playlists publicas con mas seguidores y cuantos artistas distintos
--     hay en sus canciones.
-- ============================================================================
WITH ranking AS (
    SELECT pl.id_playlist,
           pl.nombre_playlist,
           o.apodo_publico AS creador,
           COUNT(DISTINCT ps.id_oyente) AS seguidores,
           COUNT(DISTINCT pc.id_cancion) AS canciones,
           COUNT(DISTINCT ca.id_artista) AS artistas_distintos,
           ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT ps.id_oyente) DESC,
                                       COUNT(DISTINCT ca.id_artista) DESC,
                                       pl.nombre_playlist) AS posicion
    FROM playlist pl
    JOIN oyente o ON o.id_usuario = pl.id_oyente
    LEFT JOIN playlist_seguidor ps ON ps.id_playlist = pl.id_playlist
    LEFT JOIN playlist_cancion pc ON pc.id_playlist = pl.id_playlist
    LEFT JOIN cancion_artista ca ON ca.id_cancion = pc.id_cancion AND ca.rol = 'PRINCIPAL'
    WHERE pl.es_publica = TRUE
    GROUP BY pl.id_playlist, pl.nombre_playlist, o.apodo_publico
)
SELECT posicion,
       id_playlist,
       nombre_playlist,
       creador,
       seguidores,
       canciones,
       artistas_distintos
FROM ranking
WHERE posicion <= 10
ORDER BY posicion;


-- ============================================================================
-- P6. Top 5 artistas con mas oyentes mensuales en cada pais y cuantos de
--     esos oyentes son del mismo pais del artista.
-- ============================================================================
WITH params AS (
    SELECT '2026-10-27' AS inicio_30d,
           '2026-11-26' AS fin_30d
),
base AS (
    SELECT u.pais AS pais_oyente,
           ca.id_artista,
           ar.nombre_artistico,
           ar.pais_origen,
           COUNT(DISTINCT r.id_oyente) AS oyentes_mensuales,
           COUNT(DISTINCT CASE WHEN u.pais = ar.pais_origen THEN r.id_oyente END) AS oyentes_mismo_pais
    FROM reproduccion r
    JOIN oyente o ON o.id_usuario = r.id_oyente
    JOIN usuario u ON u.id_usuario = o.id_usuario
    JOIN cancion_artista ca ON ca.id_cancion = r.id_cancion AND ca.rol = 'PRINCIPAL'
    JOIN artista ar ON ar.id_usuario = ca.id_artista
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_30d
      AND r.fecha_hora_reproduccion <  p.fin_30d
    GROUP BY u.pais, ca.id_artista, ar.nombre_artistico, ar.pais_origen
),
ranking AS (
    SELECT base.*,
           ROW_NUMBER() OVER (PARTITION BY pais_oyente
                              ORDER BY oyentes_mensuales DESC, nombre_artistico) AS posicion
    FROM base
)
SELECT pais_oyente,
       posicion,
       nombre_artistico,
       pais_origen,
       oyentes_mensuales,
       oyentes_mismo_pais
FROM ranking
WHERE posicion <= 5
ORDER BY pais_oyente, posicion;


-- ============================================================================
-- P7. Paises con mas artistas por encima del umbral de reproducciones y
--     genero musical predominante de esos artistas.
--     Nota: la pregunta original usa 1.000.000 de reproducciones. Con el
--     seed de demostracion se usa 350, cambie el valor en params.umbral.
-- ============================================================================
WITH params AS (
    SELECT 350 AS umbral_reproducciones,
           '2025-11-26' AS inicio_anio,
           '2026-11-26' AS fin_anio
),
reproducciones_artista AS (
    SELECT ca.id_artista,
           COUNT(*) AS total_reproducciones
    FROM reproduccion r
    JOIN cancion_artista ca ON ca.id_cancion = r.id_cancion AND ca.rol = 'PRINCIPAL'
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_anio
      AND r.fecha_hora_reproduccion <  p.fin_anio
    GROUP BY ca.id_artista
),
artistas_destacados AS (
    SELECT a.id_usuario,
           a.pais_origen
    FROM artista a
    JOIN reproducciones_artista ra ON ra.id_artista = a.id_usuario
    CROSS JOIN params p
    WHERE ra.total_reproducciones >= p.umbral_reproducciones
),
genero_artista AS (
    SELECT ca.id_artista,
           g.id_genero,
           g.nombre_genero,
           COUNT(*) AS reproducciones
    FROM reproduccion r
    JOIN cancion_artista ca ON ca.id_cancion = r.id_cancion AND ca.rol = 'PRINCIPAL'
    JOIN cancion_genero cg ON cg.id_cancion = r.id_cancion
    JOIN genero g ON g.id_genero = cg.id_genero
    JOIN artistas_destacados ad ON ad.id_usuario = ca.id_artista
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_anio
      AND r.fecha_hora_reproduccion <  p.fin_anio
    GROUP BY ca.id_artista, g.id_genero, g.nombre_genero
),
genero_rank AS (
    SELECT ga.*,
           ROW_NUMBER() OVER (PARTITION BY id_artista
                              ORDER BY reproducciones DESC, nombre_genero) AS rn
    FROM genero_artista ga
),
pais_resumen AS (
    SELECT ad.pais_origen,
           COUNT(DISTINCT ad.id_usuario) AS artistas_destacados
    FROM artistas_destacados ad
    GROUP BY ad.pais_origen
),
genero_predominante_base AS (
    SELECT ad.pais_origen,
           gr.nombre_genero,
           SUM(gr.reproducciones) AS reproducciones_genero
    FROM artistas_destacados ad
    JOIN genero_rank gr ON gr.id_artista = ad.id_usuario AND gr.rn = 1
    GROUP BY ad.pais_origen, gr.nombre_genero
),
genero_predominante AS (
    SELECT gp.*,
           ROW_NUMBER() OVER (PARTITION BY pais_origen
                              ORDER BY reproducciones_genero DESC, nombre_genero) AS rn
    FROM genero_predominante_base gp
)
SELECT pr.pais_origen,
       pr.artistas_destacados,
       gp.nombre_genero AS genero_predominante
FROM pais_resumen pr
JOIN genero_predominante gp ON gp.pais_origen = pr.pais_origen AND gp.rn = 1
ORDER BY pr.artistas_destacados DESC, pr.pais_origen;


-- ============================================================================
-- P8. Artistas con audiencia en 10 o mas paises y el pais donde mas crecen
--     sus reproducciones mes a mes (comparacion septiembre vs octubre 2026).
-- ============================================================================
WITH params AS (
    SELECT '2025-11-26' AS inicio_anio,
           '2026-11-26' AS fin_anio,
           '2026-09-01' AS inicio_mes_anterior,
           '2026-10-01' AS inicio_mes_actual,
           '2026-11-01' AS fin_mes_actual,
           10 AS min_paises
),
base AS (
    SELECT ca.id_artista,
           u.pais AS pais_oyente,
           CASE WHEN r.fecha_hora_reproduccion >= p.inicio_mes_actual
                THEN 'ACTUAL' ELSE 'ANTERIOR' END AS mes,
           COUNT(*) AS reproducciones
    FROM reproduccion r
    JOIN oyente o ON o.id_usuario = r.id_oyente
    JOIN usuario u ON u.id_usuario = o.id_usuario
    JOIN cancion_artista ca ON ca.id_cancion = r.id_cancion AND ca.rol = 'PRINCIPAL'
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_mes_anterior
      AND r.fecha_hora_reproduccion <  p.fin_mes_actual
    GROUP BY ca.id_artista, u.pais,
             CASE WHEN r.fecha_hora_reproduccion >= p.inicio_mes_actual
                  THEN 'ACTUAL' ELSE 'ANTERIOR' END
),
paises_artista AS (
    SELECT ca.id_artista,
           COUNT(DISTINCT u.pais) AS paises
    FROM reproduccion r
    JOIN oyente o ON o.id_usuario = r.id_oyente
    JOIN usuario u ON u.id_usuario = o.id_usuario
    JOIN cancion_artista ca ON ca.id_cancion = r.id_cancion AND ca.rol = 'PRINCIPAL'
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_anio
      AND r.fecha_hora_reproduccion <  p.fin_anio
    GROUP BY ca.id_artista
),
elegibles AS (
    SELECT pa.id_artista
    FROM paises_artista pa
    CROSS JOIN params p
    WHERE pa.paises >= p.min_paises
),
pivot AS (
    SELECT b.id_artista,
           b.pais_oyente,
           SUM(CASE WHEN b.mes = 'ANTERIOR' THEN b.reproducciones ELSE 0 END) AS repro_anterior,
           SUM(CASE WHEN b.mes = 'ACTUAL' THEN b.reproducciones ELSE 0 END) AS repro_actual
    FROM base b
    JOIN elegibles e ON e.id_artista = b.id_artista
    GROUP BY b.id_artista, b.pais_oyente
),
crecimiento AS (
    SELECT pv.*,
           (pv.repro_actual - pv.repro_anterior) AS crecimiento_absoluto,
           CASE WHEN pv.repro_anterior = 0 THEN NULL
                ELSE ROUND(100.0 * (pv.repro_actual - pv.repro_anterior) / pv.repro_anterior, 2)
           END AS crecimiento_pct
    FROM pivot pv
),
ranking AS (
    SELECT c.*,
           a.nombre_artistico,
           ROW_NUMBER() OVER (PARTITION BY c.id_artista
                              ORDER BY c.crecimiento_absoluto DESC, c.pais_oyente) AS rn
    FROM crecimiento c
    JOIN artista a ON a.id_usuario = c.id_artista
)
SELECT id_artista,
       nombre_artistico,
       pais_oyente,
       repro_anterior,
       repro_actual,
       crecimiento_absoluto,
       crecimiento_pct
FROM ranking
WHERE rn = 1
ORDER BY crecimiento_absoluto DESC;


-- ============================================================================
-- P9. Artista mas escuchado en un pais especifico durante el ultimo anio y
--     cuantas de sus reproducciones provienen de oyentes fuera del pais.
--     Cambie params.pais_objetivo para analizar otro pais.
-- ============================================================================
WITH params AS (
    SELECT '2025-11-26' AS inicio_anio,
           '2026-11-26' AS fin_anio,
           'Colombia' AS pais_objetivo
),
plays AS (
    SELECT ca.id_artista,
           ar.nombre_artistico,
           u.pais AS pais_oyente
    FROM reproduccion r
    JOIN oyente o ON o.id_usuario = r.id_oyente
    JOIN usuario u ON u.id_usuario = o.id_usuario
    JOIN cancion_artista ca ON ca.id_cancion = r.id_cancion AND ca.rol = 'PRINCIPAL'
    JOIN artista ar ON ar.id_usuario = ca.id_artista
    CROSS JOIN params p
    WHERE r.fecha_hora_reproduccion >= p.inicio_anio
      AND r.fecha_hora_reproduccion <  p.fin_anio
),
top_pais AS (
    SELECT pl.id_artista,
           COUNT(*) AS reproducciones_en_pais
    FROM plays pl
    CROSS JOIN params p
    WHERE pl.pais_oyente = p.pais_objetivo
    GROUP BY pl.id_artista
),
ranking AS (
    SELECT tp.*,
           ROW_NUMBER() OVER (ORDER BY tp.reproducciones_en_pais DESC, tp.id_artista) AS rn
    FROM top_pais tp
),
elegido AS (
    SELECT r.id_artista,
           r.reproducciones_en_pais
    FROM ranking r
    WHERE r.rn = 1
)
SELECT e.id_artista,
       a.nombre_artistico,
       e.reproducciones_en_pais AS reproducciones_en_el_pais,
       SUM(CASE WHEN pl.pais_oyente <> p.pais_objetivo THEN 1 ELSE 0 END) AS reproducciones_exterior,
       COUNT(*) AS reproducciones_totales,
       ROUND(100.0 * SUM(CASE WHEN pl.pais_oyente <> p.pais_objetivo THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_exterior
FROM elegido e
JOIN plays pl ON pl.id_artista = e.id_artista
JOIN artista a ON a.id_usuario = e.id_artista
CROSS JOIN params p
GROUP BY e.id_artista, a.nombre_artistico, e.reproducciones_en_pais;
