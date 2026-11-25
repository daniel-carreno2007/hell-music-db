-- ============================================================================
-- Proyecto : Hell Music
-- Archivo  : 01_schema.sql
-- Contenido: DDL del modelo relacional (20 tablas)
-- Motor    : MySQL 8.0+ / MariaDB 10.5+ (SQL estandar, sin PostgreSQL)
-- Nota     : El script asume una base de datos vacia. No usa SERIAL,
--            AUTO_INCREMENT, JSONB, ENUM ni tipos propietarios de PostgreSQL.
--            Los identificadores se suministran explicitamente (seed y app).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Planes de suscripcion (resuelve la incoherencia "Premium" sin modelo)
-- ----------------------------------------------------------------------------
CREATE TABLE plan (
    id_plan        INTEGER      NOT NULL,
    nombre_plan    VARCHAR(20)  NOT NULL,
    precio_mensual NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_plan PRIMARY KEY (id_plan),
    CONSTRAINT uq_plan_nombre UNIQUE (nombre_plan),
    CONSTRAINT ck_plan_nombre CHECK (nombre_plan IN ('GRATUITO', 'PREMIUM')),
    CONSTRAINT ck_plan_precio CHECK (precio_mensual >= 0)
);

-- ----------------------------------------------------------------------------
-- 2. Generos musicales
-- ----------------------------------------------------------------------------
CREATE TABLE genero (
    id_genero     INTEGER      NOT NULL,
    nombre_genero VARCHAR(50)  NOT NULL,
    descripcion   VARCHAR(300),
    CONSTRAINT pk_genero PRIMARY KEY (id_genero),
    CONSTRAINT uq_genero_nombre UNIQUE (nombre_genero)
);

-- ----------------------------------------------------------------------------
-- 3. Usuario: superclase de oyente, artista y disquera.
--    Agrega credenciales y estado, necesarios para RF-1 (autenticacion).
-- ----------------------------------------------------------------------------
CREATE TABLE usuario (
    id_usuario      INTEGER      NOT NULL,
    correo          VARCHAR(120) NOT NULL,
    nombre_usuario  VARCHAR(50)  NOT NULL,
    contrasena_hash VARCHAR(255) NOT NULL,
    fecha_registro  DATE         NOT NULL,
    pais            VARCHAR(60)  NOT NULL,
    tipo_usuario    VARCHAR(10)  NOT NULL,
    activo          BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_usuario PRIMARY KEY (id_usuario),
    CONSTRAINT uq_usuario_correo UNIQUE (correo),
    CONSTRAINT uq_usuario_nombre UNIQUE (nombre_usuario),
    CONSTRAINT uq_usuario_tipo UNIQUE (id_usuario, tipo_usuario),
    CONSTRAINT ck_usuario_tipo CHECK (tipo_usuario IN ('OYENTE', 'ARTISTA', 'DISQUERA'))
);

-- ----------------------------------------------------------------------------
-- 4. Oyente: subclase de usuario (PK = FK a usuario).
--    La FK compuesta (id_usuario, tipo_usuario) impide que un usuario sea
--    oyente y artista/disquera a la vez, sin necesidad de triggers.
-- ----------------------------------------------------------------------------
CREATE TABLE oyente (
    id_usuario       INTEGER     NOT NULL,
    tipo_usuario     VARCHAR(10) NOT NULL DEFAULT 'OYENTE',
    apodo_publico    VARCHAR(50) NOT NULL,
    fecha_nacimiento DATE,
    CONSTRAINT pk_oyente PRIMARY KEY (id_usuario),
    CONSTRAINT fk_oyente_usuario FOREIGN KEY (id_usuario, tipo_usuario)
        REFERENCES usuario (id_usuario, tipo_usuario) ON DELETE CASCADE,
    CONSTRAINT uq_oyente_apodo UNIQUE (apodo_publico),
    CONSTRAINT ck_oyente_tipo CHECK (tipo_usuario = 'OYENTE')
);

