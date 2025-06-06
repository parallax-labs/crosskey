mod key_listener;
mod overlay;

use std::sync::{Arc, Mutex};
use crossbeam_channel::unbounded;
use crate::key_listener::start_key_listener;
use crate::overlay::{OverlayState, KeyOverlayApp};

fn main() {
    // 1) Shared state + channel
    let state = Arc::new(Mutex::new(OverlayState::default()));
    let (tx, rx) = unbounded::<String>();

    // 2) Spawn the global key listener thread
    start_key_listener(tx.clone());

    // 3) Build our eframe app
    let app = KeyOverlayApp::new(state.clone(), rx);

    // 4) Configure a transparent, always–on–top, borderless window
    let native_options = eframe::NativeOptions {
        transparent: true,
        always_on_top: true,
        decorated: false, // no window decorations
        initial_window_size: Some(egui::vec2(300.0, 60.0)),
        ..Default::default()
    };

    // 5) Run the eframe loop. We ignore the `CreationContext` here (`|_|`).
    let _ = eframe::run_native(
        "crosskey",
        native_options,
        Box::new(|_| Box::new(app)),
    );
}
