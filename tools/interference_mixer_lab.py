#!/usr/bin/env python3
"""Interactive stereo lab for the Live Radio interference mixer.

Run:
    python3 tools/interference_mixer_lab.py

The lab preserves two-channel program and interference audio as stereo.
The interference clips are decoded from resources/ with ffmpeg and streamed to
ALSA through aplay, so the sliders change the mix while it is playing.
"""

from __future__ import annotations

import subprocess
import threading
import time
import tkinter as tk
import queue
from pathlib import Path

import numpy as np


RATE = 44_100
BLOCK = 1024
ROOT = Path(__file__).resolve().parents[1]
RESOURCE_NAMES = (
    "Interferencia radio 1.mp3",
    "interferencia de Radio 2.mp3",
    "interferencia de Radio 3.mp3",
)


def decode_clip(path: Path) -> np.ndarray:
    result = subprocess.run(
        [
            "ffmpeg",
            "-v",
            "error",
            "-i",
            str(path),
            "-f",
            "f32le",
            "-ac",
            "2",
            "-ar",
            str(RATE),
            "pipe:1",
        ],
        check=True,
        stdout=subprocess.PIPE,
    )
    samples = np.frombuffer(result.stdout, dtype=np.float32).copy()
    samples = samples[: len(samples) - (len(samples) % 2)].reshape(-1, 2)
    peak = float(np.max(np.abs(samples), initial=0.0))
    if peak > 0.0:
        samples /= peak
    return samples


