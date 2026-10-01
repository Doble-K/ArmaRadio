# Diseño — Emisoras FM/AM para Live Radio

> **Estado: propuesta futura.** Este documento describe dirección y diseño
> conceptual; no representa funciones implementadas en la versión actual.

Este documento describe la dirección funcional de Live Radio como sistema de
emisoras FM/AM dentro del modelo de radio de TFAR Standalone. No define todavía
una implementación concreta ni modifica el comportamiento actual del mod.

## Idea central

Live Radio no será solamente un reproductor de música. Será el motor de una
emisora de radio completa, con programación continua y recepción degradable
dentro del mundo de Arma.

El contenido de la emisora puede incluir:

- Música.
- Locutores generados con IA.
- Noticias e informes.
- Propaganda.
- Mensajes de campaña.
- Avisos de emergencia.
- Separadores y programación continua.
- Transmisiones especiales relacionadas con eventos del mundo.

El stream de Internet es el medio de distribución del programa. Dentro del
juego, el jugador percibe ese contenido como una emisión FM o AM que se
sintoniza y se recibe mediante una radio.

```text
programación de la emisora
        ↓
stream de Live Radio
        ↓
emisión FM/AM dentro del mundo
        ↓
radio receptora
```

## Estado v1 y evolución prevista

La v1 valida la parte audible del sistema: un stream de Live Radio se reproduce
localmente mediante OpenAL y su volumen, filtrado, estática e interferencia se
modifican según los datos disponibles del receptor. La integración con TFAR es
opcional y no transporta el audio por el canal de voz.

La siguiente evolución será representar la emisión mediante un objeto de radio
dentro del mundo. Ese objeto será el transmisor de una emisora y definirá, como
mínimo:

- Banda: FM o AM.
- Frecuencia e identidad de la emisora.
- Potencia y alcance base.
- Facción, propietario o estado de captura.
- Stream o programación que debe emitir.
- Disponibilidad y reglas de la misión.

La señal podrá cubrir todo el mapa cuando la misión configure una emisora de
gran alcance. La cobertura no implica enviar audio por red: cada cliente seguirá
reproduciendo localmente el stream y calculará la calidad de recepción de su
receptor con respecto al transmisor.

Los objetos enemigos, jammers y otras fuentes de interferencia afectarán a la
recepción local. Podrán:

- Reducir progresivamente la calidad de una emisora.
- Añadir estática y filtrado.
- Reducir el alcance efectivo.
- Bloquear una frecuencia o banda.
- Afectar solamente a una zona del mapa.

El modelo futuro debe mantener separadas estas responsabilidades:

```text
emisora/objeto transmisor
        ↓ frecuencia, banda, potencia y cobertura
receptor del jugador o vehículo
        ↓ distancia, terreno y jammers locales
calidad de señal
        ↓
mezclador OpenAL local
```

La v1 no representa todavía una topología de transmisores ni una propagación
física completa. Es la base del receptor y del mezclador sobre la que se podrá
añadir ese modelo sin cambiar el transporte de audio.

## Modos de integración

Live Radio mantiene tres modos mutuamente excluyentes. TFAR no se desactiva por
seleccionar uno de los modos TFAR; lo que cambia es el backend que utiliza Live
Radio para interpretar y reproducir la señal.

- `Legacy`: funciona sin TFAR y utiliza el backend actual de Live Radio.
- `TFAR actual`: utiliza TFAR como proveedor de degradación de recepción y
  conserva el backend estable de Live Radio.
- `TFAR Realtime`: utiliza el adaptador TFAR Realtime y está reservado para el
  backend nativo de baja latencia que se está portando.

El PBO `live_radio_tfar_realtime` registra la capacidad del tercer modo. Si TFAR
o ese PBO no están disponibles, la selección cae de forma segura a `Legacy` o a
`TFAR actual`, respectivamente. Hasta completar el backend nativo, `TFAR
Realtime` mantiene la ruta estable para permitir pruebas de selección sin
duplicar audio.

## Relación con TFAR Standalone

TFAR Standalone proporciona el entorno de radio que ya conocen los jugadores:

