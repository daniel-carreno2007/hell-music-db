-- ============================================================================
-- Proyecto : Hell Music
-- Archivo  : 02_views.sql
-- Contenido: Vistas de privacidad y de apoyo analitico
-- Motor    : MySQL 8.0+ / MariaDB 10.5+
-- Nota     : Las vistas ocultan columnas sensibles (correo, contrasena,
--            fecha de nacimiento). El filtrado por fila (que un oyente solo
--            vea SU historial) se resuelve en la aplicacion con
--            WHERE id_oyente = :usuario_actual, porque el SQL estandar no
--            ofrece seguridad a nivel de fila portable.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Perfiles publicos (sin datos personales sensibles)
-- ----------------------------------------------------------------------------
CREATE VIEW vw_usuario_publico AS
SELECT u.id_usuario,
       u.nombre_usuario,
       u.pais,
       u.fecha_registro,
       u.tipo_usuario
FROM usuario u
WHERE u.activo = TRUE;

CREATE VIEW vw_oyente_publico AS
SELECT o.id_usuario,
       o.apodo_publico,
       u.pais,
       u.fecha_registro
FROM oyente o
JOIN usuario u ON u.id_usuario = o.id_usuario
WHERE u.activo = TRUE;

CREATE VIEW vw_artista_publico AS
SELECT a.id_usuario,
       a.nombre_artistico,
       a.biografia,
       a.tipo_artista,
       a.pais_origen
FROM artista a;

CREATE VIEW vw_disquera_publica AS
SELECT d.id_usuario,
       d.nit,
       d.razon_social,
       d.pais_sede,
       d.correo_contacto
FROM disquera d;

-- ----------------------------------------------------------------------------
-- Catalogo musical
-- ----------------------------------------------------------------------------
CREATE VIEW vw_album_detalle AS
SELECT al.id_album,
       al.titulo_album,
       al.anio_lanzamiento,
       al.tipo_produccion,
       al.portada_url,
       ar.nombre_artistico,
       d.razon_social AS disquera
FROM album al
JOIN artista ar ON ar.id_usuario = al.id_artista
LEFT JOIN disquera d ON d.id_usuario = al.id_disquera;

CREATE VIEW vw_catalogo_canciones AS
SELECT c.id_cancion,
       c.titulo_cancion,
       c.duracion_segundos,
       c.es_explicita,
       c.ruta_archivo_audio,
       c.id_album,
       al.titulo_album,
       al.anio_lanzamiento,
       ar.nombre_artistico AS artista_principal
FROM cancion c
LEFT JOIN album al ON al.id_album = c.id_album
LEFT JOIN cancion_artista ca ON ca.id_cancion = c.id_cancion AND ca.rol = 'PRINCIPAL'
LEFT JOIN artista ar ON ar.id_usuario = ca.id_artista;

CREATE VIEW vw_cancion_genero AS
SELECT c.id_cancion,
       c.titulo_cancion,
       g.id_genero,
       g.nombre_genero
FROM cancion c
JOIN cancion_genero cg ON cg.id_cancion = c.id_cancion
JOIN genero g ON g.id_genero = cg.id_genero;

-- ----------------------------------------------------------------------------
-- Playlists publicas con contadores
-- ----------------------------------------------------------------------------
CREATE VIEW vw_playlist_publica AS
SELECT pl.id_playlist,
       pl.nombre_playlist,
       pl.tematica,
       pl.fecha_creacion,
       o.apodo_publico AS creador,
       (SELECT COUNT(*) FROM playlist_cancion pc
         WHERE pc.id_playlist = pl.id_playlist) AS num_canciones,
       (SELECT COUNT(*) FROM playlist_seguidor ps
         WHERE ps.id_playlist = pl.id_playlist) AS num_seguidores
FROM playlist pl
JOIN oyente o ON o.id_usuario = pl.id_oyente
WHERE pl.es_publica = TRUE;

-- ----------------------------------------------------------------------------
-- Suscripcion vigente (solo plan, sin datos de pago)
-- ----------------------------------------------------------------------------
CREATE VIEW vw_suscripcion_actual AS
SELECT s.id_usuario,
       u.nombre_usuario,
       p.nombre_plan,
       s.fecha_inicio,
       s.estado
FROM suscripcion s
JOIN usuario u ON u.id_usuario = s.id_usuario
JOIN plan p ON p.id_plan = s.id_plan
WHERE s.estado = 'ACTIVA' AND s.fecha_fin IS NULL;

-- ----------------------------------------------------------------------------
-- Historial detallado: solo para rol_analista / rol_admin.
-- No se concede a rol_oyente ni a rol_publico.
-- ----------------------------------------------------------------------------
CREATE VIEW vw_reproduccion_analitica AS
SELECT r.id_oyente,
       o.apodo_publico,
       r.id_cancion,
       c.titulo_cancion,
       r.fecha_hora_reproduccion,
       r.segundos_escuchados,
       r.dispositivo,
       r.origen,
       r.id_playlist_origen
FROM reproduccion r
JOIN oyente o ON o.id_usuario = r.id_oyente
JOIN cancion c ON c.id_cancion = r.id_cancion;