-- ----------------------------------------------------------------------------
-- 5. Artista: subclase de usuario (PK = FK a usuario).
--    tipo_artista se conserva por compatibilidad con la ficha F9; su
--    consistencia con contrato_derechos se valida en 06_tests.sql.
-- ----------------------------------------------------------------------------
CREATE TABLE artista (
    id_usuario       INTEGER     NOT NULL,
    tipo_usuario     VARCHAR(10) NOT NULL DEFAULT 'ARTISTA',
    nombre_artistico VARCHAR(80) NOT NULL,
    biografia        VARCHAR(500),
    tipo_artista     VARCHAR(15) NOT NULL,
    pais_origen      VARCHAR(60) NOT NULL,
    CONSTRAINT pk_artista PRIMARY KEY (id_usuario),
    CONSTRAINT fk_artista_usuario FOREIGN KEY (id_usuario, tipo_usuario)
        REFERENCES usuario (id_usuario, tipo_usuario) ON DELETE CASCADE,
    CONSTRAINT uq_artista_nombre UNIQUE (nombre_artistico),
    CONSTRAINT ck_artista_tipo CHECK (tipo_artista IN ('INDEPENDIENTE', 'VINCULADO')),
    CONSTRAINT ck_artista_usuario_tipo CHECK (tipo_usuario = 'ARTISTA')
);

-- ----------------------------------------------------------------------------
-- 6. Disquera: subclase de usuario (PK = FK a usuario).
--    Ahora puede autenticarse, lo que resuelve la incoherencia con RF-1.
-- ----------------------------------------------------------------------------
CREATE TABLE disquera (
    id_usuario      INTEGER      NOT NULL,
    tipo_usuario    VARCHAR(10)  NOT NULL DEFAULT 'DISQUERA',
    nit             VARCHAR(20)  NOT NULL,
    razon_social    VARCHAR(120) NOT NULL,
    pais_sede       VARCHAR(60)  NOT NULL,
    correo_contacto VARCHAR(120) NOT NULL,
    CONSTRAINT pk_disquera PRIMARY KEY (id_usuario),
    CONSTRAINT fk_disquera_usuario FOREIGN KEY (id_usuario, tipo_usuario)
        REFERENCES usuario (id_usuario, tipo_usuario) ON DELETE CASCADE,
    CONSTRAINT uq_disquera_nit UNIQUE (nit),
    CONSTRAINT uq_disquera_razon UNIQUE (razon_social),
    CONSTRAINT ck_disquera_usuario_tipo CHECK (tipo_usuario = 'DISQUERA')
);

-- ----------------------------------------------------------------------------
-- 7. Contrato de derechos artista-disquera (historial del vinculo).
--    Se conserva como dato historico; la gestion operativa sigue fuera de
--    alcance. Un artista puede tener varios contratos en el tiempo.
-- ----------------------------------------------------------------------------
CREATE TABLE contrato_derechos (
    id_contrato         INTEGER       NOT NULL,
    id_artista          INTEGER       NOT NULL,
    id_disquera         INTEGER       NOT NULL,
    fecha_inicio        DATE          NOT NULL,
    fecha_fin           DATE,
    porcentaje_regalias NUMERIC(5,2)  NOT NULL,
    estado_contrato     VARCHAR(12)   NOT NULL,
    CONSTRAINT pk_contrato PRIMARY KEY (id_contrato),
    CONSTRAINT fk_contrato_artista FOREIGN KEY (id_artista)
        REFERENCES artista (id_usuario),
    CONSTRAINT fk_contrato_disquera FOREIGN KEY (id_disquera)
        REFERENCES disquera (id_usuario),
    CONSTRAINT uq_contrato UNIQUE (id_artista, id_disquera, fecha_inicio),
    CONSTRAINT ck_contrato_regalias CHECK (porcentaje_regalias >= 0 AND porcentaje_regalias <= 100),
    CONSTRAINT ck_contrato_fechas CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio),
    CONSTRAINT ck_contrato_estado CHECK (estado_contrato IN ('VIGENTE', 'FINALIZADO', 'SUSPENDIDO'))
);

-- ----------------------------------------------------------------------------
-- 8. Album: pertenece a un artista; la disquera que lo publica es opcional
--    (un artista independiente no tiene disquera).
-- ----------------------------------------------------------------------------
CREATE TABLE album (
    id_album         INTEGER      NOT NULL,
    titulo_album     VARCHAR(120) NOT NULL,
    anio_lanzamiento INTEGER      NOT NULL,
    tipo_produccion  VARCHAR(10)  NOT NULL,
    portada_url      VARCHAR(255),
    id_artista       INTEGER      NOT NULL,
    id_disquera      INTEGER,
    CONSTRAINT pk_album PRIMARY KEY (id_album),
    CONSTRAINT fk_album_artista FOREIGN KEY (id_artista)
        REFERENCES artista (id_usuario),
    CONSTRAINT fk_album_disquera FOREIGN KEY (id_disquera)
        REFERENCES disquera (id_usuario),
    CONSTRAINT uq_album_titulo UNIQUE (id_artista, titulo_album, anio_lanzamiento),
    CONSTRAINT ck_album_anio CHECK (anio_lanzamiento BETWEEN 1900 AND 2100),
    CONSTRAINT ck_album_tipo CHECK (tipo_produccion IN ('LP', 'EP', 'SENCILLO'))
);