- Frecuencias.
- Radios de corto y largo alcance.
- Radios de vehículos.
- Posición del emisor y del receptor.
- Alcance.
- Terreno y antena.
- Interferencia.
- Degradación y recuperación de la señal.

Live Radio proporciona el contenido de la emisora:

- Música.
- Locutores.
- Informes.
- Propaganda.
- Programación dinámica.

La emisora musical no debe convertirse en una conversación de voz de TFAR ni
enviar su audio mediante el servidor de voz. La música se reproduce localmente
en cada cliente, pero su recepción debe respetar el modelo de radio del juego.

```text
TFAR: entorno de transmisión y recepción
Live Radio: contenido y reproducción de la emisora
La misión: reglas de disponibilidad, cobertura y programación
```

## Adaptador TFAR futuro

La integración con TFAR debe ser opcional y vivir en un adaptador separado del
núcleo, por ejemplo `live_radio_tfar.pbo`:

```text
Live Radio Core
|-- streams y decoder
|-- OpenAL y mezcla local
|-- interferencia y señal
`-- API de receptores

Live Radio TFAR Adapter
|-- radios SW/LR/vehículo
|-- frecuencia y potencia
|-- modo auricular/altavoz
`-- traducción a receptor Live Radio
```

El adaptador debe leer la frecuencia y el estado del receptor TFAR, pero el
audio de la emisora debe continuar reproduciéndose localmente mediante OpenAL.
No se debe transmitir música mediante el canal de voz de TFAR.

Una estación puede declararse mediante un perfil del servidor:

```json
{
  "id": "resistance_fm",
  "name": "Resistance FM",
  "frequency": 88.5,
  "url": "https://example.org/radio.mp3",
  "receivers": ["SW", "LR", "vehicle"]
}
```

La misión o el jugador deberían sintonizar la frecuencia. El adaptador no debe
cambiarla automáticamente. La frecuencia es la identidad de recepción; el
stream, los filtros, la estática y la mezcla siguen siendo responsabilidad de
Live Radio.

## Simulación FM y AM

FM y AM son perfiles de emisión y recepción dentro del juego. No se pretende
simular componentes físicos de hardware, sino el comportamiento de una señal
FM o AM cuando el receptor se aleja, encuentra obstáculos o sufre interferencia.

### Perfil FM

Una emisora FM puede representar:

- Sonido limpio mientras la señal es suficiente.
- Buena calidad dentro del área de cobertura.
- Caída más marcada al acercarse al límite.
- Ruido y distorsión cerca del umbral.
- Recuperación reconocible al volver a una zona de buena recepción.
- Pérdida de calidad o estéreo antes de perder completamente la señal, si la
  misión utiliza esa regla.

### Perfil AM

Una emisora AM puede representar:

- Alcance y comportamiento diferentes a FM.
- Degradación más progresiva.
- Ruido de fondo persistente.
- Estática más evidente.
- Recepción parcial durante más tiempo.
- Mayor sensibilidad a interferencias configuradas por la misión.

Las diferencias entre FM y AM deben ser audibles y jugables. No son solamente
etiquetas de frecuencia.

## Experiencia del jugador

El jugador encuentra o utiliza una radio compatible y sintoniza una frecuencia.
La emisión puede encontrarse en distintos estados:

- Música limpia.
- Locutor en directo.
- Informe de situación.
- Señal débil.
- Interferencia.
- Transmisión incompleta.
- Silencio.
- Otra emisora en la misma banda.
- Emisión de emergencia.

La radio también funciona como una señal de orientación. El jugador puede
inferir su situación sin consultar siempre una interfaz:

- Una señal limpia indica buena recepción.
- Una señal débil indica mala cobertura.
- Una transmisión cortada indica interferencia o pérdida de señal.
- Un informe nuevo indica que la emisora tiene información actualizada.
- La ausencia de señal puede indicar distancia, bloqueo o una estación fuera de
  servicio.

La respuesta fuera de cobertura no debe ser única para todas las misiones. Puede
configurarse para mantener música degradada, emitir estática, perder solamente
los informes, cambiar a otra emisora o cortar completamente la señal.

## Emisora de resistencia