class MixerLab:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("Live Radio interference mixer lab")
        self.lock = threading.Lock()
        self.running = True
        self.phase = 0
        self.static_cursor = [0, 0, 0]
        self.program_state = np.zeros(2, dtype=np.float32)
        self.static_state = np.zeros(2, dtype=np.float32)
        self.interference_state = 0.0
        self.stream_process: subprocess.Popen[bytes] | None = None
        self.stream_queue: queue.Queue[np.ndarray] = queue.Queue(maxsize=24)
        self.stream_thread: threading.Thread | None = None
        self.clips = [decode_clip(ROOT / "resources" / name) for name in RESOURCE_NAMES]

        self.interference = tk.DoubleVar(value=1.0)
        self.program_gain = tk.DoubleVar(value=1.0)
        self.distance = tk.DoubleVar(value=0.0)
        self.distance_min = tk.DoubleVar(value=0.0)
        self.distance_max = tk.DoubleVar(value=800.0)
        self.stream_initial = tk.DoubleVar(value=1.0)
        self.stream_final = tk.DoubleVar(value=0.3)
        self.interference_initial = tk.DoubleVar(value=0.0)
        self.interference_final = tk.DoubleVar(value=0.75)
        self.cone_1 = tk.DoubleVar(value=1.0)
        self.cone_2 = tk.DoubleVar(value=1.0)
        self.cone_3 = tk.DoubleVar(value=1.0)
        self.filters_enabled = tk.BooleanVar(value=True)
        self.stream_url = tk.StringVar(
            value="http://killuminatis.duckdns.org:8585/listen/carpincho_radio/radio.mp3"
        )
        self.values = {
            "interference": 1.0,
            "program_gain": 1.0,
            "distance": 0.0,
            "distance_min": 0.0,
            "distance_max": 800.0,
            "stream_initial": 1.0,
            "stream_final": 0.3,
            "interference_initial": 0.0,
            "interference_final": 0.75,
            "cone_1": 1.0,
            "cone_2": 1.0,
            "cone_3": 1.0,
            "filters_enabled": True,
        }
        self.status = tk.StringVar(value="starting audio...")

        self.build_controls()
        self.process = subprocess.Popen(
            ["aplay", "-q", "-t", "raw", "-f", "S16_LE", "-c", "2", "-r", str(RATE)],
            stdin=subprocess.PIPE,
        )
        self.audio_thread = threading.Thread(target=self.audio_loop, daemon=True)
        self.audio_thread.start()
        self.start_stream()
        self.root.protocol("WM_DELETE_WINDOW", self.close)
        self.refresh_status()

    def build_controls(self) -> None:
        frame = tk.Frame(self.root, padx=12, pady=12)
        frame.pack(fill="both", expand=True)
        tk.Label(frame, text="Stream URL", width=16, anchor="w").grid(row=0, column=0, sticky="w")
        tk.Entry(frame, textvariable=self.stream_url, width=52).grid(row=0, column=1, sticky="ew")
        tk.Button(frame, text="Start stream", command=self.start_stream).grid(row=0, column=2, padx=(6, 0))
        self.filters_enabled.trace_add(
            "write",
            lambda *_args: self.update_value("filters_enabled", self.filters_enabled),
        )
        tk.Checkbutton(
            frame,
            text="Enable hi/low-pass filters",
            variable=self.filters_enabled,
        ).grid(row=0, column=3, padx=(8, 0), sticky="w")
        controls = (
            (
                "TFAR factor",
                "interference",
                self.interference,
                0.0,
                1.0,
                0.01,
                "Degradacion recibida desde TFAR. 0 = senal limpia; 1 = perdida maxima.",
            ),
            ("Distance (m)", "distance", self.distance, 0.0, 2000.0, 1.0,
             "Distancia actual. Cerca de la torre = Distance min y maxima interferencia; lejos = Distance max y efecto neutro."),
            (
                "Stream volume",
                "program_gain",
                self.program_gain,
                0.0,
                1.0,
                0.01,
                "Volumen fijo del audio recibido desde la URL, antes de aplicar interferencia.",
            ),
            ("Stream initial (far)", "stream_initial", self.stream_initial, 0.0, 1.0, 0.01,
             "Volumen del stream lejos de la torre, en Distance max."),
            ("Stream final (near)", "stream_final", self.stream_final, 0.0, 1.0, 0.01,
             "Volumen final del stream cerca de la torre, en Distance min. Ejemplo: 0.30 = 30%."),
            ("Interference initial (far)", "interference_initial", self.interference_initial, 0.0, 2.0, 0.01,
             "Volumen inicial de interferencia lejos de la torre."),
            ("Interference final (near)", "interference_final", self.interference_final, 0.0, 2.0, 0.01,
             "Volumen final de interferencia cerca de la torre."),
            (
                "Cone 1",
                "cone_1",
                self.cone_1,
                0.0,
                1.0,
                0.01,
                "Aporte del primer cono. Se suma con los otros conos, no se panea a un lado.",
            ),
            (
                "Cone 2",
                "cone_2",
                self.cone_2,
                0.0,
                1.0,
                0.01,
                "Aporte del segundo cono. Su interferencia se suma al canal general.",
            ),
            (
                "Cone 3",
                "cone_3",
                self.cone_3,
                0.0,
                1.0,
                0.01,
                "Aporte del tercer cono. La suma final se limita a 1.0.",
            ),
        )
        for row, (label, name, variable, start, end, resolution, description) in enumerate(controls, start=1):
            tk.Label(frame, text=label, width=16, anchor="w").grid(row=row, column=0, sticky="w")
            variable.trace_add("write", lambda *_args, key=name, var=variable: self.update_value(key, var))
            tk.Scale(
                frame,
                variable=variable,
                from_=start,
                to=end,
                resolution=resolution,
                orient="horizontal",
                length=360,
            ).grid(row=row, column=1, sticky="ew")
            tk.Label(
                frame,
                text=description,
                justify="left",
                anchor="w",
                wraplength=430,
            ).grid(row=row, column=2, sticky="w", padx=(8, 0))
        frame.columnconfigure(1, weight=1)

        bounds_row = len(controls) + 1
        tk.Label(frame, text="Distance bounds", width=16, anchor="w").grid(
            row=bounds_row, column=0, sticky="w"
        )
        bounds = tk.Frame(frame)
        bounds.grid(row=bounds_row, column=1, sticky="w")
        for label, name, variable in (
            ("near", "distance_min", self.distance_min),
            ("far", "distance_max", self.distance_max),
        ):
            tk.Label(bounds, text=f"{label}:").pack(side="left")
            variable.trace_add("write", lambda *_args, key=name, var=variable: self.update_value(key, var))
            tk.Entry(bounds, textvariable=variable, width=8).pack(side="left", padx=(2, 8))
        tk.Label(
            frame,
            text="near = cerca de la torre, factor 1 y volumen final; far = lejos, factor 0 y volumen inicial.",
            justify="left",
            anchor="w",
            wraplength=430,
        ).grid(row=bounds_row, column=2, sticky="w", padx=(8, 0))

        buttons = tk.Frame(frame)
        buttons.grid(row=len(controls) + 2, column=0, columnspan=3, pady=(10, 4))
        tk.Button(buttons, text="Clean", command=lambda: self.set_preset(0.0, 0.0)).pack(side="left")
        tk.Button(buttons, text="Medium", command=lambda: self.set_preset(0.5, 0.5)).pack(side="left")
        tk.Button(buttons, text="Maximum", command=lambda: self.set_preset(1.0, 1.0)).pack(side="left")
        tk.Label(frame, textvariable=self.status, anchor="w").grid(
            row=len(controls) + 3, column=0, columnspan=3, sticky="ew"
        )

    def start_stream(self) -> None:
        self.stop_stream()
        url = self.stream_url.get().strip()
        if not url:
            self.status.set("synthetic stereo program")
            return
        try:
            self.stream_process = subprocess.Popen(
                [
                    "ffmpeg",
                    "-v",
                    "error",
                    "-reconnect",
                    "1",
                    "-reconnect_streamed",
                    "1",
                    "-reconnect_delay_max",
                    "5",
                    "-i",
                    url,
                    "-f",
                    "f32le",
                    "-ac",
                    "2",
                    "-ar",
                    str(RATE),
                    "pipe:1",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
        except OSError as error:
            self.status.set(f"stream error: {error}")
            return
        self.stream_thread = threading.Thread(target=self.read_stream, daemon=True)
        self.stream_thread.start()
        self.status.set("stream starting; static is stereo")

    def stop_stream(self) -> None:
        process = self.stream_process
        self.stream_process = None
        if process is not None:
            process.kill()
            process.wait()
        while True:
            try:
                self.stream_queue.get_nowait()
            except queue.Empty:
                break

    def read_stream(self) -> None:
        process = self.stream_process
        if process is None or process.stdout is None:
            return
        size = BLOCK * 2 * np.dtype(np.float32).itemsize
        while self.running and process is self.stream_process:
            data = process.stdout.read(size)
            if not data:
                break
            stereo = np.frombuffer(data, dtype=np.float32).copy()
            if len(stereo) < BLOCK * 2:
                break
            stereo = stereo[: BLOCK * 2].reshape(BLOCK, 2)
            try:
                self.stream_queue.put(stereo, timeout=0.2)
            except queue.Full:
                try:
                    self.stream_queue.get_nowait()
                except queue.Empty:
                    pass

    def set_preset(self, interference: float, static_gain: float) -> None:
        self.interference.set(interference)
        self.interference_initial.set(0.0)
        self.interference_final.set(static_gain if interference else 0.0)

    def read_controls(self) -> tuple[float, ...]:
        with self.lock:
            return (
                self.values["interference"],
                self.values["distance"],
                self.values["program_gain"],
                self.values["distance_min"],
                self.values["distance_max"],
                self.values["stream_initial"],
                self.values["stream_final"],
                self.values["interference_initial"],
                self.values["interference_final"],
                self.values["cone_1"],
                self.values["cone_2"],
                self.values["cone_3"],
                self.values["filters_enabled"],
            )

    def update_value(self, name: str, variable: tk.DoubleVar) -> None:
        with self.lock:
            self.values[name] = variable.get()

    def audio_loop(self) -> None:
        assert self.process.stdin is not None
        while self.running:
            (
                interference,
                distance,
                program_gain,
                distance_min,
                distance_max,
                stream_initial,
                stream_final,
                interference_initial,
                interference_final,
                cone_1,
                cone_2,
                cone_3,
                filters_enabled,
            ) = self.read_controls()
            distance_span = max(1.0, distance_max - distance_min)
            distance_factor = max(0.0, min(1.0, (distance_max - distance) / distance_span))
            cone_levels = np.clip(
                interference * distance_factor * np.array([cone_1, cone_2, cone_3]),
                0.0,
                1.0,
            )
            target_interference = float(np.clip(np.sum(cone_levels), 0.0, 1.0))
            if distance >= distance_max:
                self.interference_state = 0.0
            else:
                # Smooth the cone boundary without leaving a long filter tail
                # while the listener is inside the distance range.
                self.interference_state += (target_interference - self.interference_state) * 0.03
            filter_amount = self.interference_state
            interference = self.interference_state
            try:
                program = self.stream_queue.get(timeout=0.05)
            except queue.Empty:
                t = (np.arange(BLOCK) + self.phase) / RATE
                left = 0.16 * np.sin(2 * np.pi * 220 * t) + 0.08 * np.sin(2 * np.pi * 330 * t)
                right = 0.16 * np.sin(2 * np.pi * 277.18 * t) + 0.08 * np.sin(2 * np.pi * 415.3 * t)
                self.phase += BLOCK
                program = np.column_stack((left, right)).astype(np.float32)
            program *= program_gain

            static = np.zeros((BLOCK, 2), dtype=np.float32)
            for cone, level in enumerate(cone_levels):
                clip = self.clips[cone]
                start = self.static_cursor[cone]
                indexes = (np.arange(BLOCK) + start) % len(clip)
                static += clip[indexes] * float(level)
                self.static_cursor[cone] = int((start + BLOCK) % len(clip))

            stream_level = stream_initial + (stream_final - stream_initial) * filter_amount
            interference_level = interference_initial + (interference_final - interference_initial) * filter_amount
            static *= interference_level
            program *= program_gain * stream_level
            mixed = program + static

            # A deliberately gentle stereo smoothing stage for hearing the
            # effect of the sliders without hiding the static bed.
            if filters_enabled and filter_amount > 0.0:
                unfiltered = mixed.copy()
                alpha = 0.04 + 0.30 * filter_amount
                for channel in range(2):
                    state = self.static_state[channel]
                    for index in range(BLOCK):
                        state += alpha * (mixed[index, channel] - state)
                        mixed[index, channel] = state
                    self.static_state[channel] = state
                mixed = unfiltered * (1.0 - filter_amount) + mixed * filter_amount
            else:
                # Outside every cone, do not leave the previous filter tail
                # active after the distance factor reaches zero.
                self.static_state[:] = mixed[-1]

            pcm = np.clip(mixed * 0.65, -1.0, 1.0)
            try:
                self.process.stdin.write((pcm * 32767).astype("<i2").tobytes())
                self.process.stdin.flush()
            except (BrokenPipeError, OSError):
                break

    def refresh_status(self) -> None:
        values = self.read_controls()
        (
            factor,
            distance,
            stream,
            distance_min,
            distance_max,
            stream_initial,
            stream_final,
            interference_initial,
            interference_final,
            cone_1,
            cone_2,
            cone_3,
            filters_enabled,
        ) = values
        distance_span = max(1.0, distance_max - distance_min)
        distance_factor = max(0.0, min(1.0, (distance_max - distance) / distance_span))
        effective = min(1.0, factor * distance_factor * (cone_1 + cone_2 + cone_3))
        self.status.set(
            "distance={:.0f}m near={:.0f}m far={:.0f}m factor={:.2f} effective={:.2f} stream={:.2f}->{:.2f} interference={:.2f}->{:.2f} filters={}".format(
                distance,
                distance_min,
                distance_max,
                factor,
                effective,
                stream_initial,
                stream_final,
                interference_initial,
                interference_final,
                filters_enabled,
            )
        )
        if self.running:
            self.root.after(200, self.refresh_status)

    def close(self) -> None:
        self.running = False
        self.stop_stream()
        if self.process.stdin is not None:
            self.process.stdin.close()
        self.process.terminate()
        self.root.destroy()


def main() -> None:
    root = tk.Tk()
    MixerLab(root)
    root.mainloop()


if __name__ == "__main__":
    main()
