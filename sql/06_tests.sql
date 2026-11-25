-- ============================================================================
-- HELL MUSIC - PRUEBAS DE RESTRICCIONES Y REGLAS DE NEGOCIO
-- Motor objetivo: MySQL 8.0+ / MariaDB 10.5+
-- Requiere: 01_schema.sql y 04_seed.sql cargados.
--
-- Como leer este archivo:
--   * PARTE A: consultas de integridad. Todas deben devolver 0 filas.
--   * PARTE B: pruebas negativas. Cada INSERT esta comentado; descomente
--     UNA por una y confirme el error esperado. Si el INSERT no falla,
--     la restriccion no esta funcionando.
--   * PARTE C: pruebas positivas. Se ejecutan dentro de una transaccion y
--     terminan en ROLLBACK para no dejar datos de prueba.
--   * PARTE D: matriz de cobertura regla -> caso.
--
-- Fecha de referencia del seed: 2026-11-25.
-- ============================================================================


-- ============================================================================
-- PARTE A. CONSULTAS DE INTEGRIDAD (resultado esperado: 0 filas)
-- ============================================================================

-- A01. Cada usuario debe tener exactamente un subtipo y debe coincidir con
--      usuario.tipo_usuario. La FK compuesta impide subtipos cruzados; esta
--      consulta detecta usuarios sin subtipo.
SELECT u.id_usuario,
       u.tipo_usuario,
       (o.id_usuario IS NOT NULL) AS es_oyente,
       (a.id_usuario IS NOT NULL) AS es_artista,
       (d.id_usuario IS NOT NULL) AS es_disquera
FROM usuario u
LEFT JOIN oyente o   ON o.id_usuario = u.id_usuario
LEFT JOIN artista a  ON a.id_usuario = u.id_usuario
LEFT JOIN disquera d ON d.id_usuario = u.id_usuario
WHERE (o.id_usuario IS NOT NULL)
    + (a.id_usuario IS NOT NULL)
    + (d.id_usuario IS NOT NULL) <> 1
   OR (u.tipo_usuario = 'OYENTE'   AND o.id_usuario IS NULL)
   OR (u.tipo_usuario = 'ARTISTA'  AND a.id_usuario IS NULL)
   OR (u.tipo_usuario = 'DISQUERA' AND d.id_usuario IS NULL);

-- A02. RN-03: un oyente no puede calificar dos veces la misma cancion.
SELECT id_oyente, id_cancion, COUNT(*) AS veces
FROM calificacion
GROUP BY id_oyente, id_cancion
HAVING COUNT(*) > 1;

-- A03. RN-04: una cancion no puede repetirse dentro de la misma playlist.
SELECT id_playlist, id_cancion, COUNT(*) AS veces
FROM playlist_cancion
GROUP BY id_playlist, id_cancion
HAVING COUNT(*) > 1;

-- A04. RN-01: (proveedor, id_externo) debe ser unico.
SELECT proveedor, id_externo, COUNT(*) AS veces
FROM cancion
WHERE proveedor IS NOT NULL
GROUP BY proveedor, id_externo
HAVING COUNT(*) > 1;

-- A05. Un usuario no puede tener mas de una suscripcion ACTIVA.
--      Regla cruzada: se valida aqui y debe replicarse en la aplicacion.
SELECT id_usuario, COUNT(*) AS suscripciones_activas
FROM suscripcion
WHERE estado = 'ACTIVA'
GROUP BY id_usuario
HAVING COUNT(*) > 1;

-- A06. Un artista VINCULADO debe tener un contrato VIGENTE a la fecha.
SELECT a.id_usuario, a.nombre_artistico
FROM artista a
WHERE a.tipo_artista = 'VINCULADO'
  AND NOT EXISTS (
      SELECT 1
      FROM contrato_derechos c
      WHERE c.id_artista = a.id_usuario
        AND c.estado_contrato = 'VIGENTE'
        AND c.fecha_inicio <= '2026-11-25'
        AND (c.fecha_fin IS NULL OR c.fecha_fin >= '2026-11-25')
  );

-- A07. Un artista INDEPENDIENTE no puede tener un contrato VIGENTE.
SELECT a.id_usuario, a.nombre_artistico, c.id_contrato
FROM artista a
JOIN contrato_derechos c ON c.id_artista = a.id_usuario
WHERE a.tipo_artista = 'INDEPENDIENTE'
  AND c.estado_contrato = 'VIGENTE'
  AND c.fecha_inicio <= '2026-11-25'
  AND (c.fecha_fin IS NULL OR c.fecha_fin >= '2026-11-25');

