# Roadmap — Live Radio

Plan de mejoras para ir implementando de a pasos, ordenado por **urgencia y simpleza** (P0 = más fácil/urgente → P3 = futuro lejano). Ningún cambio de código todavía.

Los items están pensados como mejoras genéricas para contribuir al repo original (PRs upstream). Se mantienen los nombres originales del mod y los streams default no se tocan.

## P0 — Quick wins (fácil + urgente, sin tocar Rust)

### Config básica

- [x] **Volumen default 30%** — slider `[0.1, 1, 0.5, 2, true]` → `[0.1, 1, 0.3, 2, true]` en `addons/manager/XEH_preInit.sqf`. El rango sigue permitiendo llegar a 100%.
  - Nota: hoy el DLL arranca en 100% y el default del slider nunca se aplica solo.
- [x] **Default "Driver and Commander Only" = true** — en `addons/interface/XEH_preInit.sqf`, cambiar el último `false` por `true` en el `CBA_fnc_addSetting` del setting.
  - Nota: todos escuchan (pasajeros y gente cerca — ya ocurre vía audio posicional). La restricción aplica solo a CONTROLAR la radio: abrirla y cambiar emisora.

### Streamer Mode

- [x] **Nuevo setting "Streamer Mode"** (`CHECKBOX`, default `false`) en `addons/manager/XEH_preInit.sqf`.
  - ON → `EXT callExtension ["source:global_gain", [0]]` (silencia todas las fuentes, incluidas nuevas).
  - OFF → restaura `GVAR(volumeMultiplier)`.
  - El handler de "Volume Multiplier" no debe pisar el mute cuando streamer mode está activo.
  - Se guarda en el perfil del jugador (`CBA_settings.sqf`) → queda configurado entre misiones.
- [x] **Re-aplicar al iniciar misión** — en `addons/manager/XEH_postInit.sqf` (bloque `hasInterface`):
  ```sqf
  private _gain = if (GVAR(streamerMode)) then { 0 } else { GVAR(volumeMultiplier) };
  EXT callExtension ["source:global_gain", [_gain]];
  ```
  El valor del setting viene del perfil; el handler `onChange` solo dispara al tocarlo en partida, por eso hay que re-aplicarlo en cada misión. Este bloque también resuelve el default 30% de la Config básica.

### Vehículos compatibles configurables (#3)

- [x] Settings CBA (globales — los maneja el servidor, los clientes no los tocan) en `addons/interface/XEH_preInit.sqf`:
  - `Enable for Cars` (clase base `Car`) — `CHECKBOX`, default `true`
  - `Enable for Armored` (clase base `Tank`) — `CHECKBOX`, default `false`
  - `Enable for Helicopters` (clase base `Helicopter`) — `CHECKBOX`, default `false`
  - `Enable for Planes` (clase base `Plane`) — `CHECKBOX`, default `false`
  - `Enable for Ships` (clase base `Ship`) — `CHECKBOX`, default `false`
  - (Opcional) `Custom vehicle classes` — array de classnames extra
- [x] Función nueva `fnc_isCompatible.sqf` (`addons/interface/functions/`): recibe vehículo → `true` si `isKindOf` alguna clase base habilitada por los settings + las custom.
- [x] `addons/interface/XEH_postInit.sqf:19`: condición de la acción de jugador → `[_vehicle] call FUNC(isCompatible)`.
- [x] `addons/interface/CfgVehicles.hpp`: `ACE_SelfActions` con `GVAR(open)` en `Car`, `Tank`, `Helicopter`, `Plane` y `Ship`; la acción se filtra por `isCompatible` para ocultarla si el checkbox está en false.
- [x] `fnc_canOpen.sqf`: se mantiene (conductor/comandante) — aplica a todas las categorías.

### Indicador de estado del stream (ONLINE/OFFLINE)

