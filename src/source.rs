use std::{
    collections::HashMap,
    mem::MaybeUninit,
    sync::{
        atomic::{AtomicBool, AtomicU8, Ordering},
        mpsc::{self, Receiver, Sender},
        Arc, Mutex, RwLock,
    },
    time::SystemTime,
};

use alto::Source;
use arma_rs::{Context, ContextState, Group};
use crossbeam_channel::TryRecvError;
use rand::{rngs::StdRng, Rng, SeedableRng};
use std::{
    collections::hash_map::DefaultHasher,
    hash::{Hash, Hasher},
};

use crate::{
    audio::{Audio, InterferenceCache},
    listener::Listener,
    streams::{StreamPacket, Streams},
    vector3::Vector3,
};

pub struct Sources();

type SourceMap = RwLock<HashMap<String, Mutex<SoundSource>>>;

impl Sources {
    pub fn get() -> Arc<SourceMap> {
        static mut SINGLETON: MaybeUninit<Arc<SourceMap>> = MaybeUninit::uninit();
        static mut INIT: bool = false;

        unsafe {
            if !INIT {
                SINGLETON.write(Arc::new(RwLock::new(HashMap::new())));
                INIT = true;
            }
            SINGLETON.assume_init_ref().clone()
        }
    }
}

enum SoundCommand {
    SetPos(Vector3, Vector3),
    SetGain(f32),
    SetQuality(f32),
    SetInterference([f32; 4], f32),
    SetMixConfig(bool, f32, f32, f32, f32),
    RefreshGain,
    Destroy,
}

struct LocalMixer {
    clips: Arc<InterferenceCache>,
    cursors: [f64; 4],
    current: [f32; 4],
    targets: [f32; 4],
    stream_fade: f32,
    stream_fade_target: f32,
    filters_enabled: bool,
    stream_initial: f32,
    stream_final: f32,
    interference_initial: f32,
    interference_final: f32,
    high_pass_state: [f32; 2],
    high_pass_input: [f32; 2],
    low_pass_state: [f32; 2],
    filter_current: f32,
    fluctuation_rngs: [StdRng; 4],
    fluctuation_current: [f32; 4],
    fluctuation_targets: [f32; 4],
    fluctuation_elapsed: [f32; 4],
    fluctuation_intervals: [f32; 4],
}

impl LocalMixer {
    fn new(id: &str) -> Option<Self> {
        let mut hasher = DefaultHasher::new();
        id.hash(&mut hasher);
        let seed = hasher.finish();
        let fluctuation_rngs = std::array::from_fn(|channel| {
            let mut bytes = [0u8; 32];
            bytes[..8].copy_from_slice(&seed.to_le_bytes());
            bytes[8..16].copy_from_slice(&(channel as u64).to_le_bytes());
            StdRng::from_seed(bytes)
        });
        Audio::interference().ok().map(|clips| Self {
            clips,
            cursors: [0.0; 4],
            current: [0.0; 4],
            targets: [0.0; 4],
            stream_fade: 1.0,
            stream_fade_target: 1.0,
            filters_enabled: true,
            stream_initial: 1.0,
            stream_final: 0.3,
            interference_initial: 0.0,
            interference_final: 0.75,
            high_pass_state: [0.0; 2],
            high_pass_input: [0.0; 2],
            low_pass_state: [0.0; 2],
            filter_current: 0.0,
            fluctuation_rngs,
            fluctuation_current: [1.0; 4],
            fluctuation_targets: [1.0; 4],
            fluctuation_elapsed: [0.0; 4],
            fluctuation_intervals: [0.08; 4],
        })
    }

    fn set_quality(&mut self, quality: f32) {
        self.targets[0] = quality.clamp(0.0, 1.0);
    }

    fn set_targets(&mut self, targets: [f32; 4], stream_fade: f32) {
        self.targets = targets.map(|target| target.clamp(0.0, 1.0));
        self.stream_fade_target = stream_fade.clamp(0.0, 1.0);
    }

