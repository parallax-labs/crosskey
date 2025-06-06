// src/main.rs

mod key_listener;
mod overlay;

use crate::key_listener::{KeyEvent, start_key_listener};
use crate::overlay::{KeyOverlayApp, OverlayState};
use crossbeam_channel::unbounded;
use std::sync::{Arc, Mutex};

fn main() {
    // 1) Shared state + channel
    let state = Arc::new(Mutex::new(OverlayState::default()));
    let (tx, rx) = unbounded::<KeyEvent>();

    // 2) Spawn the key-listener thread
    start_key_listener(tx.clone());

    // 3) Build our eframe “App”
    let app = KeyOverlayApp::new(state.clone(), rx);

    // 4) Configure a transparent, always-on-top, borderless window (eframe 0.23)
    let native_options = eframe::NativeOptions {
        transparent: true,
        always_on_top: true,
        decorated: false,
        initial_window_size: Some(egui::vec2(300.0, 60.0)),
        ..Default::default()
    };

    // 5) Run the eframe loop:
    let _ = eframe::run_native("crosskey", native_options, Box::new(|_| Box::new(app)));
}