-- ----------------------------------------------------------------------------
-- 9. Cancion: metadatos + ruta/URL. La BD nunca almacena audio binario.
--    proveedor + id_externo implementan RN-01 (sin duplicados con la API).
-- ----------------------------------------------------------------------------
CREATE TABLE cancion (
    id_cancion         INTEGER      NOT NULL,
    titulo_cancion     VARCHAR(150) NOT NULL,
    num_pista          INTEGER,
    duracion_segundos  INTEGER      NOT NULL,
    ruta_archivo_audio VARCHAR(500) NOT NULL,
    es_explicita       BOOLEAN      NOT NULL DEFAULT FALSE,
    id_album           INTEGER,
    proveedor          VARCHAR(10),
    id_externo         VARCHAR(100),
    CONSTRAINT pk_cancion PRIMARY KEY (id_cancion),
    CONSTRAINT fk_cancion_album FOREIGN KEY (id_album)
        REFERENCES album (id_album),
    CONSTRAINT uq_cancion_proveedor UNIQUE (proveedor, id_externo),
    CONSTRAINT ck_cancion_duracion CHECK (duracion_segundos > 0),
    CONSTRAINT ck_cancion_pista CHECK (num_pista IS NULL OR num_pista > 0),
    CONSTRAINT ck_cancion_album_pista CHECK (id_album IS NULL OR num_pista IS NOT NULL),
    CONSTRAINT ck_cancion_proveedor CHECK (proveedor IS NULL OR proveedor IN ('PROPIO', 'JAMENDO', 'AUDIUS')),
    CONSTRAINT ck_cancion_externo CHECK (
        (proveedor IS NULL AND id_externo IS NULL)
        OR (proveedor IS NOT NULL AND id_externo IS NOT NULL)
    )
);

-- ----------------------------------------------------------------------------
-- 10. Cancion-Artista: M:N para colaboraciones (RF-3)
-- ----------------------------------------------------------------------------
CREATE TABLE cancion_artista (
    id_cancion INTEGER     NOT NULL,
    id_artista INTEGER     NOT NULL,
    rol        VARCHAR(12) NOT NULL,
    CONSTRAINT pk_cancion_artista PRIMARY KEY (id_cancion, id_artista),
    CONSTRAINT fk_ca_cancion FOREIGN KEY (id_cancion)
        REFERENCES cancion (id_cancion) ON DELETE CASCADE,
    CONSTRAINT fk_ca_artista FOREIGN KEY (id_artista)
        REFERENCES artista (id_usuario),
    CONSTRAINT ck_ca_rol CHECK (rol IN ('PRINCIPAL', 'FEATURING'))
);

-- ----------------------------------------------------------------------------
-- 11. Cancion-Genero: M:N (una cancion puede tener varios generos)
-- ----------------------------------------------------------------------------
CREATE TABLE cancion_genero (
    id_cancion INTEGER NOT NULL,
    id_genero  INTEGER NOT NULL,
    CONSTRAINT pk_cancion_genero PRIMARY KEY (id_cancion, id_genero),
    CONSTRAINT fk_cg_cancion FOREIGN KEY (id_cancion)
        REFERENCES cancion (id_cancion) ON DELETE CASCADE,
    CONSTRAINT fk_cg_genero FOREIGN KEY (id_genero)
        REFERENCES genero (id_genero)
);

-- ----------------------------------------------------------------------------
-- 12. Playlist: creada por un oyente
-- ----------------------------------------------------------------------------
CREATE TABLE playlist (
    id_playlist     INTEGER      NOT NULL,
    id_oyente       INTEGER      NOT NULL,
    nombre_playlist VARCHAR(100) NOT NULL,
    tematica        VARCHAR(100),
    fecha_creacion  DATE         NOT NULL,
    es_publica      BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_playlist PRIMARY KEY (id_playlist),
    CONSTRAINT fk_playlist_oyente FOREIGN KEY (id_oyente)
        REFERENCES oyente (id_usuario) ON DELETE CASCADE,
    CONSTRAINT uq_playlist_nombre UNIQUE (id_oyente, nombre_playlist)
);