    fn set_mix_config(
        &mut self,
        filters_enabled: bool,
        stream_initial: f32,
        stream_final: f32,
        interference_initial: f32,
        interference_final: f32,
    ) {
        self.filters_enabled = filters_enabled;
        self.stream_initial = stream_initial.clamp(0.0, 1.0);
        self.stream_final = stream_final.clamp(0.0, 1.0);
        self.interference_initial = interference_initial.clamp(0.0, 2.0);
        self.interference_final = interference_final.clamp(0.0, 2.0);
    }

    fn mix(&mut self, mut samples: Vec<alto::Stereo<f32>>, frequency: i32) -> Vec<alto::Stereo<f32>> {
        let frequency = frequency.max(1) as u32;
        for (current, target) in self.current.iter_mut().zip(self.targets) {
            *current += (target - *current) * 0.1;
        }
        let filter_target = self.targets[1..]
            .iter()
            .copied()
            .sum::<f32>()
            .clamp(0.0, 1.0);
        if filter_target <= 0.0001 {
            self.current[1..].fill(0.0);
            self.filter_current = 0.0;
        } else {
            self.filter_current += (filter_target - self.filter_current) * 0.03;
        }
        self.stream_fade += (self.stream_fade_target - self.stream_fade) * 0.1;
        let block_duration = samples.len() as f32 / frequency as f32;
        for channel in 0..4 {
            self.fluctuation_elapsed[channel] += block_duration;
            while self.fluctuation_elapsed[channel] >= self.fluctuation_intervals[channel] {
                self.fluctuation_elapsed[channel] -= self.fluctuation_intervals[channel];
                self.fluctuation_targets[channel] =
                    0.8 + self.fluctuation_rngs[channel].gen::<f32>() * 0.4;
                self.fluctuation_intervals[channel] =
                    0.08 + self.fluctuation_rngs[channel].gen::<f32>() * 0.17;
            }
            self.fluctuation_current[channel] += (self.fluctuation_targets[channel]
                - self.fluctuation_current[channel])
                * (block_duration / self.fluctuation_intervals[channel]).min(1.0);
        }
        let gains: [f32; 4] = std::array::from_fn(|channel| {
            self.current[channel] * self.fluctuation_current[channel]
        });
        // The general channel can add static, but the hi/low-pass filter is
        // controlled only by the summed cone channels. Outside every cone the
        // program remains unfiltered.
        let filter_interference = self.filter_current;
        let high_pass = 20.0 + 780.0 * filter_interference;
        let low_pass = 20_000.0 - 18_000.0 * filter_interference;
        let high_alpha = (std::f32::consts::TAU * high_pass / frequency as f32).min(1.0);
        let low_alpha = (std::f32::consts::TAU * low_pass / frequency as f32).min(1.0);
        let clips = [
            &self.clips.resource_1,
            &self.clips.resource_3,
            &self.clips.resource_2,
            &self.clips.resource_1,
        ];

        for sample in &mut samples {
            let local = [0, 1].map(|output_channel| {
                clips
                    .iter()
                    .enumerate()
                    .map(|(channel, clip)| {
                        clip.sample_at(self.cursors[channel], frequency, output_channel)
                            * gains[channel]
                    })
                    .sum::<f32>()
            });
            // Attenuate the program progressively while keeping a clearly
            // audible procedural static bed at maximum quality loss.
            // Keep 30% of the program at maximum interference. The same
            // distance-derived factor controls both fade and filter amount.
            let stream_factor = self.stream_initial
                + (self.stream_final - self.stream_initial) * filter_interference;
            let program_gain = (stream_factor * self.stream_fade).clamp(0.0, 1.0);
            let mixed = [
                sample.left * program_gain + local[0] * 0.25,
                sample.right * program_gain + local[1] * 0.25,
            ];
            let filtered = [0, 1].map(|channel| {
                let high_passed = high_alpha
                    * (self.high_pass_state[channel]
                        + mixed[channel]
                        - self.high_pass_input[channel]);
                self.high_pass_input[channel] = mixed[channel];
                self.high_pass_state[channel] = high_passed;
                self.low_pass_state[channel] +=
                    low_alpha * (high_passed - self.low_pass_state[channel]);
                self.low_pass_state[channel]
            });
            let interference_level = self.interference_initial
                + (self.interference_final - self.interference_initial) * filter_interference;
            let filtered_output = [
                soft_limit(filtered[0] + local[0] * 0.65 * interference_level),
                soft_limit(filtered[1] + local[1] * 0.65 * interference_level),
            ];
            let filter_mix = if self.filters_enabled {
                filter_interference
            } else {
                0.0
            };
            sample.left = mixed[0] * (1.0 - filter_mix) + filtered_output[0] * filter_mix;
            sample.right = mixed[1] * (1.0 - filter_mix) + filtered_output[1] * filter_mix;
            for (cursor, clip) in self.cursors.iter_mut().zip(clips) {
                *cursor = clip.advance(*cursor, frequency);
            }
        }
        samples
    }
}