- [x] DLL: callback `stream:status` (`online`/`offline`) vía ExtensionCallback — online al recibir data, offline al terminar la decodificación (EOF/Close). Comparte señal con el ruido blanco del bug del loop (P1).
- [x] SQF: handler en `addons/manager/XEH_postInit.sqf` → `GVAR(sourcesStatus)` + refresh de UI vía `metadataUpdated`.
- [x] UI: mostrar ONLINE/OFFLINE en el panel (texto en `gui.hpp`, verde/rojo) o en el `IDC_DESCRIPTION`.

### Multilenguaje (ES/EN)

- [x] Completar keys de `stringtable.xml` (`addons/interface`, `addons/main`) en Español e Inglés.
- [x] Migrar strings hardcodeados ("Driver and Commander Only", "FM Radio", "Live Radio", acciones ACE) a `LSTRING`/`localize` — sin cambiar el texto (se mantienen los nombres originales del mod).

## P1 — Corrección + comodidad

### Bug: audio repite un segmento en loop al terminar la canción

**Síntoma**: al terminar una canción, se escucha un trozo corto repetido en bucle.

**Causa raíz probable — desync de metadatos ICY (`src/streams/read.rs`)**:
- En el límite entre canciones la estación suele mandar un bloque de metadatos ICY (`StreamTitle`). El parser lee `length = length[0] * 16` y luego `read_exact` esa cantidad (`read.rs:52-56`).
- Si el largo declarado no coincide con el bloque real, el stream de bytes queda **desalineado** → el decoder MP3 (`simplemad`) pierde sync de frames.
- Al perder sync, `simplemad` puede repetir el último frame decodificado hasta re-sincronizar → de ahí el "loop" de un segmento.
- Nota: `read.rs:65-67` tiene además recursión `if read == 0 { self.read(buf) }` que, con `icy-metaint` raro, puede caer en recursión profunda/infinita.

**Causas secundarias**:
- **Stream muere sin `Close`** (`src/streams/mod.rs`): si el stream corta (EOF entre canciones), el `for decoding_result in decoder` termina sin mandar `StreamPacket::Close`; la fuente queda registrada con `count > 0` pero el hilo murió → al volver a esa URL `Streams::listen` no reinicia el hilo.
- **Heartbeat limpia todo** (`src/lib.rs:32-48`): sin heartbeat por >3s, `source::cleanup()` vacía todas las fuentes sin limpiar `Streams`.

**Plan de fix (diagnóstico primero)**:
1. Loggear sync del decoder / frame errors en `mod.rs` para confirmar la pérdida de sync entre canciones.
2. Endurecer `read.rs`: validar largo de metadatos contra lo real, y eliminar la recursión de `read == 0`.
3. En `Stream::start`, mandar `Close`/reconexión si el decoder termina con `count > 0`.
4. Verificar el pool de buffers en `source.rs` (reuso con `buffers_processed() > 200` + reintento de `play()`).

**Comportamiento al caer el stream — ruido blanco**:
- En vez de quedar muda o repetir un segmento, el DLL debe emitir ruido blanco/estática cuando la decodificación termina (EOF entre canciones o conexión caída).
- Implementación: en `src/source.rs`, cuando `stream.receiver.try_recv()` quede en `Empty` y el hilo del stream haya muerto, generar un buffer de ruido blanco (fácil: muestras aleatorias) y seguirlo enviando hasta que llegue `Close` o data nueva.
- Aplica también si se agrega reconexión automática más adelante: ruido hasta que se restablezca.

