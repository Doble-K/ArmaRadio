use std::io::{BufReader, Read};

use regex::Regex;
use reqwest::blocking::{Client, Response};

use super::{Senders, StreamPacket};

pub struct RemoteStream {
    response: BufReader<Response>,
    counter: usize,
    interval: Option<usize>,
    regex: Regex,
    senders: Senders,
}

impl RemoteStream {
    pub fn new(url: &str, senders: Senders) -> Result<Self, String> {
        let response = Client::new()
            .get(url)
            .header("Icy-MetaData", "1")
            .send()
            .map_err(|e| e.to_string())?;
        Ok(Self {
            interval: response
                .headers()
                .get("icy-metaint")
                .and_then(|i| i.to_str().ok())
                .and_then(|i| i.parse::<usize>().ok()),
            response: BufReader::new(response),
            counter: 0,
            regex: Regex::new("(?m)StreamTitle='(.+?)';").map_err(|e| e.to_string())?,
            senders,
        })
    }
}

impl RemoteStream {
    fn read_metadata(&mut self) -> std::io::Result<()> {
        let mut length = [0u8; 1];
        self.response.read_exact(&mut length)?;
        let length = length[0] as usize * 16;
        let mut metadata = vec![0u8; length];
        self.response.read_exact(&mut metadata)?;
        let metadata = String::from_utf8_lossy(&metadata);
        for cap in self.regex.captures_iter(&metadata) {
            for sender in self.senders.0.read().expect("not poisoned").iter() {
                let _ = sender.send(StreamPacket::Title(cap[1].to_string()));
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn regex() -> Regex {
        Regex::new("(?m)StreamTitle='(.+?)';").expect("valid regex")
    }

    #[test]
    fn parses_stream_title() {
        let meta = "StreamTitle='Artist - Song';StreamUrl='';";
        let caps: Vec<String> = regex()
            .captures_iter(meta)
            .map(|c| c[1].to_string())
            .collect();
        assert_eq!(caps, vec!["Artist - Song".to_string()]);
    }

    #[test]
    fn parses_multiple_titles() {
        let meta = "StreamTitle='A';StreamTitle='B';";
        let caps: Vec<String> = regex()
            .captures_iter(meta)
            .map(|c| c[1].to_string())
            .collect();
        assert_eq!(caps.len(), 2);
    }

    #[test]
    fn handles_no_title() {
        let meta = "StreamUrl='http://example.com';";
        let caps: Vec<String> = regex()
            .captures_iter(meta)
            .map(|c| c[1].to_string())
            .collect();
        assert!(caps.is_empty());
    }

    #[test]
    fn handles_null_padding() {
        let mut meta = String::from("StreamTitle='Song';");
        while (meta.len() % 16) != 0 {
            meta.push('\0');
        }
        let caps: Vec<String> = regex()
            .captures_iter(&meta)
            .map(|c| c[1].to_string())
            .collect();
        assert_eq!(caps, vec!["Song".to_string()]);
    }
}

impl Read for RemoteStream {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        let Some(interval) = self.interval else {
            return self.response.read(buf);
        };
        if interval == 0 || buf.is_empty() {
            return self.response.read(buf);
        }
        let mut read = 0;
        while read < buf.len() {
            let remaining = interval - self.counter;
            if buf.len() - read >= remaining {
                self.response.read_exact(&mut buf[read..read + remaining])?;
                read += remaining;
                self.counter += remaining;
            } else {
                self.response.read_exact(&mut buf[read..])?;
                read = buf.len();
                break;
            }
            if self.counter == interval {
                self.read_metadata()?;
                self.counter = 0;
            }
        }
        Ok(read)
    }
}
