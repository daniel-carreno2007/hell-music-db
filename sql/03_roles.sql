-- ============================================================================
-- Proyecto : Hell Music
-- Archivo  : 03_roles.sql
-- Contenido: DCL: roles y privilegios (RF-1, F6)
-- Motor    : MySQL 8.0+ / MariaDB 10.5+ (roles nativos)
-- Nota     : Ejecutar despues de 01_schema.sql y 02_views.sql, con la base
--            de datos seleccionada. Reemplace hell_music por el nombre real
--            de la base si es distinto.
-- ============================================================================

USE hell_music;

-- ----------------------------------------------------------------------------
-- Roles
-- ----------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS rol_publico;
CREATE ROLE IF NOT EXISTS rol_oyente;
CREATE ROLE IF NOT EXISTS rol_artista;
CREATE ROLE IF NOT EXISTS rol_disquera;
CREATE ROLE IF NOT EXISTS rol_analista;
CREATE ROLE IF NOT EXISTS rol_admin;

-- ----------------------------------------------------------------------------
-- rol_publico: solo consulta de informacion publica
-- ----------------------------------------------------------------------------
GRANT SELECT ON vw_usuario_publico  TO rol_publico;
GRANT SELECT ON vw_oyente_publico   TO rol_publico;
GRANT SELECT ON vw_artista_publico  TO rol_publico;
GRANT SELECT ON vw_disquera_publica TO rol_publico;
GRANT SELECT ON vw_album_detalle    TO rol_publico;
GRANT SELECT ON vw_catalogo_canciones TO rol_publico;
GRANT SELECT ON vw_cancion_genero   TO rol_publico;
GRANT SELECT ON vw_playlist_publica TO rol_publico;

-- ----------------------------------------------------------------------------
-- rol_oyente: consulta publica + gestion de SUS propios datos.
-- La aplicacion restringe cada operacion con WHERE id_oyente = :usuario.
-- ----------------------------------------------------------------------------
GRANT SELECT ON vw_usuario_publico  TO rol_oyente;
GRANT SELECT ON vw_oyente_publico   TO rol_oyente;
GRANT SELECT ON vw_artista_publico  TO rol_oyente;
GRANT SELECT ON vw_disquera_publica TO rol_oyente;
GRANT SELECT ON vw_album_detalle    TO rol_oyente;
GRANT SELECT ON vw_catalogo_canciones TO rol_oyente;
GRANT SELECT ON vw_cancion_genero   TO rol_oyente;
GRANT SELECT ON vw_playlist_publica TO rol_oyente;
GRANT SELECT ON plan                TO rol_oyente;
GRANT SELECT ON suscripcion         TO rol_oyente;
GRANT SELECT ON vw_suscripcion_actual TO rol_oyente;

GRANT SELECT, INSERT, UPDATE, DELETE ON playlist          TO rol_oyente;
GRANT SELECT, INSERT, UPDATE, DELETE ON playlist_cancion  TO rol_oyente;
GRANT SELECT, INSERT, UPDATE, DELETE ON playlist_seguidor TO rol_oyente;
GRANT SELECT, INSERT, UPDATE, DELETE ON calificacion      TO rol_oyente;
GRANT SELECT, INSERT, UPDATE, DELETE ON favorito_cancion  TO rol_oyente;
GRANT SELECT, INSERT, UPDATE, DELETE ON favorito_album    TO rol_oyente;
GRANT SELECT, INSERT, UPDATE, DELETE ON favorito_artista  TO rol_oyente;
GRANT SELECT, INSERT                 ON reproduccion      TO rol_oyente;

-- ----------------------------------------------------------------------------
-- rol_artista: catalogo propio (album, canciones, generos, colaboraciones)
-- ----------------------------------------------------------------------------
GRANT SELECT ON vw_usuario_publico  TO rol_artista;
GRANT SELECT ON vw_artista_publico  TO rol_artista;
GRANT SELECT ON vw_disquera_publica TO rol_artista;
GRANT SELECT ON vw_album_detalle    TO rol_artista;
GRANT SELECT ON vw_catalogo_canciones TO rol_artista;
GRANT SELECT ON vw_cancion_genero   TO rol_artista;
GRANT SELECT ON genero              TO rol_artista;
GRANT SELECT ON contrato_derechos   TO rol_artista;
GRANT SELECT, INSERT, UPDATE        ON album             TO rol_artista;
GRANT SELECT, INSERT, UPDATE        ON cancion           TO rol_artista;
GRANT SELECT, INSERT, UPDATE, DELETE ON cancion_artista  TO rol_artista;
GRANT SELECT, INSERT, UPDATE, DELETE ON cancion_genero   TO rol_artista;