fn soft_limit(sample: f32) -> f32 {
    sample / (1.0 + sample.abs())
}

#[cfg(test)]
mod tests {
    use super::LocalMixer;

    #[test]
    fn maximum_interference_keeps_procedural_static_audible() {
        let mut mixer = LocalMixer::new("maximum-interference-test")
            .expect("interference assets should load");
        mixer.set_targets([0.0, 1.0, 0.0, 0.0], 1.0);

        let mut output = Vec::new();
        for _ in 0..100 {
            output = mixer.mix(
                vec![alto::Stereo { left: 1.0, right: 1.0 }; 1024],
                48_000,
            );
        }

        let peak = output
            .iter()
            .map(|sample| sample.left.abs().max(sample.right.abs()))
            .fold(0.0_f32, f32::max);
        let rms = (output
            .iter()
            .map(|sample| (sample.left * sample.left + sample.right * sample.right) * 0.5)
            .sum::<f32>()
            / output.len() as f32)
            .sqrt();
        assert!(peak > 0.001, "maximum interference became silent: {peak}");
        assert!(rms > 0.02, "maximum interference static is too quiet: {rms}");
    }
}

#[derive(Debug)]
pub struct SoundSource {
    position: Vector3,
    time: SystemTime,
    channel: Sender<SoundCommand>,
    alive: Arc<AtomicBool>,
}

struct SourceThreadGuard(Arc<AtomicBool>);

impl Drop for SourceThreadGuard {
    fn drop(&mut self) {
        self.0.store(false, Ordering::Release);
    }
}

