use std::{
    io::Cursor,
    mem::MaybeUninit,
    sync::{Arc, OnceLock},
};

use alto::Alto;
use rust_embed::RustEmbed;
use simplemad::Decoder;

#[derive(RustEmbed)]
#[folder = "resources"]
struct Assets;

pub struct Audio();

pub struct InterferenceCache {
    pub resource_1: DecodedClip,
    pub resource_2: DecodedClip,
    pub resource_3: DecodedClip,
}

pub struct DecodedClip {
    samples: Arc<[f32]>,
    sample_rate: u32,
}

impl DecodedClip {
    pub fn sample_rate(&self) -> u32 {
        self.sample_rate
    }

    pub fn samples_at_rate(&self, sample_rate: u32) -> Vec<f32> {
        if sample_rate == 0 || sample_rate == self.sample_rate || self.samples.is_empty() {
            return self.samples.to_vec();
        }

        let length = ((self.samples.len() as u64 * sample_rate as u64) / self.sample_rate as u64)
            .max(1) as usize;
        let ratio = self.sample_rate as f64 / sample_rate as f64;
        (0..length)
            .map(|index| {
                let position = index as f64 * ratio;
                let left = position.floor() as usize;
                let right = (left + 1).min(self.samples.len() - 1);
                let fraction = position - left as f64;
                self.samples[left] * (1.0 - fraction as f32) + self.samples[right] * fraction as f32
            })
            .collect()
    }

    pub(crate) fn sample_at(&self, position: f64, sample_rate: u32) -> f32 {
        if self.samples.is_empty() || sample_rate == 0 {
            return 0.0;
        }
        let position = position % self.samples.len() as f64;
        let left = position.floor() as usize;
        let right = (left + 1) % self.samples.len();
        let fraction = position - left as f64;
        self.samples[left] * (1.0 - fraction as f32) + self.samples[right] * fraction as f32
    }

    pub(crate) fn advance(&self, position: f64, sample_rate: u32) -> f64 {
        if sample_rate == 0 {
            position
        } else {
            (position + self.sample_rate as f64 / sample_rate as f64)
                % self.samples.len().max(1) as f64
        }
    }
}

impl InterferenceCache {
    fn load() -> Result<Self, String> {
        Ok(Self {
            resource_1: decode_clip("Interferencia radio 1.mp3")?,
            resource_2: decode_clip("interferencia de Radio 2.mp3")?,
            resource_3: decode_clip("interferencia de Radio 3.mp3")?,
        })
    }
}

impl Audio {
    pub fn interference() -> Result<Arc<InterferenceCache>, String> {
        static CACHE: OnceLock<Result<Arc<InterferenceCache>, String>> = OnceLock::new();

        CACHE
            .get_or_init(|| InterferenceCache::load().map(Arc::new))
            .clone()
    }

    /// Gets a reference to the NATS connection.
    ///
    /// # Panics
    ///
    /// Panics if the NATS connection can not be initialized.
    pub fn get() -> Option<Arc<Alto>> {
        static mut SINGLETON: MaybeUninit<Arc<Alto>> = MaybeUninit::uninit();
        static mut INIT: bool = false;

        unsafe {
            if !INIT {
                SINGLETON.write(Arc::new({
                    let openal = std::path::Path::new("OpenAL32.dll");
                    if !openal.exists() {
                        let dll = Assets::get("OpenAL32.dll").expect("Failed to get OpenAL32.dll");
                        debug!("Creating OpenAL.dll");
                        let Ok(mut out) = std::fs::File::create(openal) else {
                            error!("Failed to create OpenAL32.dll");
                            return None;
                        };
                        if std::io::copy(&mut std::io::Cursor::new(dll.data), &mut out).is_err() {
                            error!("Failed to write to OpenAL32.dll");
                            return None;
                        }
                    }
                    Alto::load_default().expect("some sound exists")
                }));
                INIT = true;
            }
            Some(SINGLETON.assume_init_ref().clone())
        }
    }
}

fn decode_clip(path: &str) -> Result<DecodedClip, String> {
    let asset = Assets::get(path).ok_or_else(|| format!("Missing audio resource: {path}"))?;
    let decoder = Decoder::decode(Cursor::new(asset.data.to_vec()))
        .map_err(|_| String::from("Failed to initialize decoder"))?;
    let mut samples = Vec::new();
    let mut sample_rate = None;

    for frame in decoder {
        let frame = match frame {
            Ok(frame) => frame,
            Err(_) => continue,
        };
        if frame.samples.is_empty() || frame.samples.iter().any(Vec::is_empty) {
            continue;
        }
        sample_rate.get_or_insert(frame.sample_rate);
        let channels = frame.samples.len() as f32;
        for index in 0..frame.samples[0].len() {
            let mono = frame
                .samples
                .iter()
                .map(|channel| channel[index].to_f32())
                .sum::<f32>()
                / channels;
            samples.push(mono);
        }
    }

    let sample_rate = sample_rate.ok_or_else(|| format!("No audio frames in {path}"))?;
    let peak = samples
        .iter()
        .copied()
        .map(f32::abs)
        .fold(0.0_f32, f32::max);
    if peak > 0.0 {
        samples.iter_mut().for_each(|sample| *sample /= peak);
    }

    Ok(DecodedClip {
        samples: samples.into(),
        sample_rate,
    })
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use super::Audio;

    #[test]
    fn loads_all_interference_resources_once() {
        let first = Audio::interference().expect("interference resources should decode");
        let second = Audio::interference().expect("interference resources should be cached");
        assert!(Arc::ptr_eq(&first, &second));
        for clip in [&first.resource_1, &first.resource_2, &first.resource_3] {
            assert!(clip.sample_rate() > 0);
            let samples = clip.samples_at_rate(44_100);
            assert!(!samples.is_empty());
            assert!(samples.iter().all(|sample| sample.abs() <= 1.0));
        }
    }
}
