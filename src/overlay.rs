// src/overlay.rs

use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use crate::key_listener::KeyEvent;
use crossbeam_channel::Receiver;
use eframe::egui;

/// When the final key is released, we store it here to fade out over 2 seconds.
struct ReleasedKey {
    label: String,
    released_at: Instant,
}

/// Shared overlay state:
///   • `held_modifiers` = any of “Shift”, “Ctrl”, “Alt”, “Meta” currently held  
///   • `held_map`       = Vec of (raw_label, displayed_label) for non-modifier keys currently held  
///   • `fading`         = Some(ReleasedKey) when “all keys/modifiers just got released,” else None  
///   • `visible`        = toggle to show/hide overlay entirely
pub struct OverlayState {
    held_modifiers: Vec<String>,
    held_map: Vec<(String, String)>, // (raw, displayed)
    fading: Option<ReleasedKey>,
    pub visible: bool,
}

impl Default for OverlayState {
    fn default() -> Self {
        OverlayState {
            held_modifiers: Vec::new(),
            held_map: Vec::new(),
            fading: None,
            visible: true,
        }
    }
}

impl OverlayState {
    /// Called on key‐down:
    ///   1) Cancel any in-progress fade (`self.fading = None`).
    ///   2) If raw_label is a modifier (“Shift” / “Ctrl” / “Alt” / “Meta”), add it to `held_modifiers`.
    ///   3) Otherwise, compute a “displayed” label:
    ///       - If Shift is in `held_modifiers` and raw_label is a single letter/digit, transform accordingly.
    ///       - Otherwise, displayed = raw_label.
    ///         Then insert `(raw_label, displayed)` into `held_map`.
    pub fn key_down(&mut self, raw_label: String) {
        // 1) Cancel any fade
        self.fading = None;

        // 2) If it’s one of our modifiers, just add it (if not already present):
        if raw_label == "Shift" || raw_label == "Ctrl" || raw_label == "Alt" || raw_label == "Meta"
        {
            if !self.held_modifiers.contains(&raw_label) {
                self.held_modifiers.push(raw_label);
            }
            return;
        }

        // 3) Otherwise, it’s a “regular” key. Compute displayed form:
        let mut displayed = raw_label.clone();

        // If Shift is held, transform single letters/digits:
        if self.held_modifiers.iter().any(|m| m == "Shift") && raw_label.len() == 1 {
            let c = raw_label.chars().next().unwrap();
            if c.is_ascii_lowercase() {
                // letter → uppercase
                displayed = c.to_ascii_uppercase().to_string();
            } else if c.is_ascii_digit() {
                // digit → symbol (US keyboard)
                displayed = match c {
                    '1' => "!".into(),
                    '2' => "@".into(),
                    '3' => "#".into(),
                    '4' => "$".into(),
                    '5' => "%".into(),
                    '6' => "^".into(),
                    '7' => "&".into(),
                    '8' => "*".into(),
                    '9' => "(".into(),
                    '0' => ")".into(),
                    _ => raw_label.clone(),
                };
            }
        }

        // Insert into held_map if that raw_label is not already present:
        if !self.held_map.iter().any(|(r, _)| r == &raw_label) {
            self.held_map.push((raw_label, displayed));
        }
    }

    /// Called on key‐up:
    ///   1) If raw_label is a modifier, remove it from `held_modifiers`.
    ///   2) Otherwise, find the entry in `held_map` whose first element == raw_label, remove it,
    ///      and capture its displayed label.  
    ///   3) If after removal both `held_modifiers` and `held_map` are empty, start fading the removed label.
    pub fn key_up(&mut self, raw_label: &str) {
        // 1) If releasing a modifier, just remove from held_modifiers:
        if raw_label == "Shift" || raw_label == "Ctrl" || raw_label == "Alt" || raw_label == "Meta"
        {
            self.held_modifiers.retain(|m| m != raw_label);
            return;
        }

        // 2) Otherwise, it’s a “regular” key. Look up in held_map:
        let mut removed_displayed: Option<String> = None;
        if let Some(idx) = self
            .held_map
            .iter()
            .position(|(r, _displayed)| r == raw_label)
        {
            // Remove it and keep its displayed label:
            let (_r, disp) = self.held_map.remove(idx);
            removed_displayed = Some(disp);
        }

        // 3) If _now_ both held_modifiers and held_map are empty, fade the removed label:
        if self.held_modifiers.is_empty() && self.held_map.is_empty() {
            if let Some(lbl) = removed_displayed {
                self.fading = Some(ReleasedKey {
                    label: lbl,
                    released_at: Instant::now(),
                });
            }
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

    /// Return a slice of currently held‐down “displayed” labels,
    /// in the order: (all modifiers except Shift) + (all ordinary displayed keys).
    /// However, if only Shift is held (and held_map is empty), return `["Shift"]`.
    pub fn get_held_labels(&self) -> Vec<String> {
        let mut out = Vec::new();

        // 1) If Shift is held _and_ there are ordinary keys held, do NOT show “Shift”:
        let show_shift =
            !self.held_modifiers.contains(&"Shift".to_string()) || self.held_map.is_empty();

        // 2) Append all other modifiers in the order they were pressed:
        for m in &self.held_modifiers {
            if m == "Shift" && !show_shift {
                continue;
            }
            out.push(m.clone());
        }

        // 3) Append all displayed ordinary keys in the order they were pressed:
        for (_raw, displayed) in &self.held_map {
            out.push(displayed.clone());
        }

        out
    }

    /// If we’re in a fade, return (label, alpha). Else None.
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

/// The eframe “App” that draws our always‐on‐top, transparent window.
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

        // 3) Build the list of held labels (modifiers + ordinary). If both are empty and no fade, skip drawing:
        let held_labels = st.get_held_labels();
        let fading_option = st.fading_label_and_alpha();
        if held_labels.is_empty() && fading_option.is_none() {
            ctx.request_repaint_after(Duration::from_millis(100));
            return;
        }

        // 4) Otherwise, draw a semi‐opaque black bar + all held or fading labels:
        let mut visuals = ctx.style().visuals.clone();
        visuals.window_fill = egui::Color32::from_rgba_unmultiplied(0, 0, 0, 0);
        ctx.set_visuals(visuals);

        egui::CentralPanel::default()
            .frame(egui::Frame {
                fill: egui::Color32::from_rgba_unmultiplied(0, 0, 0, 128),
                inner_margin: egui::Margin::same(10.0),
                stroke: egui::Stroke::NONE,
                ..Default::default()
            })
            .show(ctx, |ui| {
                ui.horizontal(|ui| {
                    // 4a) Draw all held labels at full opacity (255):
                    for label in &held_labels {
                        ui.label(
                            egui::RichText::new(label)
                                .font(egui::FontId::monospace(28.0))
                                .color(egui::Color32::from_rgba_unmultiplied(255, 255, 255, 255)),
                        );
                        ui.add_space(8.0);
                    }
                    // 4b) If fading, draw that single label with its computed alpha:
                    if let Some((label, alpha)) = fading_option {
                        ui.label(
                            egui::RichText::new(label)
                                .font(egui::FontId::monospace(28.0))
                                .color(egui::Color32::from_rgba_unmultiplied(255, 255, 255, alpha)),
                        );
                    }
                });
            });

        // 5) Keep repainting so the fade animation is smooth:
        ctx.request_repaint_after(Duration::from_millis(50));
    }
}