impl SoundSource {
    pub fn new(ctx: Context, id: String, url: String, gain: f32) -> Self {
        let (tx, rx): (Sender<SoundCommand>, Receiver<SoundCommand>) = mpsc::channel();
        let alive = Arc::new(AtomicBool::new(true));
        let thread_alive = alive.clone();
        std::thread::spawn(move || {
            let _alive = SourceThreadGuard(thread_alive);
            debug!("Starting source `{}`", id);
            let stream = Streams::listen(url);
            let Some(listener) = Listener::get() else {
                error!("Source `{}` stopped: no OpenAL listener", id);
                return;
            };
            let Ok(mut source) = listener.new_streaming_source() else {
                error!("Error creating source");
                return;
            };
            source
                .set_soft_spatialization(alto::SoftSourceSpatialization::Enabled)
                .expect("Error setting soft spatialization");
            source
                .set_gain(
                    gain * ctx
                        .group()
                        .get::<AtomicU8>()
                        .map(|gain| gain.load(std::sync::atomic::Ordering::Relaxed))
                        .unwrap_or(255) as f32
                        / 255.0,
                )
                .expect("Error setting gain");
            let mut specific_gain = gain;
            let mut online = false;
            let mut reported = false;
            let mut mixer = LocalMixer::new(&id);
            'outer: loop {
                while let Ok(command) = rx.try_recv() {
                    match command {
                        #[allow(unused_variables)]
                        SoundCommand::SetPos(pos, vel) => {
                            if source.set_position([pos.x, pos.y, pos.z]).is_err() {
                                error!("Error setting position for {}", id);
                            }
                            if cfg!(not(test))
                                && source.set_velocity([vel.x, vel.y, vel.z]).is_err()
                            {
                                error!("Error setting velocity for {}", id);
                            }
                        }
                        SoundCommand::SetQuality(new_quality) => {
                            debug!("Setting quality to {} for {}", new_quality, id);
                            if let Some(mixer) = mixer.as_mut() {
                                mixer.set_quality(new_quality);
                            }
                        }
                        SoundCommand::SetInterference(targets, stream_fade) => {
                            debug!("Setting interference targets for {}: {:?}", id, targets);
                            if let Some(mixer) = mixer.as_mut() {
                                mixer.set_targets(targets, stream_fade);
                            }
                        }
                        SoundCommand::SetMixConfig(
                            filters_enabled,
                            stream_initial,
                            stream_final,
                            interference_initial,
                            interference_final,
                        ) => {
                            if let Some(mixer) = mixer.as_mut() {
                                mixer.set_mix_config(
                                    filters_enabled,
                                    stream_initial,
                                    stream_final,
                                    interference_initial,
                                    interference_final,
                                );
                            }
                        }
                        SoundCommand::SetGain(gain) => {
                            debug!("Setting gain to {} for {}", gain, id);
                            specific_gain = gain;
                            if source
                                .set_gain(
                                    gain * ctx
                                        .group()
                                        .get::<AtomicU8>()
                                        .map(|gain| gain.load(std::sync::atomic::Ordering::Relaxed))
                                        .unwrap_or(255)
                                        as f32
                                        / 255.0,
                                )
                                .is_err()
                            {
                                error!("Error setting gain");
                            }
                        }
                        SoundCommand::RefreshGain => {
                            debug!("Refreshing gain for {}", id);
                            if source
                                .set_gain(
                                    specific_gain
                                        * ctx
                                            .group()
                                            .get::<AtomicU8>()
                                            .map(|gain| {
                                                gain.load(std::sync::atomic::Ordering::Relaxed)
                                            })
                                            .unwrap_or(255)
                                            as f32
                                        / 255.0,
                                )
                                .is_err()
                            {
                                error!("Error setting gain");
                            }
                        }
                        SoundCommand::Destroy => {
                            debug!("Source `{}` destroy command received; stopping worker", id);
                            source.stop();
                            break 'outer;
                        }
                    }
                }
                match stream.receiver.try_recv() {
                    Ok(recv) => {
                        match recv {
                            StreamPacket::Data(samples, freq) => {
                                let samples = if let Some(mixer) = mixer.as_mut() {
                                    mixer.mix(samples, freq)
                                } else {
                                    samples
                                };
                                if !online {
                                    online = true;
                                    reported = true;
                                    if ctx
                                        .callback_data(
                                            "live_radio",
                                            "status",
                                            Some(vec![id.to_string(), "online".to_string()]),
                                        )
                                        .is_err()
                                    {
                                        // arma is probably closed
                                        break;
                                    }
                                }
                                let buffer = if source.buffers_processed() > 200 {
                                    if let Ok(mut buffer) = source.unqueue_buffer() {
                                        if let Err(e) = buffer.set_data(samples, freq) {
                                            error!(
                                                "Error setting buffer sample data for {}: {}",
                                                id, e
                                            );
                                            continue;
                                        }
                                        buffer
                                    } else {
                                        let Some(listener) = Listener::get() else {
                                            return;
                                        };
                                        let Ok(buffer) = listener.new_buffer(samples, freq) else {
                                            error!("Error creating buffer for {}", id);
                                            continue;
                                        };
                                        buffer
                                    }
                                } else {
                                    let Some(listener) = Listener::get() else {
                                        return;
                                    };
                                    let Ok(buffer) = listener.new_buffer(samples, freq) else {
                                        error!("Error creating buffer for {}", id);
                                        continue;
                                    };
                                    buffer
                                };
                                if let Err(e) = source.queue_buffer(buffer) {
                                    error!(
                                        "Source `{}` worker stopped: queueing buffer failed: {}",
                                        id, e
                                    );
                                    return;
                                }
                                if source.state() != alto::SourceState::Playing
                                    && source.buffers_queued() > 75
                                {
                                    info!("Playing source for {}, {:?}", id, source.state());
                                    source.play();
                                }
                            }
                            StreamPacket::Title(title) => {
                                if ctx
                                    .callback_data(
                                        "live_radio",
                                        "title",
                                        Some(vec![id.to_string(), title]),
                                    )
                                    .is_err()
                                {
                                    // arma is probably closed
                                    break;
                                }
                            }
                            StreamPacket::Close => {
                                debug!("Source `{}` stream ended or disconnected", id);
                                if online || !reported {
                                    reported = true;
                                    online = false;
                                    if ctx
                                        .callback_data(
                                            "live_radio",
                                            "status",
                                            Some(vec![id.to_string(), "offline".to_string()]),
                                        )
                                        .is_err()
                                    {
                                        // arma is probably closed
                                        break;
                                    }
                                }
                                source.stop();
                                break;
                            }
                            StreamPacket::Check => {
                                // noop
                            }
                        }
                    }
                    Err(TryRecvError::Empty) => {
                        std::thread::sleep(std::time::Duration::from_millis(16));
                    }
                    Err(TryRecvError::Disconnected) => {
                        error!(
                            "Source `{}` stream receiver disconnected; worker is stopping",
                            id
                        );
                        if online || !reported {
                            reported = true;
                            online = false;
                            if ctx
                                .callback_data(
                                    "live_radio",
                                    "status",
                                    Some(vec![id.to_string(), "offline".to_string()]),
                                )
                                .is_err()
                            {
                                // arma is probably closed
                            }
                        }
                        break;
                    }
                }
            }
            debug!("Source `{}` has died", id);
        });
        Self {
            position: Vector3::new(0.0, 0.0, 0.0),
            time: SystemTime::now(),
            channel: tx,
            alive,
        }
    }

    pub fn set_position(&mut self, position: [f32; 3]) {
        let old = self.time;
        self.time = SystemTime::now();
        let dif = self
            .time
            .duration_since(old)
            .expect("time doesn't flow backwards");
        let elapsed: f32 = (dif.as_secs() as f32) + (dif.subsec_nanos() as f32 / 1_000_000_000.0);

        if elapsed == 0.0 {
            return;
        }

        let velocity = self
            .position
            .update(position[0], position[1], position[2], elapsed);
        if self
            .channel
            .send(SoundCommand::SetPos(self.position, velocity))
            .is_err()
        {
            error!("error sending position update");
        }
    }

    pub fn set_gain(&self, gain: f32) {
        if self.channel.send(SoundCommand::SetGain(gain)).is_err() {
            error!("error sending gain update");
        }
    }

    pub fn set_quality(&self, quality: f32) {
        if self
            .channel
            .send(SoundCommand::SetQuality(quality))
            .is_err()
        {
            error!("error sending quality update");
        }
    }

    pub fn set_interference(&self, targets: [f32; 4], stream_fade: f32) {
        if self
            .channel
            .send(SoundCommand::SetInterference(targets, stream_fade))
            .is_err()
        {
            error!("error sending interference update");
        }
    }

    pub fn set_mix_config(
        &self,
        filters_enabled: bool,
        stream_initial: f32,
        stream_final: f32,
        interference_initial: f32,
        interference_final: f32,
    ) {
        if self
            .channel
            .send(SoundCommand::SetMixConfig(
                filters_enabled,
                stream_initial,
                stream_final,
                interference_initial,
                interference_final,
            ))
            .is_err()
        {
            error!("error sending mix configuration update");
        }
    }

    pub fn refresh_gain(&self) {
        self.channel
            .send(SoundCommand::RefreshGain)
            .expect("not poisoned");
    }
}

