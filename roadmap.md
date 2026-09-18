# Roadmap — Live Radio

Plan de mejoras para ir implementando de a pasos, ordenadas de **simple → complejo**. Cada tarea = **un commit**. Un agente las hace de a una y commitea al terminar cada una. Todo lo que es **backend/decoder queda al final (Fase 3) y NO se implementa por ahora** — solo se documenta para poder re-integrarlo después.

Los items están pensados como mejoras genéricas para contribuir al repo original (PRs upstream). Se mantienen los nombres originales del mod y los streams default no se tocan.

## Fase 1 — Tareas simples (SQF/UI/Config, sin tocar Rust) — 1 commit por tarea

### Completado — Config básica

- [x] **Volumen default 30%** — slider `[0.1, 1, 0.5, 2, true]` → `[0.1, 1, 0.3, 2, true]` en `addons/manager/XEH_preInit.sqf`. El rango sigue permitiendo llegar a 100%.
  - Nota: hoy el DLL arranca en 100% y el default del slider nunca se aplica solo.
- [x] **Default "Driver and Commander Only" = true** — en `addons/interface/XEH_preInit.sqf`, cambiar el último `false` por `true` en el `CBA_fnc_addSetting` del setting.
  - Nota: todos escuchan (pasajeros y gente cerca — ya ocurre vía audio posicional). La restricción aplica solo a CONTROLAR la radio: abrirla y cambiar emisora.

### Completado — Streamer Mode

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

### Completado — Vehículos compatibles configurables (#3)

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

### Completado — Indicador de estado del stream (ONLINE/OFFLINE)

- [x] DLL: callback `stream:status` (`online`/`offline`) vía ExtensionCallback — online al recibir data, offline al terminar la decodificación (EOF/Close). Comparte señal con el ruido blanco del bug del loop (Fase 3).
- [x] SQF: handler en `addons/manager/XEH_postInit.sqf` → `GVAR(sourcesStatus)` + refresh de UI vía `metadataUpdated`.
- [x] UI: mostrar ONLINE/OFFLINE en el panel (texto en `gui.hpp`, verde/rojo) o en el `IDC_DESCRIPTION`.

### Completado — Multilenguaje (ES/EN)

- [x] Completar keys de `stringtable.xml` (`addons/interface`, `addons/main`) en Español e Inglés.
- [x] Migrar strings hardcodeados ("Driver and Commander Only", "FM Radio", "Live Radio", acciones ACE) a `LSTRING`/`localize` — sin cambiar el texto (se mantienen los nombres originales del mod).

### Completado — Controles rápidos ACE (sin abrir el panel)

- [x] Nuevas funciones en `addons/interface/functions/`:
  - `fnc_power.sqf` — encender/apagar (toggle), reusando `EFUNC(manager,play)`.
  - `fnc_volumeChange.sqf` — subir/bajar volumen en pasos ~0.1, límite `MIN_VOLUME`/`MAX_VOLUME` (0–2), reusando `EFUNC(manager,volume)`.
  - `fnc_stationChange.sqf` — estación anterior/siguiente navegando `GVAR(stations)`, solo si está encendida.
- [x] Registrar acciones ACE en `addons/interface/CfgVehicles.hpp`:
  - Vehículos (`ACE_SelfActions`): Encender/Apagar, Subir Volumen, Bajar Volumen, Estación Anterior, Estación Siguiente.
  - Radio estática (`Land_FMradio_F` en `ACE_Actions`).
- [x] Agregar las mismas acciones al fallback sin ACE en `addons/interface/XEH_postInit.sqf` (cuando no está cargado `ace_interaction`).

### Completado — Rango de sonido configurable (#17)

- [x] Setting CBA "Sound Range" (metros).
- [x] En `fnc_tick`: fuente fuera del rango → `source:gain 0`; dentro del rango → volumen normal.
- (Relacionado) La interferencia por torres de radio (ver Fase 2) también sirve como indicador audible de estar en rango de una torre.

### Completado — Click de encendido/apagado molesto

- [x] El `EXT callExtension ["click", []]` en `fnc_power.sqf` y `fnc_handlePower.sqf` suena siempre al prender/apagar.
- [x] **Fix**: nuevo setting CBA `playClickSound` (CHECKBOX, default `false`) en `addons/manager/XEH_preInit.sqf`; los clicks solo suenan si está activo.

### Completado — Stream offline que no reporta estado

- [x] **Síntoma**: un stream caído/roto quedaba "mudo" sin indicar ONLINE/OFFLINE en el panel.
- [x] **Causa raíz**: `source.rs` solo emitía `status=offline` si previamente había estado online (`if online`); un stream que moría antes de mandar data nunca reportaba.
- [x] **Fix (Rust)**: flag `reported` — reporta `offline` la primera vez aunque nunca haya estado online, y `online` al recibir data.

### Completado — Controles rápidos ACE: volumen y estación no funcionan

- [x] **Causa raíz**: en `addons/interface/CfgVehicles.hpp`, las statements usaban `QUOTE(ARR_2(_target,0.1) call FUNC(volumeChange))`. El macro CBA `ARR_2` expande a `ARG1, ARG2` **sin corchetes**, generando `_target, 0.1 call ...` en el config compilado → `fnc_volumeChange` recibía `0.1` como primer argumento (`Error getvariable: Tipo Número` en el RPT). `open`/`power` sí funcionaban porque usan `[_target]` literal.
- [x] **Fix**: statements reescritas con corchetes explícitos: `QUOTE([_target, 0.1] call FUNC(volumeChange))` etc.

### Completado — Interferencia / distorsión según daño

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

### Completado — Volumen baja con ACE hearing / tinnitus (#11)

- [ ] El DLL usa su propio contexto OpenAL, separado del audio del juego → no baja con tinnitus/tapones.
- [x] Hook: leer el volumen de hearing de ACE (módulo `ace_hearing`) y multiplicar `global_gain` (igual que `volumeMultiplier`).
- [x] Nota: verificar en implementación la API exacta de ACE (setting/evento de hearing).

### Completado — Sonido de encendido/apagado

- [x] Click/estática corta al prender y al apagar la radio.
  - Implementación: clip de audio embebido reproducido por el DLL (ya decodifica MP3 con `simplemad`) o asset SQF.

### Completado — Control en Zeus

- [x] Permitir al curador (Zeus) encender/apagar radios de unidades de IA y vehículos.
- [x] `fnc_tick` ya detecta `_inZeus` (cámara del curador) — reusar para posicionar fuentes.
- [x] Módulo Zeus o interacción ACE para seleccionar unidad/vehículo y togglear power (reusa `EFUNC(manager,play)`).

