# Puntos bloqueados / pendientes de definición

Registro de puntos del `roadmap.md` que quedaron sin completar en la sesión de trabajo del 14/8/2026, con el motivo y qué se necesita para resolverlos.

## P2 — Apagado automático — DESHABILITADO por bug de apagado espontáneo

- **Estado**: DESHABILITADO (defaults `autoOffRange = 0`, `autoOffTime = 0`; el guard del handler lo apaga). El código y los settings se mantienen.
- **Síntoma**: la radio se apagó sola estando el jugador al lado del vehículo (2 reportes), incluida al bajarse del vehículo. Con el mod original no pasaba.
- **Causa probable**: `allUnits select { isPlayer _x }` puede venir vacío/sin el jugador en hosted (respawn/transición) → `_near` nunca `true` → el contador de `autoOffTime` (120 s) se dispara indebidamente. El commit `6988716` habilitó la feature en hosted (`isServer` sin `!hasInterface`), que es donde juega el usuario.
- **Qué se necesita para resolver**:
  1. Diagnóstico con logging temporal (`count _players`, distancia, valores de settings) antes del apagado.
  2. Probar fixes: inicializar `GVAR(autoOffLastSeen)` en el evento `start`; no contar hasta el primer "near"; usar `allPlayers`; saltar el vehículo del propio jugador.
- **Nota**: no se sigue ahora — documentado a pedido del usuario (14/8/2026).


## P2 — Interferencia ambiental por explosiones — nota

- **Estado**: COMPLETADO con fix de `addMissionEventHandler ["Explosion"]` → object handlers.
- **Problema original**: `addMissionEventHandler ["Explosion", ...]` en `addons/manager/XEH_postInit.sqf` lanzaba `Error externo: Unknown enum value: "Explosion"` en partida (Arma 3 v2.22). `Explosion` NO es un mission event handler; solo existe como object/unit event handler (`_objeto addEventHandler ["Explosion", ...]`). El lint de HEMTT (`L-S02IC`) tenía razón.
- **Fix aplicado**: se anclan `addEventHandler ["Explosion"]` sobre la unidad y el vehículo del jugador vía per-frame (re-ancla en respawn/cambio de vehículo), escribiendo `GVAR(lastExplosion) = time`.
- **Limitación**: solo detecta explosiones que dañan la unidad o el vehículo del jugador. No detecta explosiones cercanas que no lo tocan.
- **Para mejorarlo (futuro)**: detección por distancia con polling de `nearObjects` (radio configurable, más costoso por frame), o revisar si una versión futura de Arma 3 agrega `Explosion` como mission event handler.


## P2.2 (opcional) — Interferencia por distancia del jugador a la radio

- **Qué se intentó**: la interferencia por distancia era un sub-item "(Opcional)" del punto de interferencia por daño. Se implementó la interferencia por daño (`source:quality`) y la ambiental (lluvia + explosiones cercanas).
- **Por qué quedó sin hacer**: la atenuación por distancia ya la maneja OpenAL (modelo de distancia) y el setting nuevo `Sound Range` (P1.3) silencia por completo las fuentes fuera del radio. Sumar más interferencia por distancia sería redundante/contradictorio con el corte duro del rango de sonido.
- **Qué se necesita**: decisión de diseño sobre si se quiere una transición suave (estática progresiva) en vez del corte duro del `Sound Range`.

## P2 — ACE hearing / tinnitus (#11) — nota

- **Estado**: COMPLETADO (hook de `ace_hearing_volume` × `ace_hearing_volumeAttenuation` en `fnc_applyGain.sqf`).
- La nota del roadmap sobre "verificar la API exacta de ACE" se resolvió leyendo el código fuente de ACE3: el estado de tapones está en `ACE_hasEarPlugsIn` (variable de unidad) y los factores en `ace_hearing_volume` / `ace_hearing_volumeAttenuation` (missionNamespace).

## P3.3 — Radios de mano y mochila radio

- **Qué se intentó**: nada (explícitamente deferido por el roadmap: "no se toca por ahora").
- **Por qué quedó bloqueado**: requiere rediseñar el sistema de fuentes (trackear unidades que llevan el radio, mochilas posicionables). Alcance no definido.
- **Qué se necesita**: definición de items concretos y alcance antes de implementar.

## P3.4 — Volumen por vehículo (persistencia en perfil)

- **Qué se intentó**: nada. El roadmap lo marca como "(Opcional) ... Complejo — puede pisar volúmenes entre vehículos iguales. Pendiente de definir."
- **Por qué quedó bloqueado**: la persistencia por clase de vehículo en el perfil puede pisar volúmenes entre vehículos de la misma clase; comportamiento actual (por sesión) está documentado y funciona.
- **Qué se necesita**: decisión de diseño (persistir por clase, por objeto único, o mantener solo por sesión).

## P3.2 — Control en Zeus

- **Estado**: COMPLETADO (módulo Zeus `ModuleToggleRadio` + acciones `ACE_ZeusActions` con toggle de power).
- **Nota de verificación**: la estructura de `ACE_ZeusActions` fue verificada contra el fuente de ACE3/ZEN: se compila desde la clase raíz `configFile >> "ACE_ZeusActions"` con submenús como subclases directas (NO dentro de `CfgVehicles`, NO envuelto en `ACE_MainActions`). La implementación final quedó en `addons/interface/CfgZeusActions.hpp` a nivel root. Igual conviene verificar visualmente en partida con ACE cargado.