impl Drop for SoundSource {
    fn drop(&mut self) {
        debug!("Dropping source");
        if self.channel.send(SoundCommand::Destroy).is_err() {
            error!("error sending destroy command");
        }
    }
}

pub fn cleanup() {
    debug!("cleaning up sources");
    Sources::get().write().expect("not poisoned").clear();
}

pub fn group() -> Group {
    let global_gain = AtomicU8::new(255);
    Group::new()
        .command("new", command_new)
        .command("destroy", command_destroy)
        .command("pos", command_set_position)
        .command("gain", command_set_gain)
        .command("quality", command_set_quality)
        .command("interference", command_set_interference)
        .command("mix_config", command_set_mix_config)
        .command("exists", command_source_exists)
        .command("global_gain", command_set_global_gain)
        .state(global_gain)
}

fn command_new(ctx: Context, id: String, source: String, gain: f32) -> String {
    Sources::get().write().expect("not poisoned").insert(
        id.clone(),
        Mutex::new(SoundSource::new(ctx, id.clone(), source, gain)),
    );
    id
}

fn command_destroy(id: String) -> bool {
    Sources::get()
        .write()
        .expect("not poisoned")
        .remove(&id)
        .is_some()
}

pub fn command_set_position(id: String, x: f32, y: f32, z: f32) {
    if let Some(src) = Sources::get().read().expect("not poisoned").get(&id) {
        src.lock().expect("not poisoned").set_position([x, y, z]);
    }
}

