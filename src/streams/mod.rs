use std::{
    collections::HashMap,
    mem::MaybeUninit,
    sync::{
        atomic::{AtomicBool, AtomicU64, AtomicU8, Ordering},
        Arc, Mutex, RwLock,
    },
    time::{Duration, Instant},
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
    pub generation: u64,
    pub count: Arc<AtomicU8>,
    pub senders: Senders,
    idle_since: Arc<Mutex<Option<Instant>>>,
    active: Arc<AtomicBool>,
}

impl Stream {
    pub fn start(&self, url: &str) {
        debug!("Starting stream: {} generation {}", url, self.generation);
        let count = self.count.clone();
        let url = url.to_string();
        let senders = self.senders.clone();
        let idle_since = self.idle_since.clone();
        let active = self.active.clone();
        std::thread::spawn(move || {
            let remote = RemoteStream::new(&url, senders.clone());
            let Ok(remote) = remote else {
                error!(
                    "Failed to start stream: {}",
                    remote.err().expect("error expected")
                );
                send_close(&senders);
                active.store(false, Ordering::Release);
                return;
            };
            let Ok(decoder) = Decoder::decode(remote) else {
                error!("Failed to start stream: {}", url);
                send_close(&senders);
                active.store(false, Ordering::Release);
                return;
            };
            for decoding_result in decoder {
                if count.load(Ordering::Relaxed) == 0 {
                    let idle_at = *idle_since.lock().expect("not poisoned");
                    if idle_at
                        .is_some_and(|since| since.elapsed() >= Duration::from_secs(30))
                    {
                        debug!("idle stream expired, shutting down stream");
                        Streams::remove_if_same(&url, &senders);
                        break;
                    }
                    std::thread::sleep(Duration::from_millis(50));
                    continue;
                }
                match decoding_result {
                    Err(_) => {} // error!("Error: {:?}", e),
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

            // A normal EOF must be visible to every source. Without this
            // packet the source thread remains alive with an exhausted stream
            // and the UI never receives the offline transition.
            send_close(&senders);
            active.store(false, Ordering::Release);
        });
    }
}

fn send_close(senders: &Senders) {
    for sender in senders.0.read().expect("not poisoned").iter() {
        let _ = sender.send(StreamPacket::Close);
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
    stream: Arc<Stream>,
    sender: Sender<StreamPacket>,
}

impl Drop for StreamListener {
    fn drop(&mut self) {
        let previous = self
            .stream
            .count
            .fetch_sub(1, std::sync::atomic::Ordering::SeqCst);
        self.stream
            .senders
            .0
            .write()
            .expect("not poisoned")
            .retain(|sender| !sender.same_channel(&self.sender));
        if previous == 1 {
            *self.stream.idle_since.lock().expect("not poisoned") = Some(Instant::now());
        }
    }
}

pub struct Streams;

static NEXT_GENERATION: AtomicU64 = AtomicU64::new(1);

impl Streams {
    pub fn get() -> Arc<RwLock<HashMap<String, Arc<Stream>>>> {
        static mut SINGLETON: MaybeUninit<Arc<RwLock<HashMap<String, Arc<Stream>>>>> =
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
        // Hold the map write lock through lookup and insertion so concurrent
        // source creation cannot start two streams for the same URL.
        let streams = Self::get();
        let mut streams = streams.write().expect("not poisoned");
        if let Some(stream) = streams.get(&url).cloned() {
            if stream.active.load(Ordering::Acquire) {
                debug!("using existing stream for {}", url);
                stream.count.fetch_add(1, Ordering::SeqCst);
                *stream.idle_since.lock().expect("not poisoned") = None;
                stream.senders.push(sender.clone());
                return StreamListener {
                    receiver,
                    stream,
                    sender,
                };
            }
        }
        streams.remove(&url);
        debug!("creating new stream for {}", url);
        let stream = Arc::new(Stream {
            generation: NEXT_GENERATION.fetch_add(1, Ordering::Relaxed),
            count: Arc::new(AtomicU8::new(1)),
            senders: Senders(Arc::new(RwLock::new(vec![sender.clone()]))),
            idle_since: Arc::new(Mutex::new(None)),
            active: Arc::new(AtomicBool::new(true)),
        });
        let stream_url = url.clone();
        streams.insert(url, stream.clone());
        stream.start(&stream_url);
        let sl = StreamListener {
            receiver,
            stream,
            sender,
        };
        sl
    }

    fn remove_if_same(url: &str, senders: &Senders) {
        let streams = Self::get();
        let mut streams = streams.write().expect("not poisoned");
        if streams
            .get(url)
            .is_some_and(|stream| Arc::ptr_eq(&stream.senders.0, &senders.0))
        {
            streams.remove(url);
        }
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