Antistasi es el primer contexto de uso previsto, pero la emisora de resistencia
no debe quedar codificada dentro del núcleo de Live Radio.

La emisora puede transmitir:

- Estado de la resistencia.
- Territorios recuperados.
- Ataques recientes.
- Objetivos y operaciones.
- Convoyes y movimientos enemigos.
- Pérdidas y avisos.
- Mensajes de campaña.
- Música y propaganda.

El contenido puede cambiar según el estado real de la misión. La información
puede ser incompleta, retrasarse, interrumpirse o mejorar conforme la red de la
resistencia progresa.

El progreso de la misión puede afectar a:

- Disponibilidad de la emisora.
- Calidad de recepción.
- Alcance.
- Contenido de los informes.
- Acceso a nuevas frecuencias.
- Interferencia enemiga.
- Programación disponible.

Estas reglas pertenecen al adaptador de Antistasi, no al núcleo universal de
Live Radio.

## Repetidoras y torres

La red de radio puede usar repetidoras construidas y torres capturadas. La
misión decide qué significa cada una:

- Ampliar el área de cobertura.
- Mejorar la calidad.
- Recuperar una emisora bloqueada.
- Habilitar informes nuevos.
- Reducir interferencia.
- Habilitar una frecuencia.
- Mantener una emisión en una zona concreta.

También pueden existir torres enemigas o jammers que reduzcan la recepción,
introduzcan interferencia o bloqueen determinados contenidos.

El núcleo de Live Radio debe poder recibir el resultado de estas reglas sin
conocer la lógica específica de Antistasi.

## Otras emisoras

La emisora de resistencia es solamente el primer caso de uso. El mismo sistema
debe permitir:

- Emisoras enemigas.
- Emisoras civiles.
- Radios capturadas.
- Propaganda.
- Programas musicales de otras facciones.
- Emisiones militares.
- Mensajes de misión.
- Emisiones falsas o señuelos.
- Cassettes o programas pregrabados.

Una misión puede hacer que estas emisoras sean globales, locales, sintonizables,
capturables o dependientes de una zona.

## Transmisiones de voz

Una emisora puede tener una capacidad opcional de anuncio público. Un operador
autorizado puede hablar a través de la estación y llegar a los receptores
sintonizados.

Esto es una transmisión de una estación hacia muchos oyentes, no una
conversación entre dos radios. La programación puede pausarse, reducirse o
quedar de fondo durante el anuncio y continuar después.

La misión decide si la capacidad existe y quién puede utilizarla. No forma parte
del requisito mínimo para reproducir música y programación grabada.

## Separación de responsabilidades

### Núcleo de Live Radio

- Reproduce streams y programación.
- Administra emisoras.
- Mantiene el audio local por cliente.
- Aplica los perfiles audibles FM y AM.
- Procesa degradación, estática, filtros y recuperación.
- Funciona sin TFAR.

### Integración con TFAR Standalone

- Hace que la emisora pueda utilizar el entorno de radios de TFAR.
- Permite sintonización y recepción mediante radios compatibles.
- Reutiliza el modelo de alcance e interferencia de la simulación de radio.
- Permite extender la compatibilidad a vehículos, objetos, mochilas y radios
  portátiles.
- No convierte la música en voz ni exige transportar el stream mediante el
  servidor de voz.

### Adaptador de misión

- Define las emisoras disponibles.
- Define frecuencias y bandas.
- Define cobertura y disponibilidad.
- Conecta la programación con los eventos de la misión.
- Decide el efecto de torres, repetidoras y jammers.
- Puede generar informes dinámicos.

## Dirección del proyecto

La dirección no es crear una radio específica y rígida para Antistasi. Es crear
un sistema de emisoras FM/AM que pueda ser utilizado por Antistasi y por otras
misiones.

Antistasi será el primer lugar donde la radio tenga una función narrativa fuerte:
acompañar el avance, comunicar información y reflejar el control del territorio.

El núcleo, sin embargo, debe seguir siendo una radio por streaming reutilizable
en cualquier servidor.

> Live Radio será una plataforma de emisoras FM/AM con música, locutores,
> información y programación dinámica, integrada al modelo de recepción de TFAR
> Standalone y configurable por cada misión.