### Tarea — Verificar en partida que los controles ACE funcionan

- [ ] Probar en partida que Vol+/Vol-/Next/Prev funcionan desde el menú ACE.

### Tarea — Menú ACE siempre visible y rotura configurable

- [ ] El menú ACE debe verse siempre en radios compatibles, estén quemadas o no.
- [ ] `burned` no debe ocultar el menú padre ni bloquear la apertura del panel.
- [ ] La rotura pasa a ser opcional por settings CBA: toggle maestro para desactivar rotura y toggles por causa (agua, daño, interferencia radio/clima/EMP).
- [ ] Las acciones normales quedan protegidas solo por guards internos; `Repair` debe seguir restaurando la radio y limpiar `burned`.

### Completado (commit `3c3a90c`) — Rotura dura desactivada por defecto

- [x] **Setting CBA `enableBurn`** (`CHECKBOX`, default `false`) en `addons/manager/XEH_preInit.sqf`.
- [x] **Settings CBA `burnByWater` / `burnByDamage`** (`CHECKBOX`, default `false`) en `addons/manager/XEH_preInit.sqf`.
- [x] `fnc_burn.sqf` respeta el master switch y los toggles por causa; si `enableBurn` está off, limpia `underwaterFactor` / `underwaterSince` y no marca `burned`.
- [x] El feedback de audio/estética por `quality` se mantiene intacto; no se tocó `fnc_tick.sqf`.

#### Tarea 2 — UI cuando la radio está `burned` (documentación de diseño)

- **Opción A, mínima y segura**: dejar `fnc_open.sqf`, `fnc_refresh.sqf` y `fnc_handlePower.sqf` como están; solo reforzar `fnc_repair.sqf` limpiando `underwaterSince`.
- **Opción B, UI más permisiva**: habilitar `Power` aunque esté `burned` y mover el guard a `fnc_handlePower.sqf`.
- **Opción C, feedback extra sin cambiar flujo**: mantener `Power` deshabilitado y confiar en `fnc_updateInfo.sqf` para mostrar `Radio damaged / not responding`.
- **Opción D, split explícito UI/ejecución**: separar visualización de acciones y ejecución interna; el menú siempre visible, pero los controles se regulan por guards internos en cada acción.
- **Recomendación aplicada**: Opción A, por ser la implementación mínima y de menor riesgo; fue la base del cambio en `cc71c23`.

### Completado (commit `3d505fc`) — Emisoras configurables sin hardcoded

- [x] **Setting CBA `customStations`** (`EDITBOX` en Addon Options, patrón de `customVehicleClasses`): array SQF de `[nombre, url]`, con las 3 emisoras actuales como valor por defecto editables desde la ventana de opciones.
- [x] **Fuentes combinadas**: `customStations` (principal) + `configFile`/`campaignConfigFile`/`missionConfigFile` (`CfgRadioStations`, ya soportado) → `GVAR(stations)`, con **deduplicación por URL**.
- [x] **Fallback**: si `customStations` está vacío o no parsea → las 3 hardcoded de `CfgRadioStations.hpp` (se mantienen como fallback, ya no como fuente inmutable).
- [x] **Formato**: array SQF vía `parseSimpleArray` (nativo, sin parser JSON); documentar en el tooltip.
- [ ] **Bulk (futuro)**: la ventana de opciones no escala para 50 emisoras cómodamente; listo como decisión abierta para un formato archivo/JSON de importación.

### Tarea — Apagado automático (DESHABILITADO; revisar fixes candidatos)

- [x] Handler server-only (perFrame) en `addons/manager/XEH_postInit.sqf`:
  - Por cada radio activa, si ningún jugador está a < R metros durante T segundos → `[_object, ""] call EFUNC(manager,play)` (apaga para todos).
  - R y T como settings CBA (defaults propuestos: 30 m / 120 s).
- [x] **DESHABILITADO (14/8/2026)** — reporte de apagado espontáneo en partida (ver "BUG: se apaga sola" abajo).
  - Se desactiva sin retirar el código: defaults `autoOffRange = 0` y `autoOffTime = 0` (el guard `if (GVAR(autoOffRange) <= 0 || GVAR(autoOffTime) <= 0) exitWith {}` la apaga).
  - Decisión: documentar todo y NO seguir ahora (pendiente de diagnóstico).

#### BUG: la radio se apaga sola estando al lado del vehículo / al bajarse

- **Síntoma (2 reportes)**: la radio se apagó sola estando el jugador al lado del vehículo, y se volvió a apagar al bajarse del vehículo. Antes (mod original) no pasaba.
- **Feature responsable**: auto power off (este punto), habilitada también en hosted por el commit `6988716` (cambió `isServer && !hasInterface` → `isServer`). El usuario juega en hosted/single player.
- **Hipótesis de causa** (sin confirmar):
  - `allUnits select { isPlayer _x }` puede venir vacío o sin el jugador en momentos de transición/respawn → `_near` nunca `true` → el contador de `autoOffTime` se dispara indebidamente.
  - `GVAR(autoOffLastSeen)` se inicializa con `time` en el primer check y no se refresca si `_players` está vacío.
  - El cambio de hosted (`6988716`) hizo que la feature corra en el contexto donde el usuario juega.
- **Cómo diagnosticar** (cuando se retome):
  - Logging temporal en el bloque: `diag_log` con `count _players`, distancia jugador→objeto, y valores de `autoOffRange`/`autoOffTime`/`autoOffLastSeen` antes de disparar el apagado.
  - Reproducir con `autoOffRange` alto (ej. 500) para confirmar que el conteo se dispara indebidamente.
- **Fixes candidatos a probar** (cuando se retome):
  - Inicializar `GVAR(autoOffLastSeen)` en el momento de encender la radio (evento `start`/`fnc_play`) en vez del default `time` del primer check.
  - No iniciar el conteo hasta que al menos un jugador haya estado cerca una vez (flag).
  - Usar `allPlayers` en vez de `allUnits select { isPlayer _x }`.
  - Excluir del apagado el vehículo donde está el propio jugador (`if (_object == vehicle player) exitWith {}` en el host).
- **Estado**: DESHABILITADO (defaults 0), documentado, pendiente de diagnóstico.

## Fase 2 — Gameplay (SQF, sin tocar Rust)

### Completado (commits `f5a54c5`, `7d08513`) — Interferencia por torres de radio (TFAR/Antistasi)