-- A08. Un oyente no puede seguir su propia playlist.
SELECT ps.id_playlist, ps.id_oyente
FROM playlist_seguidor ps
JOIN playlist p ON p.id_playlist = ps.id_playlist
WHERE ps.id_oyente = p.id_oyente;

-- A09. Si el origen es PLAYLIST, la cancion debe pertenecer a esa playlist.
SELECT r.id_oyente, r.id_cancion, r.fecha_hora_reproduccion, r.id_playlist_origen
FROM reproduccion r
WHERE r.origen = 'PLAYLIST'
  AND NOT EXISTS (
      SELECT 1
      FROM playlist_cancion pc
      WHERE pc.id_playlist = r.id_playlist_origen
        AND pc.id_cancion = r.id_cancion
  );

-- A10. Los segundos escuchados no pueden superar la duracion de la cancion.
SELECT r.id_oyente, r.id_cancion, r.fecha_hora_reproduccion,
       r.segundos_escuchados, c.duracion_segundos
FROM reproduccion r
JOIN cancion c ON c.id_cancion = r.id_cancion
WHERE r.segundos_escuchados > c.duracion_segundos;

-- A11. El artista PRINCIPAL de una cancion debe coincidir con el artista
--      dueno del album (las colaboraciones van como FEATURING).
SELECT ca.id_cancion, ca.id_artista, al.id_artista AS id_artista_album
FROM cancion_artista ca
JOIN cancion c ON c.id_cancion = ca.id_cancion
JOIN album al  ON al.id_album = c.id_album
WHERE ca.rol = 'PRINCIPAL'
  AND ca.id_artista <> al.id_artista;

-- A12. Toda cancion debe tener al menos un artista PRINCIPAL.
SELECT c.id_cancion, c.titulo_cancion
FROM cancion c
WHERE NOT EXISTS (
    SELECT 1
    FROM cancion_artista ca
    WHERE ca.id_cancion = c.id_cancion
      AND ca.rol = 'PRINCIPAL'
);

-- A13. Si un album tiene disquera, debe existir algun contrato historico
--      entre esa disquera y el artista del album.
SELECT al.id_album, al.titulo_album, al.id_artista, al.id_disquera
FROM album al
WHERE al.id_disquera IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM contrato_derechos c
      WHERE c.id_artista = al.id_artista
        AND c.id_disquera = al.id_disquera
  );

-- A14. Las suscripciones solo aplican a oyentes.
SELECT s.id_suscripcion, s.id_usuario, u.tipo_usuario
FROM suscripcion s
JOIN usuario u ON u.id_usuario = s.id_usuario
WHERE u.tipo_usuario <> 'OYENTE';


-- ============================================================================
-- PARTE B. PRUEBAS NEGATIVAS (descomente una por una)
-- ============================================================================

-- B01. Correo duplicado.
-- INSERT INTO usuario (id_usuario, correo, nombre_usuario, contrasena_hash,
--                      fecha_registro, pais, tipo_usuario, activo)
-- VALUES (100, 'aurora.vega@demo.com', 'usuario_prueba', 'hash', '2026-01-01',
--         'Colombia', 'OYENTE', TRUE);
-- ERROR ESPERADO: 1062 Duplicate entry 'aurora.vega@demo.com'
--                 for key 'uq_usuario_correo'.

-- B02. tipo_usuario fuera del dominio.
-- INSERT INTO usuario (id_usuario, correo, nombre_usuario, contrasena_hash,
--                      fecha_registro, pais, tipo_usuario, activo)
-- VALUES (100, 'nuevo@demo.com', 'usuario_prueba', 'hash', '2026-01-01',
--         'Colombia', 'ADMIN', TRUE);
-- ERROR ESPERADO: CHECK ck_usuario_tipo violado
--                 (MySQL 3819 / MariaDB 4025).

-- B03. Subtipo sin usuario padre.
-- INSERT INTO oyente (id_usuario, apodo_publico, fecha_nacimiento)
-- VALUES (999, 'fantasma', '2000-01-01');
-- ERROR ESPERADO: 1452 Cannot add or update a child row:
--                 FK fk_oyente_usuario.

