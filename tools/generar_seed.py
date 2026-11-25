# -*- coding: utf-8 -*-
"""
Generador reproducible de datos de prueba para Hell Music.
Salida: sql/04_seed.sql
No requiere dependencias externas (solo biblioteca estandar).
"""
import os
import random
from datetime import date, datetime, timedelta

random.seed(20261125)

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(BASE, "sql", "04_seed.sql")

# ---------------------------------------------------------------------------
# Utilidades de formato SQL
# ---------------------------------------------------------------------------
def q(value):
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def qd(value):
    return "NULL" if value is None else "'" + value.isoformat() + "'"


def lit(value):
    return "NULL" if value is None else str(value)


def qt(value):
    return "NULL" if value is None else "'" + value.strftime("%Y-%m-%d %H:%M:%S") + "'"


def block(table, columns, rows, batch=200):
    if not rows:
        return ""
    parts = []
    for i in range(0, len(rows), batch):
        chunk = rows[i:i + batch]
        values = ",\n".join("(" + ", ".join(str(v) for v in r) + ")" for r in chunk)
        parts.append(
            "INSERT INTO %s (%s) VALUES\n%s;" % (table, ", ".join(columns), values)
        )
    return "\n\n".join(parts)


def rand_date(start, end):
    delta = (end - start).days
    return start + timedelta(days=random.randint(0, delta))


def rand_dt(start, end):
    delta = int((end - start).total_seconds())
    return start + timedelta(seconds=random.randint(0, delta))


def add_month(d):
    if d.month == 12:
        return date(d.year + 1, 1, 1)
    return date(d.year, d.month + 1, 1)


# ---------------------------------------------------------------------------
# Catalogos base
# ---------------------------------------------------------------------------
planes = [
    (1, "GRATUITO", "0.00"),
    (2, "PREMIUM", "19900.00"),
]

generos = [
    (1, "Rock", "Guitarras electricas y ritmos intensos"),
    (2, "Pop", "Melodias comerciales y estribillos pegajosos"),
    (3, "Hip Hop", "Rap, ritmo urbano y cultura del samples"),
    (4, "Electronica", "Sintetizadores, beats y produccion digital"),
    (5, "Jazz", "Improvisacion, armonia y swing"),
    (6, "Clasica", "Musica academica y orquestal"),
    (7, "Reggaeton", "Ritmo urbano latino y dembow"),
    (8, "Indie", "Produccion independiente y sonidos alternativos"),
]
genero_id = {nombre: gid for gid, nombre, _ in generos}

# ---------------------------------------------------------------------------
# Usuarios: 3 disqueras (1-3), 10 artistas (4-13), 30 oyentes (14-43)
# ---------------------------------------------------------------------------
disqueras = [
    (1, "Nova Records", "900111222-1", "Colombia", "contacto@novarecords.demo"),
    (2, "Andes Music", "900333444-2", "Mexico", "contacto@andesmusic.demo"),
    (3, "Iberia Sound", "900555666-3", "Espana", "contacto@iberiasound.demo"),
]

artistas = [
    # id, nombre artistico, genero, pais, disquera, tipo, fecha_registro
    (4, "Aurora Vega", "Pop", "Colombia", 1, "VINCULADO", date(2024, 1, 15)),
    (5, "Los Caimanes", "Rock", "Colombia", None, "INDEPENDIENTE", date(2024, 2, 10)),
    (6, "Nico Flow", "Hip Hop", "Mexico", 2, "VINCULADO", date(2024, 3, 5)),
    (7, "Luna Mar", "Indie", "Argentina", None, "INDEPENDIENTE", date(2024, 4, 20)),
    (8, "DJ Solaris", "Electronica", "Espana", 3, "VINCULADO", date(2024, 5, 12)),
    (9, "Valeria Cruz", "Pop", "Mexico", 2, "VINCULADO", date(2024, 6, 1)),
    (10, "El Pulso", "Reggaeton", "Colombia", 1, "VINCULADO", date(2024, 7, 18)),
    (11, "Marea Alta", "Rock", "Chile", None, "INDEPENDIENTE", date(2024, 8, 22)),
    (12, "Sofia Andrade", "Jazz", "Argentina", None, "INDEPENDIENTE", date(2024, 9, 9)),
    (13, "Codigo Norte", "Electronica", "Peru", 2, "VINCULADO", date(2024, 10, 30)),
]