- [x] **Detección genérica y configurable**: setting CBA `interferenceTowers` con array de classnames (default `Land_Communication_F`, que cubre las torres vanilla y las de TFAR). Se detectan vía `nearestObjects`/`inAreaArray` con radio configurable (default 1000m, como el `JAM_RADIUS` de Antistasi).
- [x] **Filtro por bando (opcional, desactivado por default)**: setting `interferenceTowerSideFilter`. ON → solo torres de bando ENEMIGO al jugador jamean (lee el lado de la torre vía `getVariable`/`getSide`/`sidesX` de Antistasi si está disponible); OFF → cualquier torre del array genera interferencia (más genérico, funciona en cualquier misión).
- [x] **Fórmula** (reusa la de Antistasi `fn_radioJam.sqf`): `towerFactor = strength * (1 - _dist / _radius)`, donde `strength` ≈ 0.5–1 configurable. Se **suma al factor `quality`** existente en `fnc_tick.sqf` (junto a daño + lluvia + explosiones) → `EXT callExtension ["source:quality", ...]`.
- [x] **Rust**: sin cambios — `src/source.rs` ya mezcla ruido blanco/atenuación según `quality`.
- [x] **Performance**: recolección de torres con throttle (ej. cada 2–5s en vez de cada frame) cacheando el array de torres cercanas.
- [x] **Feedback de rango**: también es una forma de "saber que estás en rango de la torre" (la estática sube al acercarte) — cubre la idea del usuario.

### Completado (commit `6ec231e`) — Compatibilidad con Crows-Electronic-Warfare (Radio Jammer)

- [x] **Detección primaria — leer el jamMap de Crows-EW**: `missionNamespace getVariable ["crowsew_main_jamMap", createHashMap]` (hashmap `netId → [_unit, _radFalloff, _radEffective, _enabled, _capabilities]`). En `fnc_tick.sqf`, por cada fuente activa, si el jugador está dentro de un jammer activo con capability `"VoiceCommsJammer"` (`JAM_CAPABILITY_RADIO`), calcular la interferencia con la misma fórmula del mod y sumarla al factor `quality` → `EXT callExtension ["source:quality", ...]` (el DLL ya mezcla estática/cortes).
- [x] **Compatibilidad genérica (fallback)**: si Crows-EW no está cargado (`crowsew_main_jamMap` nil), leer `player getVariable ["tf_receivingDistanceMultiplicator", 1]` — cubre Antistasi (`fn_radioJam.sqf`) y cualquier otro jammer que use las variables TFAR. `rx > 1` → sumar factor proporcional.
- [x] **Inmunidad Zeus**: respetar `crowsew_main_zeus_jam_immune`; si el jugador es Zeus con inmunidad, no se aplica interferencia.
- [x] **Fórmula idéntica a Crows-EW** (`fnc_applyInterferenceTFAR.sqf`): dentro de `_radEffective` → `quality ≈ 1` (máxima estática); en el falloff (`_radFalloff`) → `lerp` lineal de intensidad por distancia: `distPercent = abs(dist - radEffective)/radFalloff` → interferencia decreciente.
- [x] **Alcance: por fuente** — el `quality` es del objeto (todos los que escuchan esa radio sufren el jammeo, coherente con el daño del vehículo). Nota en decisiones abiertas: el jammer físico solo jammea al jugador; con alcance por fuente todos lo escuchan.
- [x] **Rust**: sin cambios — `source:quality` ya mezcla estática y cortes.
- [x] **Performance**: iterar solo jammers activos dentro de `_radFalloff + _radEffective` del jugador (normalmente 0–2); el `jamMap` es un hashmap barato de leer por frame.
- [ ] **Relación con "la radio se quema"**: un jammer sostenido dentro de `_radEffective` puede quemar la radio (reusa el bloque de quemado/reparación con ingeniero + kit). — **Requiere decisión**: definir cuántos segundos es "sostenido" (valor default ambiguo) antes de implementar.

### Completado (commit `db72927`) — La radio "se quema" (inmersión o daño al vehículo) y se repara con ingeniero

- [x] **Detección de inmersión**: vehículo sumergido si `getPosASLW _object` tiene `z < 0`.
- [x] **Detección por daño al vehículo**: estado "quemada" cuando `getDammage _object` supera un umbral (setting CBA `radioBurnDamage`, default propuesto ~0.8–1) — hoy el daño solo genera estática (`fnc_tick.sqf:42`), nunca corta.
- [x] **Setting CBA `underwaterBurnTime`** (segundos, sin default fijo, definido al implementar): tiempo de inmersión antes de que la radio se queme.
- [x] **Fase 1 — Estática/cortes progresivos** (ambas causas): sumar factor creciente al `quality` existente en `fnc_tick.sqf` → `EXT callExtension ["source:quality", ...]`. A más daño o más tiempo sumergido, más estática y cortes.
- [x] **Fase 2 — "Se quema"**: al superar el límite (tiempo bajo el agua O daño del vehículo), la radio deja de funcionar (`source:destroy` + apagado). Persistente en el objeto hasta repararla.
- [x] **Reset parcial**: si sale del agua antes de quemarse, el factor decae gradualmente. (El daño del vehículo se quema y queda hasta reparar.)
- [x] **Reparación** — acción ACE nueva en `RADIO_QUICK_ACTIONS` (`addons/interface/CfgVehicles.hpp`) y fallback sin ACE (`addons/interface/XEH_postInit.sqf`):
  - Condición: estado "quemada" + `ace_repair` con ingeniero (`ace_isEngineer`/`isEngineer` > 0) y kit de herramientas (ACE `ACE_ToolBox` o vanilla `ToolKit`).
  - Al reparar: delay de reparación, restaura la radio (reinicia la fuente con la estación guardada), limpia la variable de "quemada".
  - Reparar la radio NO repara el vehículo: si el daño sigue sobre el umbral, se vuelve a quemar.
- [x] **Rust**: sin cambios — estática vía `source:quality`; `source:destroy`/`source:new` ya existen.
- [x] **Performance**: temporizador/estado por objeto en `fnc_tick` (solo fuentes activas).
  - Nota: `radioBurnDamage` default 0.8 y `underwaterBurnTime` default 10s (valores elegidos en implementación; configurables vía settings).

### Completado (commits `2d3b166`, `ef10758`) — Integración con ZEN (Zeus Enhanced) — referencia de Crows-EW

ZEN es el framework Zeus que Crows-EW usa como base y es dependencia de ese mod. Nuestro control Zeus actual es vanilla (`moduleToggleRadio`) + acciones `ACE_ZeusActions`; ZEN aporta la API moderna para integrar la radio en el flujo del curador.

