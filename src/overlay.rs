// src/overlay.rs

use std::sync::{Arc, Mutex};
use crossbeam_channel::Receiver;
use eframe::egui;

/// Shared overlay state: a small history of recent keys + a `visible` toggle.
pub struct OverlayState {
    recent: Vec<String>,
    pub visible: bool,
}

impl Default for OverlayState {
    fn default() -> Self {
        Self {
            recent: vec![],
            visible: true
        }
    }
}

impl OverlayState {
    /// Push a new key to the end, dropping the oldest if we exceed 6.
    pub fn push_key(&mut self, k: String) {
        if self.recent.len() >= 6 {
            self.recent.remove(0);
        }
        self.recent.push(k);
    }
}

/// The `eframe::App` that draws an always-on-top, semi-transparent window.
pub struct KeyOverlayApp {
    state: Arc<Mutex<OverlayState>>,
    rx: Receiver<String>,
}

impl KeyOverlayApp {
    pub fn new(state: Arc<Mutex<OverlayState>>, rx: Receiver<String>) -> Self {
        Self { state, rx }
    }
}

impl eframe::App for KeyOverlayApp {
    fn update(&mut self, ctx: &egui::Context, frame: &mut eframe::Frame) {
        // 1. Pull any pending keypresses:
        while let Ok(key_str) = self.rx.try_recv() {
            let mut st = self.state.lock().unwrap();
            if st.visible {
                st.push_key(key_str);
            }
        }

        // 2. If overlay is hidden, draw nothing (but keep the window alive):
        let st = self.state.lock().unwrap();
        if !st.visible {
            // Keep the window alive (just transparent):
            frame.set_visible(true);
            ctx.request_repaint_after(std::time::Duration::from_millis(100));
            return;
        }

        // 3. Otherwise, paint a transparent background + a semi-opaque panel with keys:
        let mut visuals = ctx.style().visuals.clone();
        // “Fully transparent” window background:
        visuals.window_fill = egui::Color32::from_rgba_unmultiplied(0, 0, 0, 0);
        ctx.set_visuals(visuals);

        egui::CentralPanel::default().frame(egui::Frame {
            fill: egui::Color32::from_rgba_unmultiplied(0, 0, 0, 128), // semi-opaque black
            inner_margin: egui::Margin::same(10.0),
            stroke: egui::Stroke::NONE,
            ..Default::default()
        }).show(ctx, |ui| {
            ui.horizontal(|ui| {
                for k in st.recent.iter() {
                    ui.label(
                        egui::RichText::new(k)
                            .font(egui::FontId::monospace(28.0))
                            .color(egui::Color32::WHITE),
                    );
                    ui.add_space(8.0);
                }
            });
        });

        // 4. Always repaint so we can fade out later (if you add a timer).
        ctx.request_repaint_after(std::time::Duration::from_millis(50));
    }
}