# 30 oyentes: distribucion por pais
oyente_paises = (
    ["Colombia"] * 4 + ["Mexico"] * 4 + ["Argentina"] * 3 + ["Espana"] * 3
    + ["Estados Unidos"] * 3 + ["Chile"] * 2 + ["Peru"] * 2 + ["Ecuador"] * 2
    + ["Uruguay"] * 2 + ["Brasil"] * 2 + ["Francia"] * 1 + ["Alemania"] * 2
)
assert len(oyente_paises) == 30

oyentes = []
for i, pais in enumerate(oyente_paises):
    uid = 14 + i
    if i in (0, 1, 4, 5, 8, 9, 12, 15):
        reg = rand_date(date(2025, 1, 15), date(2025, 5, 15))
    else:
        reg = rand_date(date(2025, 1, 1), date(2026, 6, 30))
    oyentes.append({
        "id": uid,
        "apodo": "melomano_%02d" % (i + 1),
        "usuario": "oyente_%02d" % (i + 1),
        "correo": "oyente%02d@demo.com" % (i + 1),
        "pais": pais,
        "nacimiento": rand_date(date(1985, 1, 1), date(2005, 12, 31)),
        "registro": reg,
    })

# Suscripciones: 7 premium vigentes, 1 premium cancelada, 22 nunca premium
premium_vigente = {0, 1, 4, 5, 8, 12, 15}
premium_pasado = {9}
power_free = [17, 21, 25]  # indices dentro de oyentes

# ---------------------------------------------------------------------------
# Contratos
# ---------------------------------------------------------------------------
contratos = [
    (1, 4, 1, date(2024, 1, 1), None, "15.00", "VIGENTE"),
    (2, 6, 2, date(2024, 6, 1), None, "12.50", "VIGENTE"),
    (3, 8, 3, date(2025, 1, 1), None, "18.00", "VIGENTE"),
    (4, 9, 2, date(2025, 3, 1), None, "14.00", "VIGENTE"),
    (5, 10, 1, date(2024, 9, 1), None, "16.00", "VIGENTE"),
    (6, 13, 2, date(2025, 5, 1), None, "11.00", "VIGENTE"),
    (7, 12, 3, date(2023, 1, 1), date(2024, 12, 31), "20.00", "FINALIZADO"),
    (8, 4, 2, date(2022, 1, 1), date(2023, 12, 31), "10.00", "FINALIZADO"),
]

# ---------------------------------------------------------------------------
# Albumes (30) y canciones (200)
# ---------------------------------------------------------------------------
album_words = [
    ("Horizonte", "Nocturno"), ("Ritmo", "Solar"), ("Silencio", "Azul"),
    ("Fuego", "Salvaje"), ("Viaje", "Eterno"), ("Espejo", "Digital"),
    ("Calle", "Urbano"), ("Mar", "Lejano"), ("Cielo", "Intimo"),
    ("Pulso", "Salitroso"), ("Sombra", "Fractal"), ("Aurora", "Electrico"),
    ("Desierto", "Neon"), ("Lluvia", "Analogo"), ("Viento", "Sur"),
    ("Noche", "Central"), ("Rio", "Abierto"), ("Tierra", "Fertil"),
    ("Cristal", "Roto"), ("Bosque", "Humedo"), ("Relampago", "Dorado"),
    ("Oceano", "Profundo"), ("Montana", "Alta"), ("Ciudad", "Dormida"),
    ("Estrella", "Fugaz"), ("Camino", "Largo"), ("Puerto", "Libre"),
    ("Isla", "Remota"), ("Volcan", "Activo"), ("Selva", "Verde"),
]
tipos_produccion = ["LP", "EP", "SENCILLO"]