-- B04. Un usuario ARTISTA no puede insertarse como OYENTE.
-- INSERT INTO oyente (id_usuario, apodo_publico, fecha_nacimiento)
-- VALUES (4, 'aurora_oyente', '2000-01-01');
-- ERROR ESPERADO: 1452 FK compuesta fk_oyente_usuario
--                 (usuario 4 tiene tipo_usuario = 'ARTISTA').

-- B05. Un usuario OYENTE no puede insertarse como ARTISTA.
-- INSERT INTO artista (id_usuario, nombre_artistico, biografia,
--                      tipo_artista, pais_origen)
-- VALUES (14, 'Actor Falso', 'x', 'INDEPENDIENTE', 'Colombia');
-- ERROR ESPERADO: 1452 FK compuesta fk_artista_usuario
--                 (usuario 14 tiene tipo_usuario = 'OYENTE').

-- B06. Anio de album fuera de rango.
-- INSERT INTO album (id_album, titulo_album, anio_lanzamiento,
--                    tipo_produccion, portada_url, id_artista, id_disquera)
-- VALUES (100, 'Album Prueba', 1800, 'LP', '/img/x.jpg', 4, 1);
-- ERROR ESPERADO: CHECK ck_album_anio.

-- B07. Duracion de cancion no positiva.
-- INSERT INTO cancion (id_cancion, titulo_cancion, num_pista,
--                      duracion_segundos, ruta_archivo_audio, es_explicita,
--                      id_album, proveedor, id_externo)
-- VALUES (300, 'Cancion Prueba', 1, 0, '/audio/x.mp3', FALSE, 1, 'PROPIO', 'own-300');
-- ERROR ESPERADO: CHECK ck_cancion_duracion.

-- B08. RN-01: (proveedor, id_externo) duplicado.
-- INSERT INTO cancion (id_cancion, titulo_cancion, num_pista,
--                      duracion_segundos, ruta_archivo_audio, es_explicita,
--                      id_album, proveedor, id_externo)
-- VALUES (300, 'Cancion Duplicada', 8, 200, '/audio/x.mp3', FALSE, 1,
--         'JAMENDO', 'jam-001');
-- ERROR ESPERADO: 1062 Duplicate entry 'JAMENDO-jam-001'
--                 for key 'uq_cancion_proveedor'.

-- B09. Proveedor sin id_externo.
-- INSERT INTO cancion (id_cancion, titulo_cancion, num_pista,
--                      duracion_segundos, ruta_archivo_audio, es_explicita,
--                      id_album, proveedor, id_externo)
-- VALUES (300, 'Cancion Incompleta', 8, 200, '/audio/x.mp3', FALSE, 1,
--         'JAMENDO', NULL);
-- ERROR ESPERADO: CHECK ck_cancion_externo.

-- B10. Calificacion fuera de 1..5.
-- INSERT INTO calificacion (id_oyente, id_cancion, valor, fecha_calificacion)
-- VALUES (14, 1, 6, '2026-11-25');
-- ERROR ESPERADO: CHECK ck_cal_valor.

-- B11. RN-03: calificacion duplicada (14, 14).
-- INSERT INTO calificacion (id_oyente, id_cancion, valor, fecha_calificacion)
-- VALUES (14, 14, 4, '2026-11-25');
-- ERROR ESPERADO: 1062 Duplicate entry '14-14' for key 'PRIMARY'.

-- B12. Suscripcion con fecha_fin anterior a fecha_inicio.
-- INSERT INTO suscripcion (id_suscripcion, id_usuario, id_plan,
--                          fecha_inicio, fecha_fin, estado)
-- VALUES (100, 14, 2, '2026-11-01', '2026-10-01', 'ACTIVA');
-- ERROR ESPERADO: CHECK ck_sus_fechas.

-- B13. Estado de suscripcion invalido.
-- INSERT INTO suscripcion (id_suscripcion, id_usuario, id_plan,
--                          fecha_inicio, fecha_fin, estado)
-- VALUES (100, 14, 2, '2026-11-01', NULL, 'PENDIENTE');
-- ERROR ESPERADO: CHECK ck_sus_estado.

-- B14. Porcentaje de regalias fuera de 0..100.
-- INSERT INTO contrato_derechos (id_contrato, id_artista, id_disquera,
--                                fecha_inicio, fecha_fin, porcentaje_regalias,
--                                estado_contrato)
-- VALUES (100, 5, 1, '2026-01-01', NULL, 150.00, 'VIGENTE');
-- ERROR ESPERADO: CHECK ck_contrato_regalias.

