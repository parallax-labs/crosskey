// src/overlay.rs

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use crossbeam_channel::Receiver;
use eframe::egui;
use crate::key_listener::KeyEvent;

/// When the last key is released, we store exactly one of these for fading.
struct ReleasedKey {
    label: String,
    released_at: Instant,
}

/// Shared overlay state:
///   • `held`   = currently held‐down keys (drawn at full opacity)
///   • `fading` = `Some(ReleasedKey)` if “all keys were just released,” else `None`
///   • `visible`= toggle to hide/show the overlay entirely
pub struct OverlayState {
    held: Vec<String>,
    fading: Option<ReleasedKey>,
    pub visible: bool,
}

impl Default for OverlayState {
    fn default() -> Self {
        OverlayState {
            held: Vec::new(),
            fading: None,
            visible: true,
        }
    }
}

impl OverlayState {
    /// Call on key‐down:
    ///   • Clear any fading (because a new press resets the fade).  
    ///   • Insert into `held` if not already present.
    pub fn key_down(&mut self, label: String) {
        // 1) Any new press cancels any old fading:
        self.fading = None;

        // 2) Add to held if not already there:
        if !self.held.contains(&label) {
            self.held.push(label);
        }
    }

    /// Call on key‐up:
    ///   • Remove from `held`.  
    ///   • If that empties `held`, start a fade for this label.
    pub fn key_up(&mut self, label: &str) {
        // 1) Remove from held:
        self.held.retain(|s| s != label);

        // 2) If held is now empty, start fading this key:
        if self.held.is_empty() {
            self.fading = Some(ReleasedKey {
                label: label.to_owned(),
                released_at: Instant::now(),
            });
        }
    }

    /// Drop any fading entry older than 2 seconds.
    fn prune_expired(&mut self) {
        if let Some(rk) = &self.fading {
            if Instant::now().duration_since(rk.released_at) >= Duration::from_secs(2) {
                self.fading = None;
            }
        }
    }

    /// Return a slice of held‐down key labels.
    pub fn get_held(&self) -> &[String] {
        &self.held
    }

    /// If there’s a fading key, compute its alpha (0..255). Otherwise, return `None`.
    /// At release time (`t=0`) → alpha=255; at `t=2 s` → alpha=0.
    pub fn fading_label_and_alpha(&self) -> Option<(&str, u8)> {
        if let Some(rk) = &self.fading {
            let elapsed = Instant::now().duration_since(rk.released_at);
            if elapsed >= Duration::from_secs(2) {
                return None;
            }
            let t = elapsed.as_secs_f32() + (elapsed.subsec_nanos() as f32) * 1e-9;
            let alpha_f = 1.0 - (t / 2.0);
            let alpha = (alpha_f.clamp(0.0, 1.0) * 255.0) as u8;
            return Some((rk.label.as_str(), alpha));
        }
        None
    }
}

/// The eframe “App” that draws our always-on-top, transparent window.
pub struct KeyOverlayApp {
    state: Arc<Mutex<OverlayState>>,
    rx: Receiver<KeyEvent>,
}

impl KeyOverlayApp {
    pub fn new(state: Arc<Mutex<OverlayState>>, rx: Receiver<KeyEvent>) -> Self {
        KeyOverlayApp { state, rx }
    }
}

impl eframe::App for KeyOverlayApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // 1) Drain all pending KeyEvent messages:
        while let Ok(ev) = self.rx.try_recv() {
            let mut st = self.state.lock().unwrap();
            if st.visible {
                match ev {
                    KeyEvent::Down(label) => st.key_down(label),
                    KeyEvent::Up(label) => st.key_up(&label),
                }
            }
        }

        // 2) Prune any expired fade:
        {
            let mut st = self.state.lock().unwrap();
            st.prune_expired();
        }
        let st = self.state.lock().unwrap();

        // 3) If no held keys and no fading key, draw nothing (window stays fully transparent):
        let fading_opt = st.fading_label_and_alpha();
        if st.get_held().is_empty() && fading_opt.is_none() {
            ctx.request_repaint_after(Duration::from_millis(100));
            return;
        }

        // 4) Otherwise, draw a semi-opaque background + held/fading labels:
        let mut visuals = ctx.style().visuals.clone();
        visuals.window_fill = egui::Color32::from_rgba_unmultiplied(0, 0, 0, 0); // fully transparent behind
        ctx.set_visuals(visuals);

        egui::CentralPanel::default().frame(egui::Frame {
            fill: egui::Color32::from_rgba_unmultiplied(0, 0, 0, 128), // 50% black
            inner_margin: egui::Margin::same(10.0),
            stroke: egui::Stroke::NONE,
            ..Default::default()
        }).show(ctx, |ui| {
            ui.horizontal(|ui| {
                // 4a) Draw all held keys at full opacity (alpha=255):
                for label in st.get_held().iter() {
                    ui.label(
                        egui::RichText::new(label)
                            .font(egui::FontId::monospace(28.0))
                            .color(egui::Color32::from_rgba_unmultiplied(255, 255, 255, 255)),
                    );
                    ui.add_space(8.0);
                }
                // 4b) Draw the single fading key (if any) with computed alpha:
                if let Some((label, alpha)) = fading_opt {
                    ui.label(
                        egui::RichText::new(label)
                            .font(egui::FontId::monospace(28.0))
                            .color(egui::Color32::from_rgba_unmultiplied(255, 255, 255, alpha)),
                    );
                }
            });
        });

        // 5) Continue repainting so fading animates:
        ctx.request_repaint_after(Duration::from_millis(50));
    }
}