albumes = []
album_artista = {}
album_disquera = {}
for idx, (w1, w2) in enumerate(album_words):
    aid = idx + 1
    artista = artistas[idx // 3]  # 3 albumes por artista
    artist_id = artista[0]
    label_id = artista[4]
    albumes.append((
        aid,
        "%s %s" % (w1, w2),
        2019 + (idx % 8),
        tipos_produccion[idx % 3],
        "/img/album_%02d.jpg" % aid,
        artist_id,
        label_id,
    ))
    album_artista[aid] = artist_id
    album_disquera[aid] = label_id

song_a = ["Luz", "Sombra", "Fuego", "Agua", "Viento", "Tierra", "Cielo", "Mar",
          "Rio", "Noche", "Dia", "Alba", "Eco", "Pulso", "Ritmo", "Voz",
          "Sueno", "Camino", "Puerta", "Espejo", "Cristal", "Metal", "Madera",
          "Papel", "Color", "Brillo", "Rayo", "Tormenta", "Calma", "Ruido"]
song_b = ["Lejano", "Eterno", "Fugaz", "Azul", "Rojo", "Dorado", "Plateado",
          "Salvaje", "Tranquilo", "Electrico", "Acustico", "Nocturno", "Solar",
          "Frio", "Caliente", "Suave", "Duro", "Lento", "Rapido", "Libre",
          "Preso", "Abierto", "Cerrado", "Alto", "Bajo", "Nuevo", "Viejo",
          "Real", "Virtual", "Infinito"]

titulos_usados = set()
canciones = []
cancion_album = {}
cancion_artista_principal = {}
cancion_duracion = {}
cancion_artista_rows = []
cancion_genero_rows = []
song_id = 1

for album in albumes:
    album_id = album[0]
    artist_id = album[5]
    num_songs = 7 if album_id <= 20 else 6
    for pista in range(1, num_songs + 1):
        base = "%s %s" % (random.choice(song_a), random.choice(song_b))
        titulo = base
        n = 2
        while titulo in titulos_usados:
            titulo = "%s %s" % (base, "II" * n)
            n += 1
        titulos_usados.add(titulo)

        duracion = random.randint(120, 360)
        proveedor = random.choices(
            ["PROPIO", "JAMENDO", "AUDIUS"], weights=[60, 25, 15]
        )[0]
        if proveedor == "PROPIO":
            ruta = "/audio/propio/cancion_%03d.mp3" % song_id
            externo = "own-%03d" % song_id
        elif proveedor == "JAMENDO":
            ruta = "https://cdn.jamendo.com/track/%03d.mp3" % song_id
            externo = "jam-%03d" % song_id
        else:
            ruta = "https://cdn.audius.co/track/%03d.mp3" % song_id
            externo = "aud-%03d" % song_id

        canciones.append((
            song_id,
            titulo,
            pista,
            duracion,
            ruta,
            random.random() < 0.10,
            album_id,
            proveedor,
            externo,
        ))
        cancion_album[song_id] = album_id
        cancion_artista_principal[song_id] = artist_id
        cancion_duracion[song_id] = duracion

        cancion_artista_rows.append((song_id, artist_id, "PRINCIPAL"))
        genero_principal = genero_id[artistas[artist_id - 4][2]]
        cancion_genero_rows.append((song_id, genero_principal))
        if random.random() < 0.40:
            secundario = random.choice(
                [g for g in range(1, 9) if g != genero_principal]
            )
            cancion_genero_rows.append((song_id, secundario))

        # Colaboraciones: una cada 8 canciones
        if song_id % 8 == 0:
            feat = random.choice(
                [a[0] for a in artistas if a[0] != artist_id]
            )
            cancion_artista_rows.append((song_id, feat, "FEATURING"))

        song_id += 1

assert len(canciones) == 200, len(canciones)

# ---------------------------------------------------------------------------
# Playlists (20)
# ---------------------------------------------------------------------------
playlist_temas = [
    "Road trip", "Estudio", "Fiesta", "Relax", "Gym", "Noche", "Lluvia",
    "Cocina", "Viaje", "Foco", "Domingo", "Verano", "Invierno", "Concierto",
    "Retro", "Indie", "Urbano", "Acustico", "Electronico", "Jazz",
]

playlists = []
playlist_owner = {}
playlist_cancion_rows = []
playlist_songs = {}
playlists_by_song = {}
playlist_creacion = {}
all_song_ids = [c[0] for c in canciones]

for i, tema in enumerate(playlist_temas):
    pid = i + 1
    owner = random.choice(oyentes)["id"]
    creacion = rand_date(date(2025, 6, 1), date(2026, 10, 31))
    publica = pid <= 14
    playlists.append((
        pid,
        owner,
        "%s %02d" % (tema, pid),
        tema,
        creacion,
        publica,
    ))
    playlist_owner[pid] = owner
    playlist_creacion[pid] = creacion

    n_songs = random.randint(5, 15)
    selected = random.sample(all_song_ids, n_songs)
    playlist_songs[pid] = set(selected)
    for orden, sid in enumerate(selected, start=1):
        fecha_add = creacion + timedelta(days=random.randint(0, 30))
        if fecha_add > date(2026, 11, 25):
            fecha_add = date(2026, 11, 25)
        playlist_cancion_rows.append((pid, sid, orden, fecha_add))
        playlists_by_song.setdefault(sid, []).append(pid)

# Seguidores de playlists publicas
playlist_seguidor_rows = []
seguidores_objetivo = {1: 10, 2: 8, 3: 6, 4: 5, 5: 4}
for pl in playlists:
    pid = pl[0]
    publica = pl[5]
    if not publica:
        continue
    objetivo = seguidores_objetivo.get(pid, random.randint(0, 3))
    candidatos = [o["id"] for o in oyentes if o["id"] != playlist_owner[pid]]
    random.shuffle(candidatos)
    for uid in candidatos[:objetivo]:
        fecha = playlist_creacion[pid] + timedelta(days=random.randint(0, 60))
        if fecha > date(2026, 11, 25):
            fecha = date(2026, 11, 25)
        playlist_seguidor_rows.append((pid, uid, fecha))

# ---------------------------------------------------------------------------
# Suscripciones
# ---------------------------------------------------------------------------
suscripciones = []
sid = 1
for i, o in enumerate(oyentes):
    reg = o["registro"]
    if i in premium_vigente:
        inicio_premium = rand_date(date(2026, 6, 1), date(2026, 9, 1))
        fin_gratis = inicio_premium - timedelta(days=1)
        suscripciones.append((sid, o["id"], 1, reg, fin_gratis, "VENCIDA")); sid += 1
        suscripciones.append((sid, o["id"], 2, inicio_premium, None, "ACTIVA")); sid += 1
    elif i in premium_pasado:
        inicio_premium = rand_date(date(2025, 8, 1), date(2025, 12, 1))
        fin_premium = rand_date(date(2026, 2, 1), date(2026, 6, 1))
        fin_gratis = inicio_premium - timedelta(days=1)
        suscripciones.append((sid, o["id"], 1, reg, fin_gratis, "VENCIDA")); sid += 1
        suscripciones.append((sid, o["id"], 2, inicio_premium, fin_premium, "CANCELADA")); sid += 1
        suscripciones.append((sid, o["id"], 1, fin_premium + timedelta(days=1), None, "ACTIVA")); sid += 1
    else:
        suscripciones.append((sid, o["id"], 1, reg, None, "ACTIVA")); sid += 1

# ---------------------------------------------------------------------------
# Reproducciones (5000)
# ---------------------------------------------------------------------------
artist_weights = {
    4: 20, 6: 15, 9: 13, 8: 10, 10: 9, 5: 8, 13: 7, 7: 6, 11: 6, 12: 6,
}
weighted_artists = []
for aid, w in artist_weights.items():
    weighted_artists.extend([aid] * w)

songs_by_artist = {}
for c in canciones:
    songs_by_artist.setdefault(cancion_artista_principal[c[0]], []).append(c[0])

users_by_country = {}
for o in oyentes:
    users_by_country.setdefault(o["pais"], []).append(o["id"])

countries = list(users_by_country.keys())
assert len(countries) == 12

playlists_by_owner = {}
for pid, owner in playlist_owner.items():
    playlists_by_owner.setdefault(owner, []).append(pid)

plays = []
seen = set()


def add_play(uid, sid, when, seconds, origin=None, playlist_id=None):
    key = (uid, sid, when)
    while key in seen:
        when = when + timedelta(seconds=1)
        key = (uid, sid, when)
    seen.add(key)
    plays.append({
        "uid": uid,
        "sid": sid,
        "when": when,
        "seconds": seconds,
        "device": random.choice(["Android", "iOS", "Web", "Desktop", "Smart TV"]),
        "origin": origin,
        "playlist": playlist_id,
    })


def pick_origin(uid, sid):
    origin = random.choices(
        ["PLAYLIST", "RECOMENDACION", "BUSQUEDA", "ALBUM", "OTRO"],
        weights=[40, 25, 15, 10, 10],
    )[0]
    if origin != "PLAYLIST":
        return origin, None
    candidates = playlists_by_song.get(sid, [])
    if not candidates:
        return "BUSQUEDA", None
    propias = [p for p in candidates if playlist_owner[p] == uid]
    if propias and random.random() < 0.5:
        return "PLAYLIST", random.choice(propias)
    return "PLAYLIST", random.choice(candidates)


def pick_track(uid):
    """25% de las reproducciones salen de una playlist propia (si existe)."""
    if uid in playlists_by_owner and random.random() < 0.25:
        pid = random.choice(playlists_by_owner[uid])
        sid = random.choice(list(playlist_songs[pid]))
        return sid, "PLAYLIST", pid
    aid = random.choice(weighted_artists)
    sid = random.choice(songs_by_artist[aid])
    origin, pid = pick_origin(uid, sid)
    return sid, origin, pid


# 3 usuarios gratuitos con 600 reproducciones en un solo mes (>20 horas).
# Se usan meses anteriores a la ventana sep-oct de la consulta P8 para no
# distorsionar la comparacion mes a mes.
power_plan = [
    (oyentes[power_free[0]]["id"], datetime(2026, 6, 1), datetime(2026, 6, 30, 23, 59, 59)),
    (oyentes[power_free[1]]["id"], datetime(2026, 7, 1), datetime(2026, 7, 31, 23, 59, 59)),
    (oyentes[power_free[2]]["id"], datetime(2026, 8, 1), datetime(2026, 8, 31, 23, 59, 59)),
]
for uid, start, end in power_plan:
    for _ in range(600):
        sid, origin, pid = pick_track(uid)
        when = rand_dt(start, end)
        segundos = random.randint(int(cancion_duracion[sid] * 0.6), cancion_duracion[sid])
        add_play(uid, sid, when, segundos, origin, pid)

# 3200 reproducciones balanceadas por pais
last60_start = datetime(2026, 9, 26, 0, 0, 0)
last60_end = datetime(2026, 11, 25, 23, 59, 59)
prev_start = datetime(2025, 11, 26, 0, 0, 0)
prev_end = datetime(2026, 9, 25, 23, 59, 59)

for i in range(3200):
    pais = countries[i % len(countries)]
    uid = random.choice(users_by_country[pais])
    sid, origin, pid = pick_track(uid)
    if random.random() < 0.45:
        when = rand_dt(last60_start, last60_end)
    else:
        when = rand_dt(prev_start, prev_end)
    segundos = random.randint(30, cancion_duracion[sid])
    add_play(uid, sid, when, segundos, origin, pid)

assert len(plays) == 5000, len(plays)

# Canción previa por usuario (RF-6 / RF-7)
plays.sort(key=lambda p: (p["uid"], p["when"]))
previous_song = {}
for p in plays:
    p["prev"] = previous_song.get(p["uid"])
    previous_song[p["uid"]] = p["sid"]

# ---------------------------------------------------------------------------
# Calificaciones, favoritos
# ---------------------------------------------------------------------------
plays_by_user = {}
for p in plays:
    plays_by_user.setdefault(p["uid"], []).append(p)

calificaciones = []
favorito_cancion_rows = []
favorito_album_rows = []
favorito_artista_rows = []

for o in oyentes:
    uid = o["id"]
    user_plays = plays_by_user.get(uid, [])
    distinct_songs = list({p["sid"] for p in user_plays})
    random.shuffle(distinct_songs)

    # Calificaciones: entre 20 y 50 canciones escuchadas
    n_cal = min(len(distinct_songs), random.randint(20, 50))
    for sid in distinct_songs[:n_cal]:
        play_dates = [p["when"].date() for p in user_plays if p["sid"] == sid]
        base_date = min(play_dates)
        fecha = base_date + timedelta(days=random.randint(0, 7))
        if fecha > date(2026, 11, 25):
            fecha = date(2026, 11, 25)
        valor = random.choices([1, 2, 3, 4, 5], weights=[5, 10, 20, 30, 35])[0]
        calificaciones.append((uid, sid, valor, fecha))

    # Favoritos: canciones, albumes y artistas escuchados
    n_fc = min(len(distinct_songs), random.randint(5, 15))
    for sid in distinct_songs[:n_fc]:
        fecha = rand_date(date(2025, 11, 26), date(2026, 11, 25))
        favorito_cancion_rows.append((uid, sid, fecha))

    albums = list({cancion_album[p["sid"]] for p in user_plays})
    random.shuffle(albums)
    for aid in albums[:min(len(albums), random.randint(2, 5))]:
        fecha = rand_date(date(2025, 11, 26), date(2026, 11, 25))
        favorito_album_rows.append((uid, aid, fecha))

    artists = list({cancion_artista_principal[p["sid"]] for p in user_plays})
    random.shuffle(artists)
    for aid in artists[:min(len(artists), random.randint(2, 5))]:
        fecha = rand_date(date(2025, 11, 26), date(2026, 11, 25))
        favorito_artista_rows.append((uid, aid, fecha))

# ---------------------------------------------------------------------------
# Escritura del archivo SQL
# ---------------------------------------------------------------------------
usuario_rows = []
for d in disqueras:
    uid, razon, nit, pais, correo = d
    usuario_rows.append((
        uid, q("admin@%s.demo" % razon.lower().replace(" ", "")),
        q("disquera_%02d" % uid), q("hash_demo_%03d" % uid),
        qd(date(2024, 1, 1)), q(pais), q("DISQUERA"), "TRUE",
    ))
for a in artistas:
    uid, nombre, genero, pais, label, tipo, reg = a
    usuario_rows.append((
        uid, q("%s@demo.com" % nombre.lower().replace(" ", ".")),
        q(nombre.lower().replace(" ", "_")), q("hash_demo_%03d" % uid),
        qd(reg), q(pais), q("ARTISTA"), "TRUE",
    ))
for o in oyentes:
    usuario_rows.append((
        o["id"], q(o["correo"]), q(o["usuario"]), q("hash_demo_%03d" % o["id"]),
        qd(o["registro"]), q(o["pais"]), q("OYENTE"), "TRUE",
    ))

disquera_rows = []
for d in disqueras:
    uid, razon, nit, pais, correo = d
    disquera_rows.append((uid, q(nit), q(razon), q(pais), q(correo)))

artista_rows = []
for a in artistas:
    uid, nombre, genero, pais, label, tipo, reg = a
    artista_rows.append((
        uid, q(nombre), q("Biografia de %s" % nombre), q(tipo), q(pais),
    ))

oyente_rows = []
for o in oyentes:
    oyente_rows.append((o["id"], q(o["apodo"]), qd(o["nacimiento"])))

album_rows = []
for a in albumes:
    album_rows.append((
        a[0], q(a[1]), a[2], q(a[3]), q(a[4]), a[5], lit(a[6]),
    ))

cancion_rows = []
for c in canciones:
    cancion_rows.append((
        c[0], q(c[1]), lit(c[2]), c[3], q(c[4]), "TRUE" if c[5] else "FALSE",
        lit(c[6]), q(c[7]), q(c[8]),
    ))

playlist_rows = []
for p in playlists:
    playlist_rows.append((
        p[0], p[1], q(p[2]), q(p[3]), qd(p[4]), "TRUE" if p[5] else "FALSE",
    ))

contrato_rows = []
for c in contratos:
    contrato_rows.append((
        c[0], c[1], c[2], qd(c[3]), qd(c[4]), c[5], q(c[6]),
    ))

suscripcion_rows = []
for s in suscripciones:
    suscripcion_rows.append((
        s[0], s[1], s[2], qd(s[3]), qd(s[4]), q(s[5]),
    ))

reproduccion_rows = []
for p in plays:
    reproduccion_rows.append((
        p["uid"], p["sid"], qt(p["when"]), p["seconds"],
        q(p["device"]), lit(p["prev"]), q(p["origin"]), lit(p["playlist"]),
    ))

calificacion_rows = [
    (c[0], c[1], c[2], qd(c[3])) for c in calificaciones
]
favorito_cancion_rows_sql = [(r[0], r[1], qd(r[2])) for r in favorito_cancion_rows]
favorito_album_rows_sql = [(r[0], r[1], qd(r[2])) for r in favorito_album_rows]
favorito_artista_rows_sql = [(r[0], r[1], qd(r[2])) for r in favorito_artista_rows]

playlist_cancion_rows_sql = [
    (r[0], r[1], r[2], qd(r[3])) for r in playlist_cancion_rows
]
playlist_seguidor_rows_sql = [
    (r[0], r[1], qd(r[2])) for r in playlist_seguidor_rows
]
cancion_artista_rows_sql = [(r[0], r[1], q(r[2])) for r in cancion_artista_rows]
cancion_genero_rows_sql = cancion_genero_rows

header = """-- ============================================================================
-- Proyecto : Hell Music
-- Archivo  : 04_seed.sql
-- Contenido: Datos de prueba reproducibles (generado por tools/generar_seed.py)
-- Motor    : MySQL 8.0+ / MariaDB 10.5+
-- Resumen  : 3 disqueras, 10 artistas, 30 oyentes, 30 albumes, 200 canciones,
--            20 playlists, 5000 reproducciones, 12 meses de historia.
-- Nota     : Ejecutar despues de 01_schema.sql.
-- ============================================================================

"""

parts = [header]
parts.append("-- Planes\n" + block(
    "plan", ["id_plan", "nombre_plan", "precio_mensual"],
    [(p[0], q(p[1]), p[2]) for p in planes]))
parts.append("-- Generos\n" + block(
    "genero", ["id_genero", "nombre_genero", "descripcion"],
    [(g[0], q(g[1]), q(g[2])) for g in generos]))
parts.append("-- Usuarios (3 disqueras + 10 artistas + 30 oyentes)\n" + block(
    "usuario",
    ["id_usuario", "correo", "nombre_usuario", "contrasena_hash",
     "fecha_registro", "pais", "tipo_usuario", "activo"],
    usuario_rows))
parts.append("-- Disqueras\n" + block(
    "disquera",
    ["id_usuario", "nit", "razon_social", "pais_sede", "correo_contacto"],
    disquera_rows))
parts.append("-- Artistas\n" + block(
    "artista",
    ["id_usuario", "nombre_artistico", "biografia", "tipo_artista", "pais_origen"],
    artista_rows))
parts.append("-- Oyentes\n" + block(
    "oyente",
    ["id_usuario", "apodo_publico", "fecha_nacimiento"],
    oyente_rows))
parts.append("-- Contratos de derechos\n" + block(
    "contrato_derechos",
    ["id_contrato", "id_artista", "id_disquera", "fecha_inicio", "fecha_fin",
     "porcentaje_regalias", "estado_contrato"],
    contrato_rows))
parts.append("-- Albumes\n" + block(
    "album",
    ["id_album", "titulo_album", "anio_lanzamiento", "tipo_produccion",
     "portada_url", "id_artista", "id_disquera"],
    album_rows))
parts.append("-- Canciones\n" + block(
    "cancion",
    ["id_cancion", "titulo_cancion", "num_pista", "duracion_segundos",
     "ruta_archivo_audio", "es_explicita", "id_album", "proveedor", "id_externo"],
    cancion_rows))
parts.append("-- Cancion-Artista\n" + block(
    "cancion_artista",
    ["id_cancion", "id_artista", "rol"],
    cancion_artista_rows_sql))
parts.append("-- Cancion-Genero\n" + block(
    "cancion_genero",
    ["id_cancion", "id_genero"],
    cancion_genero_rows_sql))
parts.append("-- Playlists\n" + block(
    "playlist",
    ["id_playlist", "id_oyente", "nombre_playlist", "tematica",
     "fecha_creacion", "es_publica"],
    playlist_rows))
parts.append("-- Playlist-Cancion\n" + block(
    "playlist_cancion",
    ["id_playlist", "id_cancion", "orden", "fecha_agregado"],
    playlist_cancion_rows_sql))
parts.append("-- Playlist-Seguidor\n" + block(
    "playlist_seguidor",
    ["id_playlist", "id_oyente", "fecha_seguimiento"],
    playlist_seguidor_rows_sql))
parts.append("-- Suscripciones\n" + block(
    "suscripcion",
    ["id_suscripcion", "id_usuario", "id_plan", "fecha_inicio", "fecha_fin", "estado"],
    suscripcion_rows))
parts.append("-- Calificaciones\n" + block(
    "calificacion",
    ["id_oyente", "id_cancion", "valor", "fecha_calificacion"],
    calificacion_rows))
parts.append("-- Favoritos: canciones\n" + block(
    "favorito_cancion",
    ["id_oyente", "id_cancion", "fecha_marcado"],
    favorito_cancion_rows_sql))
parts.append("-- Favoritos: albumes\n" + block(
    "favorito_album",
    ["id_oyente", "id_album", "fecha_marcado"],
    favorito_album_rows_sql))
parts.append("-- Favoritos: artistas\n" + block(
    "favorito_artista",
    ["id_oyente", "id_artista", "fecha_marcado"],
    favorito_artista_rows_sql))
parts.append("-- Reproducciones (5000)\n" + block(
    "reproduccion",
    ["id_oyente", "id_cancion", "fecha_hora_reproduccion",
     "segundos_escuchados", "dispositivo", "id_cancion_previa",
     "origen", "id_playlist_origen"],
    reproduccion_rows, batch=100))

with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n\n".join(parts))

print("Archivo generado:", OUT)
print("usuarios:", len(usuario_rows))
print("oyentes:", len(oyente_rows))
print("artistas:", len(artista_rows))
print("disqueras:", len(disquera_rows))
print("contratos:", len(contrato_rows))
print("albumes:", len(album_rows))
print("canciones:", len(cancion_rows))
print("cancion_artista:", len(cancion_artista_rows_sql))
print("cancion_genero:", len(cancion_genero_rows_sql))
print("playlists:", len(playlist_rows))
print("playlist_cancion:", len(playlist_cancion_rows_sql))
print("playlist_seguidor:", len(playlist_seguidor_rows_sql))
print("suscripciones:", len(suscripcion_rows))
print("calificaciones:", len(calificacion_rows))
print("favorito_cancion:", len(favorito_cancion_rows_sql))
print("favorito_album:", len(favorito_album_rows_sql))
print("favorito_artista:", len(favorito_artista_rows_sql))
print("reproducciones:", len(reproduccion_rows))