-- ----------------------------------------------------------------------------
-- rol_disquera: catalogo de sus artistas + lectura de contratos
-- ----------------------------------------------------------------------------
GRANT SELECT ON vw_usuario_publico  TO rol_disquera;
GRANT SELECT ON vw_artista_publico  TO rol_disquera;
GRANT SELECT ON vw_disquera_publica TO rol_disquera;
GRANT SELECT ON vw_album_detalle    TO rol_disquera;
GRANT SELECT ON vw_catalogo_canciones TO rol_disquera;
GRANT SELECT ON vw_cancion_genero   TO rol_disquera;
GRANT SELECT ON genero              TO rol_disquera;
GRANT SELECT ON contrato_derechos   TO rol_disquera;
GRANT SELECT, INSERT, UPDATE        ON album             TO rol_disquera;
GRANT SELECT, INSERT, UPDATE        ON cancion           TO rol_disquera;
GRANT SELECT, INSERT, UPDATE, DELETE ON cancion_artista  TO rol_disquera;
GRANT SELECT, INSERT, UPDATE, DELETE ON cancion_genero   TO rol_disquera;

-- ----------------------------------------------------------------------------
-- rol_analista: lectura completa para las 9 preguntas de negocio
-- ----------------------------------------------------------------------------
GRANT SELECT ON usuario            TO rol_analista;
GRANT SELECT ON oyente             TO rol_analista;
GRANT SELECT ON artista            TO rol_analista;
GRANT SELECT ON disquera           TO rol_analista;
GRANT SELECT ON plan               TO rol_analista;
GRANT SELECT ON suscripcion        TO rol_analista;
GRANT SELECT ON contrato_derechos  TO rol_analista;
GRANT SELECT ON album              TO rol_analista;
GRANT SELECT ON cancion            TO rol_analista;
GRANT SELECT ON genero             TO rol_analista;
GRANT SELECT ON cancion_artista    TO rol_analista;
GRANT SELECT ON cancion_genero     TO rol_analista;
GRANT SELECT ON playlist           TO rol_analista;
GRANT SELECT ON playlist_cancion   TO rol_analista;
GRANT SELECT ON playlist_seguidor  TO rol_analista;
GRANT SELECT ON reproduccion       TO rol_analista;
GRANT SELECT ON calificacion       TO rol_analista;
GRANT SELECT ON favorito_cancion   TO rol_analista;
GRANT SELECT ON favorito_album     TO rol_analista;
GRANT SELECT ON favorito_artista   TO rol_analista;
GRANT SELECT ON vw_usuario_publico TO rol_analista;
GRANT SELECT ON vw_oyente_publico  TO rol_analista;
GRANT SELECT ON vw_artista_publico TO rol_analista;
GRANT SELECT ON vw_disquera_publica TO rol_analista;
GRANT SELECT ON vw_album_detalle   TO rol_analista;
GRANT SELECT ON vw_catalogo_canciones TO rol_analista;
GRANT SELECT ON vw_cancion_genero  TO rol_analista;
GRANT SELECT ON vw_playlist_publica TO rol_analista;
GRANT SELECT ON vw_suscripcion_actual TO rol_analista;
GRANT SELECT ON vw_reproduccion_analitica TO rol_analista;

-- ----------------------------------------------------------------------------
-- rol_admin: control total (DBA)
-- Reemplace hell_music por el nombre real de la base.
-- ----------------------------------------------------------------------------
GRANT ALL PRIVILEGES ON hell_music.* TO rol_admin;

-- ----------------------------------------------------------------------------
-- Ejemplo de asignacion de roles a usuarios de aplicacion (MySQL 8+).
-- Cada usuario de aplicacion recibe UN rol; el rol se activa por defecto.
-- ----------------------------------------------------------------------------
-- CREATE USER 'app_oyente'@'localhost'   IDENTIFIED BY 'CambiarEstaClave1!';
-- CREATE USER 'app_artista'@'localhost'  IDENTIFIED BY 'CambiarEstaClave2!';
-- CREATE USER 'app_disquera'@'localhost' IDENTIFIED BY 'CambiarEstaClave3!';
-- CREATE USER 'app_analista'@'localhost' IDENTIFIED BY 'CambiarEstaClave4!';
-- GRANT rol_oyente   TO 'app_oyente'@'localhost';
-- GRANT rol_artista  TO 'app_artista'@'localhost';
-- GRANT rol_disquera TO 'app_disquera'@'localhost';
-- GRANT rol_analista TO 'app_analista'@'localhost';
-- SET DEFAULT ROLE rol_oyente   TO 'app_oyente'@'localhost';
-- SET DEFAULT ROLE rol_artista  TO 'app_artista'@'localhost';
-- SET DEFAULT ROLE rol_disquera TO 'app_disquera'@'localhost';
-- SET DEFAULT ROLE rol_analista TO 'app_analista'@'localhost';