- [x] **Registrar módulos ZEN custom** (`zen_custom_modules_fnc_register`, patrón de Crows-EW `fnc_zeusRegister.sqf`): módulos para toggle de power, volumen y estación en el menú Zeus de ZEN.
  - Check de presencia: `isClass (configFile >> "CfgPatches" >> "zen_custom_modules")` (mismo patrón que Crows-EW y que nuestro check de `ace_hearing`).
- [x] **Context menu de ZEN** (`zen_context_menu_fnc_addAction` / `fnc_createAction`): acciones de click-derecho sobre objetos/IA (Encender/Apagar, Vol+, Vol-, Estación +/-), con condiciones dinámicas (`_hoveredEntity` compatible), igual que el jammer de Crows-EW.
- [x] **Diálogos ZEN** (`zen_dialog_fnc_create`): configurar estación/volumen de la radio desde un diálogo de Zeus al colocar el módulo.
- [x] **Reutilizar** `EFUNC(manager,play)`/`FUNC(power)`/`FUNC(volumeChange)`/`FUNC(stationChange)` — la lógica ya existe; ZEN solo cambia la superficie de interacción.
- [x] **Relación Crows-EW**: con ZEN integrado, el curador puede combinar nuestro control de radio con los jammer de Crows-EW en el mismo menú (ambos mods cargados).
- [ ] **Verificación (pendiente, en partida)**: comprobar si `moduleToggleRadio` (módulo vanilla) opera correctamente con ZEN cargado, y si las `ACE_ZeusActions` actuales aparecen en el context menu de ZEN (coexisten ACE y ZEN — verificar solapamiento/duplicados). Documentar conflictos en `BLOQUEADOS.md` si los hay.

### Radios de mano y mochila radio

- [ ] No todas las radios: solo radios de mano (item) y mochilas radio (container).
- [ ] La "fuente" pasa a ser la unidad que la lleva (el audio sigue posicional con `getPosASL` en `fnc_tick`).
- [ ] Encender/apagar en la unidad (acción ACE / keybind), reusando la lógica de `GVAR(sources)`.
- [ ] Nota: la mochila es un objeto persistente en el mundo (posicionable); el radio de mano requiere trackear la unidad que lo tiene.

### Volumen por vehículo (persistencia en perfil)

- [ ] Ya funciona durante la sesión: `addons/manager/functions/fnc_volume.sqf` guarda `QGVAR(volume)` en el objeto con `setVariable ... true` (red); el panel lo lee al abrir (`fnc_open.sqf`).
- [ ] (Opcional) Persistencia entre misiones: guardar volumen por clase de vehículo en el perfil. Complejo — puede pisar volúmenes entre vehículos iguales. Pendiente de definir.

## Siguiente iteración — Tareas simples (autónomas, 1 commit cada una) — COMPLETADO

> Las 10 tareas quedaron implementadas (14/8/2026) en commits individuales. La verificación en partida es manual y futura (QA). No se tocó `src/` (Rust).

### T1 — Fix: menú ACE "FM Radio" siempre visible

- [x] Quitar la dependencia del estado `burned` en las condiciones del menú ACE (`CfgVehicles.hpp` / `fnc_canOpen.sqf`).
- [x] Criterio done: con la radio dañada el menú FM sigue apareciendo; `hemtt build` OK. Verificación en partida manual y futura.
- Nota: ya estaba satisfecho por el estado actual — las condiciones del menú ACE nunca dependieron de `burned` (implementado en `db72927`). Sin cambios → sin commit.

### T2 — Estado "Radio dañada" al abrir el panel

- [x] En `fnc_open.sqf` / `fnc_updateInfo.sqf`, si el objeto está `burned`, mostrar "Radio dañada / no responde" y deshabilitar Power visualmente.
- [x] Criterio done: al abrir el panel con radio dañada se ve el aviso; build OK. Verificación en partida manual y futura.
- Commit: `33f1af8`.

### T3 — Radio dañada ligada al daño del MOTOR

- [x] En `fnc_burn.sqf`, reemplazar el trigger genérico `getDammage` por lectura del daño del motor (`HitEngine`).
- [x] Nuevo setting CBA `radioMotorDamageThreshold` (default 0.8) en `addons/manager/XEH_preInit.sqf` + stringtable (reemplaza a `radioBurnDamage`).
- [x] Criterio done: el quemado ocurre solo con el motor dañado; build OK. Verificación en partida manual y futura.
- Commit: `98252d2`.

### T4 — Estática progresiva (fade)

- [x] Suavizar el factor `quality` en `fnc_tick.sqf` (interpolación temporal por `diag_deltaTime`) para que no corte de golpe ruido↔música.
- [x] Criterio done: la interferencia entra/sale gradualmente; build OK. Verificación en partida manual y futura.
- Commit: `7d3cf86`.

### T5 — Reparación de radio como item aparte + acción ACE externa

- [x] Nueva acción ACE externa "Repair Radio" en `CfgVehicles.hpp` (Car/Tank/Helicopter/Plane/Ship) que funciona desde fuera del vehículo (5 m); independiente de sanar el vehículo.
- [x] Criterio done: se puede reparar la radio parándose fuera con ingeniero + kit; build OK. Verificación en partida manual y futura.
- Commit: `3bd1bdc`.

### T6 — ZEN: módulo combinado "todas las opciones"

- [x] En `fnc_zeusRegister.sqf`, módulo único "Radio Control (All Options)" con power + volumen + estación (diálogo ZEN agrupado).
- [x] Criterio done: el módulo aparece y cambia todo junto; build OK. Verificación en partida manual y futura.
- Commit: `7059c35`.

### T7 — Volumen ACE: submenú de porcentajes (0/25/50/100)

- [x] En `CfgVehicles.hpp`, "Set Volume" como submenú con opciones fijas (0%, 25%, 50%, 100%).
- [x] El slider progresivo queda solo para hotkey (Zeus/ZEN), fuera del menú ACE y del fallback no-ACE.
- [x] Criterio done: el menú ACE muestra el submenú con los 4 porcentajes; build OK. Verificación en partida manual y futura.
- Commit: `004ac0a`.

### T8 — Pasajeros controlan si el vehículo NO tiene asiento de comandante

- [x] En `fnc_canOpen.sqf`, si `fullCrew [_object, "commander", true]` está vacío → delegar control al primer pasajero del crew.
- [x] Regla actual (sin cambio): asiento de comandante vacío → solo conductor. Excepción nueva: sin asiento de comandante → pasajero 1 (o 2, según el vehículo).
- [x] Criterio done: en autos sin asiento de comandante el pasajero 1/2 controla; build OK. Verificación en partida manual y futura.
- Commit: `16f18f4`.