-- B15. Contrato con fecha_fin anterior a fecha_inicio.
-- INSERT INTO contrato_derechos (id_contrato, id_artista, id_disquera,
--                                fecha_inicio, fecha_fin, porcentaje_regalias,
--                                estado_contrato)
-- VALUES (100, 5, 1, '2026-01-01', '2025-01-01', 10.00, 'VIGENTE');
-- ERROR ESPERADO: CHECK ck_contrato_fechas.

-- B16. Contrato duplicado (mismo artista, disquera y fecha de inicio).
-- INSERT INTO contrato_derechos (id_contrato, id_artista, id_disquera,
--                                fecha_inicio, fecha_fin, porcentaje_regalias,
--                                estado_contrato)
-- VALUES (100, 4, 1, '2024-01-01', NULL, 10.00, 'VIGENTE');
-- ERROR ESPERADO: 1062 Duplicate entry '4-1-2024-01-01'
--                 for key 'uq_contrato'.

-- B17. Orden de playlist no positivo.
-- INSERT INTO playlist_cancion (id_playlist, id_cancion, orden, fecha_agregado)
-- VALUES (1, 1, 0, '2026-11-25');
-- ERROR ESPERADO: CHECK ck_pc_orden.

-- B18. Orden duplicado dentro de la misma playlist.
-- INSERT INTO playlist_cancion (id_playlist, id_cancion, orden, fecha_agregado)
-- VALUES (1, 1, 1, '2026-11-25');
-- ERROR ESPERADO: 1062 Duplicate entry '1-1' for key 'uq_pc_orden'.

-- B19. RN-04: cancion duplicada en la misma playlist.
-- INSERT INTO playlist_cancion (id_playlist, id_cancion, orden, fecha_agregado)
-- VALUES (1, 99, 13, '2026-11-25');
-- ERROR ESPERADO: 1062 Duplicate entry '1-99' for key 'PRIMARY'.

-- B20. Segundos escuchados fuera de rango.
-- INSERT INTO reproduccion (id_oyente, id_cancion, fecha_hora_reproduccion,
--                           segundos_escuchados, dispositivo, id_cancion_previa,
--                           origen, id_playlist_origen)
-- VALUES (14, 1, '2026-11-25 03:03:03', 90000, 'Web', NULL, 'BUSQUEDA', NULL);
-- ERROR ESPERADO: CHECK ck_rep_segundos.

-- B21. Origen de reproduccion invalido.
-- INSERT INTO reproduccion (id_oyente, id_cancion, fecha_hora_reproduccion,
--                           segundos_escuchados, dispositivo, id_cancion_previa,
--                           origen, id_playlist_origen)
-- VALUES (14, 1, '2026-11-25 03:03:03', 100, 'Web', NULL, 'RADIO', NULL);
-- ERROR ESPERADO: CHECK ck_rep_origen.

-- B22. Origen PLAYLIST sin playlist identificada.
-- INSERT INTO reproduccion (id_oyente, id_cancion, fecha_hora_reproduccion,
--                           segundos_escuchados, dispositivo, id_cancion_previa,
--                           origen, id_playlist_origen)
-- VALUES (14, 1, '2026-11-25 03:03:03', 100, 'Web', NULL, 'PLAYLIST', NULL);
-- ERROR ESPERADO: CHECK ck_rep_playlist.

-- B23. Origen distinto de PLAYLIST con playlist identificada.
-- INSERT INTO reproduccion (id_oyente, id_cancion, fecha_hora_reproduccion,
--                           segundos_escuchados, dispositivo, id_cancion_previa,
--                           origen, id_playlist_origen)
-- VALUES (14, 1, '2026-11-25 03:03:03', 100, 'Web', NULL, 'BUSQUEDA', 1);
-- ERROR ESPERADO: CHECK ck_rep_playlist.

-- B24. Rol de colaboracion invalido.
-- INSERT INTO cancion_artista (id_cancion, id_artista, rol)
-- VALUES (1, 5, 'INVITADO');
-- ERROR ESPERADO: CHECK ck_ca_rol.

-- B25. Genero duplicado para la misma cancion.
-- INSERT INTO cancion_genero (id_cancion, id_genero) VALUES (1, 2);
-- ERROR ESPERADO: 1062 Duplicate entry '1-2' for key 'PRIMARY'.

-- B26. Favorito duplicado.
-- INSERT INTO favorito_cancion (id_oyente, id_cancion, fecha_marcado)
-- VALUES (14, 14, '2026-11-25');
-- ERROR ESPERADO: 1062 Duplicate entry '14-14' for key 'PRIMARY'.