pub fn command_set_gain(id: String, gain: f32) {
    if let Some(src) = Sources::get().read().expect("not poisoned").get(&id) {
        src.lock().expect("not poisoned").set_gain(gain);
    }
}

pub fn command_set_quality(id: String, quality: f32) {
    if let Some(src) = Sources::get().read().expect("not poisoned").get(&id) {
        src.lock().expect("not poisoned").set_quality(quality);
    }
}

pub fn command_set_interference(
    id: String,
    quality: f32,
    cone_1: f32,
    cone_2: f32,
    cone_3: f32,
    stream_fade: f32,
) {
    if let Some(src) = Sources::get().read().expect("not poisoned").get(&id) {
        src.lock()
            .expect("not poisoned")
            .set_interference([quality, cone_1, cone_2, cone_3], stream_fade);
    }
}

pub fn command_set_mix_config(
    id: String,
    filters_enabled: bool,
    stream_initial: f32,
    stream_final: f32,
    interference_initial: f32,
    interference_final: f32,
) {
    if let Some(src) = Sources::get().read().expect("not poisoned").get(&id) {
        src.lock().expect("not poisoned").set_mix_config(
            filters_enabled,
            stream_initial,
            stream_final,
            interference_initial,
            interference_final,
        );
    }
}

pub fn command_source_exists(id: String) -> String {
    let alive = Sources::get()
        .read()
        .expect("not poisoned")
        .get(&id)
        .and_then(|source| source.lock().ok())
        .is_some_and(|source| source.alive.load(Ordering::Acquire));
    if alive {
        "1".to_string()
    } else {
        "0".to_string()
    }
}

pub fn command_set_global_gain(ctx: Context, gain: f32) {
    let gain = (gain * 255.0) as u8;
    debug!("Setting global gain to {}", gain);
    if let Some(state) = ctx.group().get::<AtomicU8>() {
        state.store(gain, std::sync::atomic::Ordering::Relaxed);
    }
    Sources::get()
        .read()
        .expect("not poisoned")
        .iter()
        .for_each(|(_, src)| {
            src.lock().expect("not poisoned").refresh_gain();
        });
}