### T9 — Setting "All Gunners Can Control Radio"

- [x] Setting CHECKBOX (default OFF) en `addons/interface/XEH_preInit.sqf` + stringtable (descripciones EN/ES).
- [x] Lógica en `fnc_canOpen.sqf`: gunner principal (`gunner _object`) controla solo con setting ON y clase `Tank`/`Helicopter`/`Plane`.
- [x] Door gunners (turrets secundarios) quedan excluidos.
- [x] Criterio done: gunner controla solo con setting ON y clase válida; build OK. Verificación en partida manual y futura.
- Commit: `5d6792a`.

### T10 — Tooltips de settings (implementar la tabla de descripciones)

- [x] Pasar la tabla de descripciones a `stringtable.xml` (manager + interface) como tooltips EN/ES de cada setting; stringtables ordenados con `hemtt ln sort`.
- [x] Criterio done: todos los settings muestran tooltip en Addon Options; build OK. Verificación en partida manual y futura.
- Commit: `f9aefe1`.

### Confirmaciones del tester (funcionan bien, sin cambios)

- [x] Tapones ACE / tinnitus: bajan el volumen de la radio correctamente.
- [x] Streamer Mode: silencia correctamente.
- [x] Módulos ZEN individuales: funcionan.
- [x] Interferencia ambiental (lluvia/explosiones/daño): presente y audible.

## Próxima iteración — Tareas simples pendientes del testing (1 commit cada una) — COMPLETADO

> Las 2 tareas quedaron implementadas (14/8/2026) en commits individuales. La verificación en partida es manual y futura (QA). No se tocó `src/` (Rust).

### T11 — Fix: el menú ACE "FM Radio" desaparece con la radio dañada

- [x] **Síntoma**: con la radio quemada, el menú ACE "FM Radio" desaparece para pasajeros en asientos sin control. El criterio de T1 no se cumplió en partida.
- [x] **Causa raíz**: el menú padre usa `RADIO_CONDITION` (`isCompatible && canOpen`); `canOpen` falla en asientos que no controlan, y ACE oculta el submenú entero si no queda ningún hijo visible (con radio quemada y sin ser ingeniero, `Repair` tampoco se muestra).
- [x] **Fix** en `CfgVehicles.hpp`: nueva macro `RADIO_MENU_CONDITION` = `isCompatible && (canOpen || isBurned)` para el menú padre `GVAR(menu)` y la acción `Open` (así siempre hay un hijo visible con radio dañada y se puede abrir el panel para ver el aviso de T2). `power`/`volumen`/`estación` siguen con `RADIO_CONDITION`; `Repair` con `REPAIR_CONDITION`. Se aplica también a la acción `Open` del fallback sin ACE (`XEH_postInit.sqf`).
- [x] Criterio done: con la radio dañada el menú FM aparece igual; `hemtt build` OK. Verificación en partida manual y futura.
- Commit: `97476cd`.

### T12 — Modelo de acceso por tripulación (artillero principal/copiloto vs artilleros de puerta, pasajero delantero)

- [x] **Síntomas (testing)**: en la Hilux los pasajeros 3/4 tienen acceso a la radio (debería ser solo el "pasajero 2" delantero, el de al lado del conductor); en helicópteros todos los pasajeros de cabina tienen acceso y los artilleros de torreta/puerta no.
- [x] **Regla objetivo**: driver y comandante siempre; **artillero principal / copiloto** (`gunner _object` — asiento delantero del AH-1Z, artillero del blindado) = tripulación → setting nuevo; **artilleros de puerta / torretas secundarias** (rol `turret` en `fullCrew`) → solo con "All Gunners" ON; **pasajeros / cargo / infantería** → nunca.
- [x] **Setting nuevo** `mainGunnerAndCopilotCanControl` (CHECKBOX, default ON) en `addons/interface/XEH_preInit.sqf` + stringtable EN/ES con tooltip.
- [x] **T9** `allGunnersCanControl` pasa a cubrir SOLO torretas secundarias / artilleros de puerta (default OFF); corregir su descripción (hoy dice "Door gunners stay excluded", quedó invertida).
- [x] **`fnc_canOpen.sqf`**: driver/comandante → siempre; `gunner _object` → setting nuevo; torretas secundarias → `allGunners`; sin asiento de comandante y vehículo terrestre (Car/Tank) → SOLO el pasajero delantero (el ocupante de cargo más cercano a la posición del conductor); pasajeros → `false`.
- [x] Criterio done: en la Hilux solo "pasajero 2" (delantero) controla; en helicópteros los pasajeros de cabina no controlan y los artilleros de puerta sí con la opción ON; build OK. Verificación en partida manual y futura.
- Commit: `438ab19`.

## Decisiones humanas requeridas (bloqueadas, NO son tarea del agente)

- **Apagado automático**: diagnosticar el bug de apagado espontáneo (requiere partida) antes de re-habilitarlo.
- **Verificación ACE en partida**: QA manual (controles rápidos, repair, gunner).
- **Radios de mano / mochila radio**: definir items concretos y alcance.
- **Volumen persistente por perfil**: decisión de diseño (por clase / objeto / solo sesión).
- **Integración Antistasi (curación/garage) y vehículo de reparaciones**: definir cómo detecta la radio que el vehículo fue "curado"/reparado antes de implementar.
- **Inmersión como causa de quemado**: T3 mantuvo la causa por inmersión (`underwaterBurnTime`); decidir a futuro si se conserva o se elimina.
- **Licencia del fork**: DECIDIDA (14/8/2026) — contribuciones del fork (Doble-K) bajo GPL-3.0 (`LICENSE`); código de upstream bajo MIT (`LICENSE-MIT`). Nota: el código GPL-3.0 no es mergeable en el repo MIT de upstream.

## Próxima iteración — Resynced / gameplay ampliado

Estas tareas quedan añadidas al roadmap a partir de la siguiente tanda de trabajo.
Se mantienen separadas porque las primeras son compatibles con el modelo actual,
mientras que las radios personales requieren definir una arquitectura de fuentes
y un modelo de frecuencia.

### ZEN y radios colocadas en objetos