-- B27. Nombre de plan invalido.
-- INSERT INTO plan (id_plan, nombre_plan, precio_mensual)
-- VALUES (3, 'FAMILIAR', 29900.00);
-- ERROR ESPERADO: CHECK ck_plan_nombre.

-- B28. Precio de plan negativo.
-- INSERT INTO plan (id_plan, nombre_plan, precio_mensual)
-- VALUES (3, 'GRATUITO', -1.00);
-- ERROR ESPERADO: 1062 (nombre duplicado) o CHECK ck_plan_precio.

-- B29. Nombre de playlist duplicado para el mismo oyente.
-- INSERT INTO playlist (id_playlist, id_oyente, nombre_playlist, tematica,
--                       fecha_creacion, es_publica)
-- VALUES (100, 17, 'Road trip 01', 'Prueba', '2026-11-25', TRUE);
-- ERROR ESPERADO: 1062 Duplicate entry '17-Road trip 01'
--                 for key 'uq_playlist_nombre'.

-- B30. Apodo publico duplicado.
-- INSERT INTO oyente (id_usuario, apodo_publico, fecha_nacimiento)
-- VALUES (100, 'melomano_01', '2000-01-01');
-- ERROR ESPERADO: 1452 (usuario 100 no existe) o 1062 (apodo duplicado)
--                 segun el orden de validacion del motor.


-- ============================================================================
-- PARTE C. PRUEBAS POSITIVAS (transaccion + ROLLBACK)
-- ============================================================================

-- C01. Alta completa de un oyente.
START TRANSACTION;
INSERT INTO usuario (id_usuario, correo, nombre_usuario, contrasena_hash,
                     fecha_registro, pais, tipo_usuario, activo)
VALUES (100, 'prueba.oyente@demo.com', 'prueba_oyente', 'hash_prueba',
        '2026-11-25', 'Colombia', 'OYENTE', TRUE);
INSERT INTO oyente (id_usuario, apodo_publico, fecha_nacimiento)
VALUES (100, 'prueba_melomano', '2000-01-01');
ROLLBACK;

-- C02. Alta completa de un artista independiente.
START TRANSACTION;
INSERT INTO usuario (id_usuario, correo, nombre_usuario, contrasena_hash,
                     fecha_registro, pais, tipo_usuario, activo)
VALUES (101, 'prueba.artista@demo.com', 'prueba_artista', 'hash_prueba',
        '2026-11-25', 'Colombia', 'ARTISTA', TRUE);
INSERT INTO artista (id_usuario, nombre_artistico, biografia,
                     tipo_artista, pais_origen)
VALUES (101, 'Artista Prueba', 'Biografia de prueba', 'INDEPENDIENTE', 'Colombia');
ROLLBACK;

-- C03. Alta de album y cancion de un artista existente.
START TRANSACTION;
INSERT INTO album (id_album, titulo_album, anio_lanzamiento, tipo_produccion,
                   portada_url, id_artista, id_disquera)
VALUES (100, 'Album de Prueba', 2026, 'EP', '/img/prueba.jpg', 5, NULL);
INSERT INTO cancion (id_cancion, titulo_cancion, num_pista,
                     duracion_segundos, ruta_archivo_audio, es_explicita,
                     id_album, proveedor, id_externo)
VALUES (300, 'Cancion de Prueba', 1, 210, '/audio/prueba.mp3', FALSE,
        100, 'PROPIO', 'own-300');
INSERT INTO cancion_artista (id_cancion, id_artista, rol)
VALUES (300, 5, 'PRINCIPAL');
ROLLBACK;

-- C04. Alta de playlist con una cancion.
START TRANSACTION;
INSERT INTO playlist (id_playlist, id_oyente, nombre_playlist, tematica,
                      fecha_creacion, es_publica)
VALUES (100, 17, 'Playlist de Prueba', 'Prueba', '2026-11-25', TRUE);
INSERT INTO playlist_cancion (id_playlist, id_cancion, orden, fecha_agregado)
VALUES (100, 99, 1, '2026-11-25');
ROLLBACK;

-- C05. Alta de calificacion y favorito para un oyente nuevo.
START TRANSACTION;
INSERT INTO usuario (id_usuario, correo, nombre_usuario, contrasena_hash,
                     fecha_registro, pais, tipo_usuario, activo)
