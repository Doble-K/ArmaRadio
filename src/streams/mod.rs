use std::{
    collections::HashMap,
    mem::MaybeUninit,
    sync::{
        atomic::{AtomicU8, AtomicUsize, Ordering},
        Arc, RwLock,
    },
};

use crossbeam_channel::{Receiver, Sender};
use simplemad::Decoder;

use self::read::RemoteStream;

mod read;

#[derive(Clone)]
pub struct Senders(pub Arc<RwLock<Vec<Sender<StreamPacket>>>>);

impl Senders {
    pub fn push(&self, sender: Sender<StreamPacket>) {
        self.0.write().expect("not poisoned").push(sender);
    }
}

pub struct Stream {
    pub count: Arc<AtomicU8>,
    pub senders: Senders,
    /// Number of decoder threads currently running for this stream
    pub running: Arc<AtomicUsize>,
    generation: Arc<AtomicUsize>,
}

impl Stream {
    pub fn start(&self, url: &str) {
        debug!("Starting stream: {}", url);
        let count = self.count.clone();
        let running = self.running.clone();
        let generation = self.generation.clone();
        let gen = generation.fetch_add(1, Ordering::AcqRel) + 1;
        let url = url.to_string();
        let senders = self.senders.clone();
        std::thread::spawn(move || {
            running.fetch_add(1, Ordering::AcqRel);
            let remote = RemoteStream::new(&url, senders.clone());
            let Ok(remote) = remote else {
                error!(
                    "Failed to start stream: {}",
                    remote.err().expect("error expected")
                );
                running.fetch_sub(1, Ordering::AcqRel);
                if generation.load(Ordering::Acquire) == gen
                    && count.load(Ordering::Relaxed) > 0
                {
                    for sender in senders.0.read().expect("not poisoned").iter() {
                        let _ = sender.send(StreamPacket::Close);
                    }
                }
                return;
            };
            let Ok(decoder) = Decoder::decode(remote) else {
                error!("Failed to start stream: {}", url);
                running.fetch_sub(1, Ordering::AcqRel);
                if generation.load(Ordering::Acquire) == gen
                    && count.load(Ordering::Relaxed) > 0
                {
                    for sender in senders.0.read().expect("not poisoned").iter() {
                        let _ = sender.send(StreamPacket::Close);
                    }
                }
                return;
            };
            for decoding_result in decoder {
                if count.load(Ordering::Relaxed) == 0
                    || generation.load(Ordering::Acquire) != gen
                {
                    debug!("no listeners or superseded, shutting down stream");
                    break;
                }
                match decoding_result {
                    Err(e) => error!("Error decoding frame for {}: {:?}", url, e),
                    Ok(frame) => {
                        let mut samples: Vec<alto::Mono<f32>> = Vec::new();
                        for i in 0..frame.samples[0].len() {
                            samples.push(alto::Mono {
                                center: (frame.samples[0][i].to_f32()
                                    + frame.samples[1][i].to_f32())
                                    / 2.0_f32,
                            });
                        }
                        let mut delete = false;
                        for sender in senders.0.read().expect("not poisoned").iter() {
                            if let Err(e) = sender.send(StreamPacket::Data(
                                samples.clone(),
                                frame.sample_rate as i32,
                            )) {
                                error!("Failed to send data: {}", e);
                                delete = true;
                            }
                        }
                        if delete {
                            senders
                                .0
                                .write()
                                .expect("not poisoned")
                                .retain(|s| s.send(StreamPacket::Check).is_ok());
                        }
                    }
                }
            }
            running.fetch_sub(1, Ordering::AcqRel);
            debug!("Stream decoder ended for {}", url);
            if generation.load(Ordering::Acquire) == gen
                && count.load(Ordering::Relaxed) > 0
            {
                for sender in senders.0.read().expect("not poisoned").iter() {
                    let _ = sender.send(StreamPacket::Close);
                }
            }
        });
    }
}

pub enum StreamPacket {
    Data(Vec<alto::Mono<f32>>, i32),
    Title(String),
    Close,
    Check,
}

pub struct StreamListener {
    pub receiver: Receiver<StreamPacket>,
    pub count: Arc<AtomicU8>,
    pub running: Arc<AtomicUsize>,
}

impl Drop for StreamListener {
    fn drop(&mut self) {
        self.count.fetch_sub(1, Ordering::SeqCst);
        Streams::get()
            .write()
            .expect("not poisoned")
            .iter()
            .for_each(|(_, stream)| {
                stream
                    .senders
                    .0
                    .write()
                    .expect("not poisoned")
                    .retain(|s| s.send(StreamPacket::Check).is_ok());
            });
    }
}

pub struct Streams;

impl Streams {
    pub fn get() -> Arc<RwLock<HashMap<String, Stream>>> {
        static mut SINGLETON: MaybeUninit<Arc<RwLock<HashMap<String, Stream>>>> =
            MaybeUninit::uninit();
        static mut INIT: bool = false;

        unsafe {
            if !INIT {
                SINGLETON.write(Arc::new(RwLock::new(HashMap::new())));
                INIT = true;
            }
            SINGLETON.assume_init_ref().clone()
        }
    }

    pub fn listen(url: String) -> StreamListener {
        let (sender, receiver) = crossbeam_channel::unbounded();
        let streams_arc = Self::get();
        let mut streams = streams_arc.write().expect("not poisoned");
        if let Some(stream) = streams.get(&url) {
            debug!("using existing stream for {}", url);
            if stream.count.fetch_add(1, Ordering::SeqCst) == 0 {
                stream.start(&url);
            }
            stream.senders.push(sender);
            return StreamListener {
                receiver,
                count: stream.count.clone(),
                running: stream.running.clone(),
            };
        }
        debug!("creating new stream for {}", url);
        let stream = Stream {
            count: Arc::new(AtomicU8::new(1)),
            senders: Senders(Arc::new(RwLock::new(vec![sender]))),
            running: Arc::new(AtomicUsize::new(0)),
            generation: Arc::new(AtomicUsize::new(0)),
        };
        stream.start(&url);
        let sl = StreamListener {
            receiver,
            count: stream.count.clone(),
            running: stream.running.clone(),
        };
        streams.insert(url, stream);
        sl
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        let receiver =
            super::Streams::listen("http://pulseedm.cdnstream1.com:8124/1373_128".to_string());
        std::thread::sleep(std::time::Duration::from_secs(3));
        drop(receiver);
        std::thread::sleep(std::time::Duration::from_secs(3));
    }
}