- [x] **Módulo ZEN "Add FM Radio"**: seleccionar un objeto compatible, elegir una emisora y crear una fuente FM posicional asociada al objeto. Reutiliza `GVAR(active)`, `EFUNC(manager,play)` y la lista de emisoras actual.
- [x] **Módulo ZEN "Keep Radio On"**: marcar/desmarcar que la radio de un objeto no pueda apagarse mientras la persistencia esté habilitada.
- [x] **Setting CBA para radios persistentes**: permite o bloquea la función "Keep Radio On" desde Addon Options. El setting controla la disponibilidad y no enciende automáticamente todos los objetos.
- [ ] Definir el comportamiento al borrar, mover o reemplazar el objeto y evitar que el módulo cree fuentes duplicadas.

### Idea abierta — reparación multi-backend

La reparación de la radio debe tener un núcleo común y varias superficies de
interacción. La lógica de estado no debe depender de ACE, para que el mod siga
funcionando con ACE, sin ACE y con Advanced-ACE-Repair cargado.

- [ ] Extraer un núcleo común para `canRepairRadio` y `repairRadio`: estado
  `burned`, emisora guardada, tiempo de reparación, herramientas/repuestos y
  restauración de la fuente.
- [ ] **ACE**: adaptar la reparación al flujo de `ace_repair` cuando esté
  disponible, reutilizando sus permisos de ingeniero, herramientas, barra de
  progreso, animación, lugares de reparación y objetos reclamados/consumidos.
- [ ] **Vanilla**: mantener las acciones fallback actuales de
  `XEH_postInit.sqf`, usando exactamente el mismo núcleo de reparación.
- [ ] **Zeus vanilla**: añadir un módulo `Repair Radio` que invoque directamente
  el núcleo común sin requerir ACE.
- [ ] **Advanced-ACE-Repair**: detectar el mod opcionalmente y ofrecer una
  acción compatible con su modelo de reparación, sin convertirlo en dependencia
  obligatoria ni copiar su código o assets.
- [ ] Evitar acciones duplicadas cuando estén cargados ACE y
  Advanced-ACE-Repair al mismo tiempo.

#### Referencia autorizada — continuación de Advanced-ACE-Repair

La referencia actual para esta integración será la continuación mantenida por
UnRealxInferno:

- GitHub: `https://github.com/UnRealxInferno/Advanced-ACE-Repair`
- Fork directo de `MrFleff/Advanced-ACE-Repair`.
- Workshop de la continuación: `https://steamcommunity.com/sharedfiles/filedetails/?id=3688159183`.
- El Workshop original enlazado anteriormente (`3441837719`) aparece eliminado;
  no debe usarse como referencia de publicación actual.

El autor original indicó públicamente en el Workshop que cualquiera podía tomar
el mod desde GitHub y continuar su desarrollo. Por eso este fork se documenta
como una referencia autorizada para estudiar, adaptar y contribuir mejoras al
ecosistema de reparación ACE, manteniendo la atribución a Fleff y
UnRealxInferno. El repositorio no contiene una licencia formal declarada, así
que cualquier código o asset reutilizado debe conservar sus avisos y confirmar
el permiso correspondiente; la implementación de Live Radio seguirá siendo
propia y solo dependerá de la API de ACE.

Las correcciones relevantes del fork incluyen rutas `$PBOPREFIX$`, `MAINPREFIX`,
un error de parseo en `ALL_HITPOINTS` y compatibilidad con versiones actuales de
ACE. Su patrón `ACE_Repair` será la base para la futura acción `Repair Radio`.

> **Recomendación de implementación:** primero crear el núcleo común y probarlo
> con el fallback vanilla; después añadir el adaptador ACE y, por último, la
> integración opcional con Advanced-ACE-Repair.

### Estabilidad de streams en vehículos

- [ ] Reproducir y registrar cortes al entrar/salir de vehículos, cambiar de asiento,
  cambiar de emisora y mover el vehículo.
- [x] Corregir la carrera de `Streams::listen`: antes dos llamadas simultáneas
  podían pasar el lookup y abrir dos streams para la misma URL. Ahora lookup e
  inserción usan el mismo lock de escritura.
- [ ] Garantizar que destruir/recrear una fuente no deje vivo el hilo anterior ni
  encole audio antiguo después del cambio de emisora.
- [x] Proteger el evento `start` contra cambios rápidos: si el mismo objeto aún
  conserva una fuente anterior, se destruye antes de registrar la nueva.
- [x] Emitir `StreamPacket::Close` cuando el decoder termina por EOF, para que la
  fuente publique la transición a OFFLINE sin mantener un stream agotado en
  silencio. La reconexión automática queda separada hasta resolver el problema
  histórico de loops.
- [ ] Añadir logging de `source:new`, `source:destroy`, URL, ID y contador de
  listeners para diagnosticar el posible doble stream.

### Estática, modulación y ecualización

- [x] Separar la estática en una capa de ruido controlable por fuente, en lugar
  de mezclar ruido blanco sin estado directamente con cada muestra de música.
- [x] Añadir modulación progresiva según `quality`, con ruido suavizado,
  variación lenta de amplitud y atenuación gradual del programa.
- [x] Añadir setting global `enableStatic` en Addon Options, activado por defecto;
  al desactivarlo, el factor de calidad vuelve gradualmente a cero sin desactivar
  el volumen, el estado del stream ni la rotura dura.
- [ ] Evaluar una ecualización tipo radio FM: filtrar/agrupar el ruido por banda y
  aplicar un perfil distinto al audio degradado. No usar un recurso de audio fijo
  hasta definir si debe ser ruido blanco, hiss de FM o un recurso configurable.
- [ ] Añadir tests o una ruta de diagnóstico para comprobar que el procesamiento
  no introduce clipping, loops ni consumo excesivo de CPU.

### Radios personales

- [ ] **Handys**: detectar el item en el inventario de la unidad y reproducir la
  radio solo para el portador mediante auricular por defecto.
- [ ] Setting CBA para permitir que el handy también se escuche por altavoz.
- [ ] **Mochilas de radio larga**: detectar una mochila configurada como fuente,
  con audio posicional asociado al portador o a la mochila cuando se deja en el
  suelo.
- [ ] Definir una lista configurable de classnames de handys y mochilas; no
  asumir compatibilidad automática con TFAR o ACRE.
- [ ] Definir el modelo de frecuencia: una única FM global por equipo, una
  frecuencia por item, o frecuencias configurables por misión. La primera
  implementación debe elegir una sola opción para evitar mezclar emisoras FM
  con comunicaciones militares reales.
- [ ] Definir si las radios personales comparten estaciones con los vehículos o
  tienen un catálogo/frecuencia separado.

### Integración opcional con TFAR Standalone