VALUES (100, 'prueba.oyente@demo.com', 'prueba_oyente', 'hash_prueba',
        '2026-11-25', 'Colombia', 'OYENTE', TRUE);
INSERT INTO oyente (id_usuario, apodo_publico, fecha_nacimiento)
VALUES (100, 'prueba_melomano', '2000-01-01');
INSERT INTO calificacion (id_oyente, id_cancion, valor, fecha_calificacion)
VALUES (100, 99, 5, '2026-11-25');
INSERT INTO favorito_cancion (id_oyente, id_cancion, fecha_marcado)
VALUES (100, 99, '2026-11-25');
ROLLBACK;

-- C06. Reproduccion valida desde una playlist que contiene la cancion.
START TRANSACTION;
INSERT INTO reproduccion (id_oyente, id_cancion, fecha_hora_reproduccion,
                          segundos_escuchados, dispositivo, id_cancion_previa,
                          origen, id_playlist_origen)
VALUES (17, 99, '2026-11-25 03:03:03', 120, 'Web', NULL, 'PLAYLIST', 1);
ROLLBACK;


-- ============================================================================
-- PARTE D. MATRIZ DE COBERTURA
-- ============================================================================
-- Caso | Regla / restriccion                          | Tipo de prueba
-- -----+----------------------------------------------+-----------------
-- A01  | Un usuario = un subtipo                      | Integridad
-- A02  | RN-03 calificacion unica                     | Integridad
-- A03  | RN-04 cancion unica por playlist             | Integridad
-- A04  | RN-01 proveedor/id_externo unico             | Integridad
-- A05  | Una suscripcion ACTIVA por usuario           | Integridad
-- A06  | VINCULADO exige contrato vigente             | Integridad
-- A07  | INDEPENDIENTE sin contrato vigente           | Integridad
-- A08  | No auto-seguir playlist                      | Integridad
-- A09  | Origen PLAYLIST coherente                    | Integridad
-- A10  | Segundos <= duracion                         | Integridad
-- A11  | Artista principal = dueno del album          | Integridad
-- A12  | Cancion con artista principal                | Integridad
-- A13  | Album con disquera y contrato historico      | Integridad
-- A14  | Suscripcion solo para oyentes                | Integridad
-- B01  | Correo unico                                 | Negativa
-- B02  | Dominio de tipo_usuario                      | Negativa
-- B03  | FK subtipo -> usuario                        | Negativa
-- B04  | FK compuesta: ARTISTA no puede ser OYENTE    | Negativa
-- B05  | FK compuesta: OYENTE no puede ser ARTISTA    | Negativa
-- B06  | Rango de anio de album                       | Negativa
-- B07  | Duracion positiva                            | Negativa
-- B08  | RN-01 duplicado                              | Negativa
-- B09  | Proveedor e id_externo van juntos            | Negativa
-- B10  | Calificacion 1..5                            | Negativa
-- B11  | RN-03 duplicado                              | Negativa
-- B12  | Fechas de suscripcion                        | Negativa
-- B13  | Estado de suscripcion                        | Negativa
-- B14  | Regalias 0..100                              | Negativa
-- B15  | Fechas de contrato                           | Negativa
-- B16  | Contrato unico                               | Negativa
-- B17  | Orden positivo                               | Negativa
-- B18  | Orden unico por playlist                     | Negativa
-- B19  | RN-04 duplicado                              | Negativa
-- B20  | Rango de segundos escuchados                 | Negativa
-- B21  | Dominio de origen                            | Negativa
-- B22  | PLAYLIST exige id_playlist_origen            | Negativa
-- B23  | No PLAYLIST prohibe id_playlist_origen       | Negativa
-- B24  | Rol de colaboracion                          | Negativa
-- B25  | Genero unico por cancion                     | Negativa
-- B26  | Favorito unico                               | Negativa
-- B27  | Nombre de plan                               | Negativa
-- B28  | Precio de plan no negativo                   | Negativa
-- B29  | Playlist unica por oyente                    | Negativa
-- B30  | Apodo publico unico                          | Negativa
-- C01  | Alta de oyente                               | Positiva
-- C02  | Alta de artista                              | Positiva
-- C03  | Alta de album/cancion/artista principal      | Positiva
-- C04  | Alta de playlist/cancion                     | Positiva
-- C05  | Alta de calificacion/favorito                | Positiva
-- C06  | Alta de reproduccion desde playlist          | Positiva