**Otros bugs (issues del repo)**:
- **Dos streams abren si cambian rápido** (#12): race condition en `fnc_play`/`Streams::listen` (check-then-insert no atómico). Blindar con validación antes de crear la fuente/stream.
- **UI no refresca si otro jugador cambia** (#5): `updateInfo`/`handleVolume` solo corren en eventos locales (`metadataUpdated`). Broadcast del estado activo + refresh de displays abiertos al recibir cambios remotos.

### Controles rápidos ACE (sin abrir el panel)

- [x] Nuevas funciones en `addons/interface/functions/`:
  - `fnc_power.sqf` — encender/apagar (toggle), reusando `EFUNC(manager,play)`.
  - `fnc_volumeChange.sqf` — subir/bajar volumen en pasos ~0.1, límite `MIN_VOLUME`/`MAX_VOLUME` (0–2), reusando `EFUNC(manager,volume)`.
  - `fnc_stationChange.sqf` — estación anterior/siguiente navegando `GVAR(stations)`, solo si está encendida.
- [x] Registrar acciones ACE en `addons/interface/CfgVehicles.hpp`:
  - Vehículos (`ACE_SelfActions`): Encender/Apagar, Subir Volumen, Bajar Volumen, Estación Anterior, Estación Siguiente.
  - Radio estática (`Land_FMradio_F` en `ACE_Actions`).
- [x] Agregar las mismas acciones al fallback sin ACE en `addons/interface/XEH_postInit.sqf` (cuando no está cargado `ace_interaction`).

### Rango de sonido configurable (#17)

- [x] Setting CBA "Sound Range" (metros).
- [x] En `fnc_tick`: fuente fuera del rango → `source:gain 0`; dentro del rango → volumen normal.

## P2 — Gameplay / inmersión

### Apagado automático

- [x] Handler server-only (perFrame) en `addons/manager/XEH_postInit.sqf`:
  - Por cada radio activa, si ningún jugador está a < R metros durante T segundos → `[_object, ""] call EFUNC(manager,play)` (apaga para todos).
  - R y T como settings CBA (defaults propuestos: 30 m / 120 s).

### Interferencia / distorsión según daño

- [x] **Rust** (`src/source.rs`): nuevo comando `source:quality` y `SoundCommand::SetQuality`.
  - Al recibir `StreamPacket::Data`, si `quality > 0`: mezclar ruido blanco y atenuar amplitud proporcionalmente.
  - Barato por muestra; `quality` en `[0, 1]`.
- [x] **SQF** (`addons/manager/functions/fnc_tick.sqf`): por cada fuente, enviar
  `quality = linearConversion [0, 1, getDammage _object, 0, 1]` → `EXT callExtension ["source:quality", ...]`.
  - Afecta a todos los jugadores por igual (el daño del vehículo es compartido).
- [ ] (Opcional) Interferencia por distancia del jugador a la radio, además del daño.
- [x] **Interferencia ambiental** (extiende el daño): sumar distorsión por eventos ambientales cercanos:
  - Tormentas / lluvia intensa / rayos
  - Explosiones recientes
  - ECM/jammer (si la misión lo usa)
  - El SQF combina daño + eventos ambientales en un factor único → `source:quality`.

### Volumen baja con ACE hearing / tinnitus (#11) — futuro cercano

- [ ] El DLL usa su propio contexto OpenAL, separado del audio del juego → no baja con tinnitus/tapones.
- [x] Hook: leer el volumen de hearing de ACE (módulo `ace_hearing`) y multiplicar `global_gain` (igual que `volumeMultiplier`).
- [x] Nota: verificar en implementación la API exacta de ACE (setting/evento de hearing).

## P1 — Bugs detectados en prueba en partida (14/8/2026)

### Controles rápidos ACE: volumen y estación no funcionan

- [x] **Causa raíz**: en `addons/interface/CfgVehicles.hpp`, las statements usaban `QUOTE(ARR_2(_target,0.1) call FUNC(volumeChange))`. El macro CBA `ARR_2` expande a `ARG1, ARG2` **sin corchetes**, generando `_target, 0.1 call ...` en el config compilado → `fnc_volumeChange` recibía `0.1` como primer argumento (`Error getvariable: Tipo Número` en el RPT). `open`/`power` sí funcionaban porque usan `[_target]` literal.
- [x] **Fix**: statements reescritas con corchetes explícitos: `QUOTE([_target, 0.1] call FUNC(volumeChange))` etc.
- [ ] **Verificación pendiente**: probar en partida que Vol+/Vol-/Next/Prev funcionan desde el menú ACE.

### Ruido raro en el audio (desync del decoder MP3)

- [x] **Síntoma**: ruido/estática rara al reproducir ciertas estaciones (ej. `listen.classicrock109.com`). En el RPT: decenas de `Mad(LostSync)`, `Mad(BadHuffData)`, `Mad(BadScFSI)`, `Mad(BadLayer)` por segundo — `simplemad` pierde sync de frames (desync ICY, mismo bug P1 original).
- [x] **Fix parcial (Rust)**: en `src/streams/mod.rs`, contar errores de decode consecutivos; al superar 50, marcar el stream offline (`active=false`) y cortar el loop para que la fuente emita estática controlada en vez de audio corrupto.
- [ ] **Pendiente de decisión**: la estación default `ClassicRock109` parece caída/rota. Decidir si se reemplaza, se quita, o se mantiene (roadmap original decía "no tocar streams default").

### Click de encendido/apagado molesto

- [x] El `EXT callExtension ["click", []]` en `fnc_power.sqf` y `fnc_handlePower.sqf` suena siempre al prender/apagar.
- [x] **Fix**: nuevo setting CBA `playClickSound` (CHECKBOX, default `false`) en `addons/manager/XEH_preInit.sqf`; los clicks solo suenan si está activo.

### Stream offline que no reporta estado

- [x] **Síntoma**: un stream caído/roto quedaba "mudo" sin indicar ONLINE/OFFLINE en el panel.
- [x] **Causa raíz**: `source.rs` solo emitía `status=offline` si previamente había estado online (`if online`); un stream que moría antes de mandar data nunca reportaba.
- [x] **Fix (Rust)**: flag `reported` — reporta `offline` la primera vez aunque nunca haya estado online, y `online` al recibir data.

## P3 — Futuro medio/lejano

### Sonido de encendido/apagado

- [x] Click/estática corta al prender y al apagar la radio.
  - Implementación: clip de audio embebido reproducido por el DLL (ya decodifica MP3 con `simplemad`) o asset SQF.

### Control en Zeus

- [x] Permitir al curador (Zeus) encender/apagar radios de unidades de IA y vehículos.
- [x] `fnc_tick` ya detecta `_inZeus` (cámara del curador) — reusar para posicionar fuentes.
- [x] Módulo Zeus o interacción ACE para seleccionar unidad/vehículo y togglear power (reusa `EFUNC(manager,play)`).

### Radios de mano y mochila radio

- [ ] No todas las radios: solo radios de mano (item) y mochilas radio (container).
- [ ] La "fuente" pasa a ser la unidad que la lleva (el audio sigue posicional con `getPosASL` en `fnc_tick`).
- [ ] Encender/apagar en la unidad (acción ACE / keybind), reusando la lógica de `GVAR(sources)`.
- [ ] Nota: la mochila es un objeto persistente en el mundo (posicionable); el radio de mano requiere trackear la unidad que lo tiene.

### Volumen por vehículo (persistencia en perfil)

- [ ] Ya funciona durante la sesión: `addons/manager/functions/fnc_volume.sqf` guarda `QGVAR(volume)` en el objeto con `setVariable ... true` (red); el panel lo lee al abrir (`fnc_open.sqf`).
- [ ] (Opcional) Persistencia entre misiones: guardar volumen por clase de vehículo en el perfil. Complejo — puede pisar volúmenes entre vehículos iguales. Pendiente de definir.

## Dudas / decisiones abiertas

- Interferencia ambiental: ¿qué eventos exactos (tormenta, explosiones, ECM)?
- Apagado automático: confirmar valores R/T o dejarlos como settings.
- Volumen persistente: ¿solo por sesión (comportamiento actual) o guardado en perfil?
- #16 (32-bit): DESCARTADO — Arma 3 dejó de dar soporte.
- #14 (playlists M3U8/AAC): a futuro, no factible por ahora (requiere decoder nuevo).
- **Radios de mano/mochila** (futuro lejano, prioridad baja): usar el mismo sistema del mod (audio posicional propio) con radios de mano y mochilas radio como fuente — sin integrar TFAR/ACRE. Los que estén cerca escuchan la FM posicional, igual que con vehículos. Pendiente de definir items concretos y alcance; no se toca por ahora.