El repositorio `ltsammy/task-force-radio-standalone` conserva la interfaz SQF y
los nombres de funciones de TFAR, mientras reemplaza el transporte de TeamSpeak
por una extensión propia y un servidor de voz. Se puede usar como referencia y
adaptador opcional, pero Live Radio no debe depender de su DLL ni de su servidor.

- [ ] Detectar TFAR Standalone/TFAR mediante `CfgPatches` y activar un adaptador
  solo cuando esté presente.
- [ ] Leer de TFAR los classnames y el estado de radios de mano/mochila, sin
  duplicar su transmisión de voz ni modificar su extensión.
- [ ] Usar una clave de frecuencia común para decidir qué radio personal puede
  escuchar qué emisión, manteniendo el stream FM y el audio posicional dentro de
  Live Radio.
- [ ] Definir una tabla de frecuencias de misión, con nombres opcionales como
  `COM-1`, `COM-2`, `LR-1` y `MED`, en vez de depender de URLs o nombres de
  emisoras para identificar canales militares.
- [ ] Mantener un modo autónomo cuando TFAR no esté cargado: classnames y
  frecuencias configurables desde CBA/mission config.
- [ ] No enviar audio FM a la red de voz ni intentar reemplazar el sistema PTT;
  la integración inicial solo sincroniza disponibilidad, frecuencia y salida
  por auricular/altavoz.

#### Idea abierta — FM asociada a canales TFAR

La idea preliminar es que, cuando ambos mods estén activos, una emisión de Live
Radio pueda estar asociada a una combinación de banda y frecuencia TFAR, por
ejemplo `SW 30.0` o `LR 50.0`. Al sintonizar ese canal, el jugador podría recibir
la voz de TFAR y la emisión FM de Live Radio mezcladas localmente, sin enviar la
música al servidor de voz ni convertirla en una transmisión de voz.

- [ ] Definir si la emisión FM se activa automáticamente al sintonizar el canal
  o si además requiere encender manualmente el handy/radio.
- [ ] Definir si el vínculo usa solo `SW/LR + frecuencia` o también clase de
  radio, canal, cifrado y estado de altavoz.
- [ ] Definir si la emisión es global para todos los receptores sintonizados,
  exclusiva del portador o también audible como fuente 3D en modo altavoz.
- [ ] Definir cómo se configuran las asociaciones desde la misión: CBA,
  `description.ext`, objetos concretos o una combinación de ellas.
- [ ] Investigar la API estable de TFAR Standalone para leer radios y frecuencias
  sin copiar código ni depender de su DLL.
- [ ] Mantener un modo autónomo cuando TFAR no esté cargado.

> **Estado:** concepto válido para explorar, pero todavía no es una especificación
> cerrada ni una promesa de compatibilidad. La implementación debe esperar a que
> se definan el comportamiento de sintonización, el alcance del audio y el
> formato de configuración.

## Fase 3 — Backend / decoder (ÚLTIMO paso — NO implementar por ahora)

> Todo lo de esta fase está **documentado pero NO se implementa** en esta iteración. La idea: recuperar el decoder upstream que funciona y, más adelante, re-integrar con cuidado los enhancements. Lo único que interesa recuperar es la **estática offline**, pero aplica solo cuando el stream está offline → no es prioridad; si resulta fácil de integrar, se implementa, y si no, queda pendiente.