-- ----------------------------------------------------------------------------
-- 13. Playlist-Cancion: M:N con orden. PK compuesta implementa RN-04
--     (una cancion no se repite en la misma playlist).
-- ----------------------------------------------------------------------------
CREATE TABLE playlist_cancion (
    id_playlist    INTEGER NOT NULL,
    id_cancion     INTEGER NOT NULL,
    orden          INTEGER NOT NULL,
    fecha_agregado DATE    NOT NULL,
    CONSTRAINT pk_playlist_cancion PRIMARY KEY (id_playlist, id_cancion),
    CONSTRAINT fk_pc_playlist FOREIGN KEY (id_playlist)
        REFERENCES playlist (id_playlist) ON DELETE CASCADE,
    CONSTRAINT fk_pc_cancion FOREIGN KEY (id_cancion)
        REFERENCES cancion (id_cancion),
    CONSTRAINT uq_pc_orden UNIQUE (id_playlist, orden),
    CONSTRAINT ck_pc_orden CHECK (orden > 0)
);

-- ----------------------------------------------------------------------------
-- 14. Playlist-Seguidor: resuelve F10-Q5 (playlists con mas seguidores)
-- ----------------------------------------------------------------------------
CREATE TABLE playlist_seguidor (
    id_playlist       INTEGER NOT NULL,
    id_oyente         INTEGER NOT NULL,
    fecha_seguimiento DATE    NOT NULL,
    CONSTRAINT pk_playlist_seguidor PRIMARY KEY (id_playlist, id_oyente),
    CONSTRAINT fk_ps_playlist FOREIGN KEY (id_playlist)
        REFERENCES playlist (id_playlist) ON DELETE CASCADE,
    CONSTRAINT fk_ps_oyente FOREIGN KEY (id_oyente)
        REFERENCES oyente (id_usuario) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 15. Suscripcion: historial de planes por usuario (F10-Q2 y F10-Q4).
--     Un solo plan activo por usuario se valida en 06_tests.sql (regla de app).
-- ----------------------------------------------------------------------------
CREATE TABLE suscripcion (
    id_suscripcion INTEGER      NOT NULL,
    id_usuario     INTEGER      NOT NULL,
    id_plan        INTEGER      NOT NULL,
    fecha_inicio   DATE         NOT NULL,
    fecha_fin      DATE,
    estado         VARCHAR(10)  NOT NULL,
    CONSTRAINT pk_suscripcion PRIMARY KEY (id_suscripcion),
    CONSTRAINT fk_sus_usuario FOREIGN KEY (id_usuario)
        REFERENCES usuario (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_sus_plan FOREIGN KEY (id_plan)
        REFERENCES plan (id_plan),
    CONSTRAINT ck_sus_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT ck_sus_estado CHECK (estado IN ('ACTIVA', 'CANCELADA', 'VENCIDA'))
);

-- ----------------------------------------------------------------------------
-- 16. Calificacion: resuelve RF-5 y RN-03 (una calificacion por oyente/cancion)
-- ----------------------------------------------------------------------------
CREATE TABLE calificacion (
    id_oyente          INTEGER NOT NULL,
    id_cancion         INTEGER NOT NULL,
    valor              INTEGER NOT NULL,
    fecha_calificacion DATE    NOT NULL,
    CONSTRAINT pk_calificacion PRIMARY KEY (id_oyente, id_cancion),
    CONSTRAINT fk_cal_oyente FOREIGN KEY (id_oyente)
        REFERENCES oyente (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_cal_cancion FOREIGN KEY (id_cancion)
        REFERENCES cancion (id_cancion) ON DELETE CASCADE,
    CONSTRAINT ck_cal_valor CHECK (valor BETWEEN 1 AND 5)
);

-- ----------------------------------------------------------------------------
-- 17-19. Favoritos: resuelven el proceso de F6 que no tenia entidad
-- ----------------------------------------------------------------------------
CREATE TABLE favorito_cancion (
    id_oyente     INTEGER NOT NULL,
    id_cancion    INTEGER NOT NULL,
    fecha_marcado DATE    NOT NULL,
    CONSTRAINT pk_favorito_cancion PRIMARY KEY (id_oyente, id_cancion),
    CONSTRAINT fk_fc_oyente FOREIGN KEY (id_oyente)
        REFERENCES oyente (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_fc_cancion FOREIGN KEY (id_cancion)
        REFERENCES cancion (id_cancion) ON DELETE CASCADE
);

CREATE TABLE favorito_album (
    id_oyente     INTEGER NOT NULL,
    id_album      INTEGER NOT NULL,
    fecha_marcado DATE    NOT NULL,
    CONSTRAINT pk_favorito_album PRIMARY KEY (id_oyente, id_album),
    CONSTRAINT fk_fa_oyente FOREIGN KEY (id_oyente)
        REFERENCES oyente (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_fa_album FOREIGN KEY (id_album)
        REFERENCES album (id_album) ON DELETE CASCADE
);

CREATE TABLE favorito_artista (
    id_oyente     INTEGER NOT NULL,
    id_artista    INTEGER NOT NULL,
    fecha_marcado DATE    NOT NULL,
    CONSTRAINT pk_favorito_artista PRIMARY KEY (id_oyente, id_artista),
    CONSTRAINT fk_fart_oyente FOREIGN KEY (id_oyente)
        REFERENCES oyente (id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_fart_artista FOREIGN KEY (id_artista)
        REFERENCES artista (id_usuario) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 20. Reproduccion: entidad debil/historica. PK = oyente + cancion + instante
--     (RN-05). Agrega cancion previa (RF-6/RF-7), origen (F10-Q3) y playlist
--     de origen. La BD guarda solo el enlace, nunca el audio (RN-01).
-- ----------------------------------------------------------------------------
CREATE TABLE reproduccion (
    id_oyente               INTEGER     NOT NULL,
    id_cancion              INTEGER     NOT NULL,
    fecha_hora_reproduccion TIMESTAMP   NOT NULL,
    segundos_escuchados     INTEGER     NOT NULL,
    dispositivo             VARCHAR(50),
    id_cancion_previa       INTEGER,
    origen                  VARCHAR(16) NOT NULL,
    id_playlist_origen      INTEGER,
    CONSTRAINT pk_reproduccion PRIMARY KEY (id_oyente, id_cancion, fecha_hora_reproduccion),
    CONSTRAINT fk_rep_oyente FOREIGN KEY (id_oyente)
        REFERENCES oyente (id_usuario),
    CONSTRAINT fk_rep_cancion FOREIGN KEY (id_cancion)
        REFERENCES cancion (id_cancion),
    CONSTRAINT fk_rep_previa FOREIGN KEY (id_cancion_previa)
        REFERENCES cancion (id_cancion),
    CONSTRAINT fk_rep_playlist FOREIGN KEY (id_playlist_origen)
        REFERENCES playlist (id_playlist),
    CONSTRAINT ck_rep_segundos CHECK (segundos_escuchados >= 0 AND segundos_escuchados <= 86400),
    CONSTRAINT ck_rep_origen CHECK (origen IN ('PLAYLIST', 'RECOMENDACION', 'BUSQUEDA', 'ALBUM', 'OTRO')),
    CONSTRAINT ck_rep_playlist CHECK (
        (origen = 'PLAYLIST' AND id_playlist_origen IS NOT NULL)
        OR (origen <> 'PLAYLIST' AND id_playlist_origen IS NULL)
    )
);

-- ----------------------------------------------------------------------------
-- Indices de apoyo para las consultas analiticas
-- ----------------------------------------------------------------------------
CREATE INDEX ix_reproduccion_fecha    ON reproduccion (fecha_hora_reproduccion);
CREATE INDEX ix_reproduccion_cancion  ON reproduccion (id_cancion);
CREATE INDEX ix_cancion_album         ON cancion (id_album);
CREATE INDEX ix_cancion_artista_art   ON cancion_artista (id_artista);
CREATE INDEX ix_cancion_genero_gen    ON cancion_genero (id_genero);
CREATE INDEX ix_album_artista         ON album (id_artista);
CREATE INDEX ix_playlist_oyente       ON playlist (id_oyente);
CREATE INDEX ix_playlist_cancion_c    ON playlist_cancion (id_cancion);
CREATE INDEX ix_contrato_disquera     ON contrato_derechos (id_disquera);
CREATE INDEX ix_suscripcion_usuario   ON suscripcion (id_usuario, estado);
CREATE INDEX ix_calificacion_cancion  ON calificacion (id_cancion);
CREATE INDEX ix_fav_album_album       ON favorito_album (id_album);
CREATE INDEX ix_fav_artista_artista   ON favorito_artista (id_artista);