### Historial — Bug: audio repite un segmento en loop al terminar la canción

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
- **Dos streams abren si cambian rápido** (#12): la carrera check-then-insert de
  `Streams::listen` quedó corregida usando el mismo lock de escritura para
  lookup e inserción. Sigue pendiente verificar el caso completo en partida,
  incluyendo recreación de fuentes y audio antiguo encolado.
- **UI no refresca si otro jugador cambia** (#5): `updateInfo`/`handleVolume` solo corren en eventos locales (`metadataUpdated`). Broadcast del estado activo + refresh de displays abiertos al recibir cambios remotos.

### Revertido — Ruido raro en el audio (desync del decoder MP3)

- [x] **Síntoma**: ruido/estática rara al reproducir ciertas estaciones (ej. `listen.classicrock109.com`). En el RPT: decenas de `Mad(LostSync)`, `Mad(BadHuffData)`, `Mad(BadScFSI)`, `Mad(BadLayer)` por segundo — `simplemad` pierde sync de frames (desync ICY, mismo bug original).
- [x] **Fix parcial (Rust)**: en `src/streams/mod.rs`, contar errores de decode consecutivos; al superar 50, marcar el stream offline (`active=false`) y cortar el loop para que la fuente emita estática controlada en vez de audio corrupto.
- [ ] **REVERTIDO (14/8/2026)** con el decoder a upstream `v0.9.1` (ver "Decoder Rust → upstream v0.9.1" abajo): el contador `consecutive_errors` y el flag `active` se eliminaron junto con la reconexión. Queda pendiente de re-implementar con el decoder viejo.
### Revertido — Buffer de audio y cortes por falta de datos (14/8/2026)

- [x] **Síntoma**: cortes/artefactos "de procesado" al reproducir, sobre todo con red inestable o streams que pierden frames (underrun de OpenAL).
- [x] **Causa raíz**: el relleno inicial era de solo ~2 s (`buffers_queued() > 75`); tras un underrun se esperaban otros ~2 s de silencio para re-anudar. Cada frame MP3 ≈ 26 ms.
- [x] **Fix (Rust, `src/source.rs`)** — implementado en `e329630` y **REVERTIDO** por introducir el bug de audio en loop (ver sección siguiente):
  - Pre-roll de estática: al recibir el primer frame de audio, se encola un buffer de ruido blanco de ~4 s y se inicia reproducción de inmediato — el arranque suena como "sintonizar" la FM en vez de silencio, mientras el audio real se acumula detrás.
  - Reanudación rápida: tras un underrun, se re-anuda apenas `buffers_queued() > 30` (~0.8 s) en vez de esperar 75 (~2 s).
- [x] **Decisión**: el fix se **revierte junto con el decoder** (ver "Decoder Rust → upstream v0.9.1" abajo). El buffer vuelve a `buffers_queued() > 75` (~2 s), sin pre-roll de estática. El underrun original se acepta por ahora a cambio de eliminar el loop.
- [ ] **Pendiente de re-implementar** (con cuidado, en otro momento): pre-roll de estática (~4 s) y reanudación rápida (`>30`), con sincronización fina del audio entre jugadores que escuchan la misma radio (arranque coordinado con el evento global `start`).

### Revertido — Audio en loop / "falta de información" + estática en radios offline (14/8/2026)

- **Síntoma (reportado 14/8/2026)**: el audio suena como un **loop por falta de información** (segmento repetido/cortes); el usuario dice que con el **mod original no pasaba**. Las radios offline además **siempre emiten estática**.
- **Comparación con el original** (lo que nosotros introdujimos en `src/streams/mod.rs` y `src/source.rs`):
  - Original: stream muerto → solo `sleep(16ms)`, la radio quedaba muda, **sin reconexión** ni estática.
  - Nuestro fork: **reconexión automática** (`Stream::start` con loop + `generation`), **estática offline continua** (amplitud 0.05), marcado online/offline, y **pre-roll de estática de 4 s** al arrancar (commit `e329630`).
- **Hipótesis de causa** (probable, se resuelve revirtiendo):
  - El **loop de reconexión** de `Stream::start` re-decodifica el stream desde el principio y reproduce el mismo segmento inicial → suena como loop/falta de datos.
  - La **estática offline** se mantiene mientras el stream está inactivo; si la reconexión falla y el thread muere, la fuente sigue mandando ruido blanco indefinidamente.
  - Interacción del pre-roll de 4 s con streams que vuelven rápido → mezcla estática con el inicio real.
- [x] **Decisión**: el decoder Rust vuelve a **upstream `v0.9.1`** (single-shot: conecta → decodifica → si el stream muere el thread termina). Se elimina el loop de reconexión. El buffering viejo de ~2 s al cambiar de canción queda aceptado por ahora (no molesta frente al problema de buffer del decoder nuevo).
- **Estado**: revertido, NO se sigue ahora. La reconexión y estática quedan como pendientes de re-implementar (ver abajo).

#### Decisión — Decoder Rust → upstream v0.9.1 (14/8/2026)

- [x] **Qué se revierte en `src/streams/mod.rs` y `src/streams/read.rs`** (volver al estado de la tag `v0.9.1`):
  - Loop de reconexión automática de `Stream::start` (se elimina; stream muerto → thread termina).
  - Flag `generation` (supersede de streams) y flag `active` (estática offline).
  - Contador `consecutive_errors > 50` → offline.
  - Se recupera `StreamPacket::Close` (el fork lo había eliminado).
- [x] **Qué se adapta en `src/source.rs`**:
  - Se quita el pre-roll de estática (`!started`, `PRE_ROLL_SECONDS`, `STATIC_AMPLITUDE`).
  - Se quita la reanudación rápida (`PLAY_RESTART_BUFFERS`) → vuelve `buffers_queued() > 75`.
  - Se quita la estática offline (dependía del flag `active` que upstream no tiene) → pendiente de re-integrar.
  - Se quitan usos de `stream.active`, `has_data`, `last_freq` (solo servían para la estática).
  - **Se mantienen**: calidad/interferencia por daño (`source:quality`), callback status online/offline (online al recibir data, offline vía `Close`/`Disconnected`), flag `reported`, `SoundCommand::SetQuality`.
- [x] **Qué se mantiene intacto**: `src/lib.rs` (`click`, `heartbeat`, `id`) y todo el SQF (ACE quick actions, controles Zeus, settings, UI) — no dependen del decoder.
- [ ] **Pendiente de re-implementar** (todo documentado para hacerlo "de vuelta" en otro momento):
  1. Reconexión automática de streams caídos (`Stream::start` con loop).
  2. Flag `generation` para superseder streams al cambiar rápido de emisora.
  3. Contador `consecutive_errors` para marcar offline ante streams corruptos (ej. `Mad(LostSync)` en `ClassicRock109`).
  4. **Estática offline continua** (amplitud 0.05) — requiere reintroducir un flag de "stream muerto" (`active` o equivalente) en el decoder. **Única que interesa**; solo si es fácil de integrar.
  5. Pre-roll de estática de ~4 s al arrancar (sonido de "sintonizar" FM).
  6. Reanudación rápida tras underrun (`buffers_queued() > 30` en vez de 75).
  7. Refactor de `src/streams/read.rs` (parseo ICY en `read_metadata()`) + tests unitarios (perdidos con el revert).
- **Verificación**: `cargo build` + `cargo test`.

## Dudas / decisiones abiertas

- Interferencia ambiental: ¿qué eventos exactos (tormenta, explosiones, ECM)?
- Interferencia por torres: valores default de `strength` (0.5) y radio (1000m) elegidos en implementación; filtro de bando resuelto con detección genérica de lado (`getVariable`/`getSide`) — se puede extender con la API de Antistasi (`A3A_antennaMap`/`sidesX`) si se quiere.
- Quemado de la radio: valores elegidos en implementación (`radioMotorDamageThreshold` = 0.8, `underwaterBurnTime` = 10s, reparación con ACE+ingeniero o kit vanilla). **Rediseño implementado (feedback tester 14/8/2026)**: quemado ligado solo al daño de MOTOR (`HitEngine`) con umbral configurable, estática progresiva con fade, y reparación como item aparte con acción ACE externa (T1–T5, commits `33f1af8`–`3bd1bdc`). Pendiente de decisión humana: integración Antistasi (curación/garage, vehículo de reparaciones) — ver "Decisiones humanas requeridas".
- Crows-EW: el jammer físico jammea al jugador (variables TFAR por jugador), pero `quality` es por fuente/objeto → el jammeo afecta a todos los que escuchan esa radio. Decidir si se quiere granularidad por jugador en el DLL (cambio de arquitectura) o mantener el alcance por fuente (actual). Pendiente además: duración de "jammer sostenido" para quemar la radio.
- ZEN: las acciones de radio coexisten como ACE_ZeusActions (actual) + módulos/contexto ZEN cuando está cargado. Verificar en partida que no haya solapamiento/duplicados.
- Apagado automático: confirmar valores R/T o dejarlos como settings. DESHABILITADO hasta diagnosticar el apagado espontáneo.
- Volumen persistente: ¿solo por sesión (comportamiento actual) o guardado en perfil?
- #16 (32-bit): DESCARTADO — Arma 3 dejó de dar soporte.
- #14 (playlists M3U8/AAC): a futuro, no factible por ahora (requiere decoder nuevo).
- **Radios de mano/mochila** (futuro lejano, prioridad baja): usar el mismo sistema del mod (audio posicional propio) con radios de mano y mochilas radio como fuente — sin integrar TFAR/ACRE. Los que estén cerca escuchan la FM posicional, igual que con vehículos. Pendiente de definir items concretos y alcance; no se toca por ahora.
