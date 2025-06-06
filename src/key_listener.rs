// src/key_listener.rs

use rdev::{listen, Event, EventType, Key};
use crossbeam_channel::Sender;
use std::thread;

/// A “key event” that distinguishes press vs. release.
/// We send these over the channel so the UI can transform/apply Shift, etc.
#[derive(Clone, Debug)]
pub enum KeyEvent {
    Down(String),
    Up(String),
}

/// Map an rdev `Key` → a short `String` label (or `None` if we don’t care).
/// We now return `"Space"` for space, and still return `"Shift"`, `"Ctrl"`, etc.,
/// since the overlay will handle transforming letters if Shift is held.
fn map_key_code(key: Key) -> Option<String> {
    match key {
        // ─────────── Letters ───────────
        Key::KeyA => Some("a".into()),
        Key::KeyB => Some("b".into()),
        Key::KeyC => Some("c".into()),
        Key::KeyD => Some("d".into()),
        Key::KeyE => Some("e".into()),
        Key::KeyF => Some("f".into()),
        Key::KeyG => Some("g".into()),
        Key::KeyH => Some("h".into()),
        Key::KeyI => Some("i".into()),
        Key::KeyJ => Some("j".into()),
        Key::KeyK => Some("k".into()),
        Key::KeyL => Some("l".into()),
        Key::KeyM => Some("m".into()),
        Key::KeyN => Some("n".into()),
        Key::KeyO => Some("o".into()),
        Key::KeyP => Some("p".into()),
        Key::KeyQ => Some("q".into()),
        Key::KeyR => Some("r".into()),
        Key::KeyS => Some("s".into()),
        Key::KeyT => Some("t".into()),
        Key::KeyU => Some("u".into()),
        Key::KeyV => Some("v".into()),
        Key::KeyW => Some("w".into()),
        Key::KeyX => Some("x".into()),
        Key::KeyY => Some("y".into()),
        Key::KeyZ => Some("z".into()),

        // ─────────── Numbers ───────────
        Key::Num0 => Some("0".into()),
        Key::Num1 => Some("1".into()),
        Key::Num2 => Some("2".into()),
        Key::Num3 => Some("3".into()),
        Key::Num4 => Some("4".into()),
        Key::Num5 => Some("5".into()),
        Key::Num6 => Some("6".into()),
        Key::Num7 => Some("7".into()),
        Key::Num8 => Some("8".into()),
        Key::Num9 => Some("9".into()),

        // ───────── Punctuation (US-ANSI) ─────────
        Key::Minus        => Some("-".into()),
        Key::Equal        => Some("=".into()),
        Key::LeftBracket  => Some("[".into()),
        Key::RightBracket => Some("]".into()),
        Key::BackSlash    => Some("\\".into()),
        Key::SemiColon    => Some(";".into()),
        Key::Quote        => Some("'".into()),
        Key::Comma        => Some(",".into()),
        Key::Dot          => Some(".".into()),
        Key::Slash        => Some("/".into()),

        // ─────────── Specials ───────────
        Key::Return    => Some("⏎".into()),
        Key::Backspace => Some("⌫".into()),
        Key::Tab       => Some("↹".into()),
        Key::Escape    => Some("Esc".into()),
        Key::Space     => Some("Space".into()), // Now “Space” instead of “␣”

        // Modifiers
        Key::ShiftLeft   | Key::ShiftRight   => Some("Shift".into()),
        Key::ControlLeft | Key::ControlRight => Some("Ctrl".into()),
        Key::Alt                              => Some("Alt".into()),
        Key::MetaLeft    | Key::MetaRight    => Some("Meta".into()),

        // Arrow keys
        Key::UpArrow    => Some("↑".into()),
        Key::DownArrow  => Some("↓".into()),
        Key::LeftArrow  => Some("←".into()),
        Key::RightArrow => Some("→".into()),

        // Function keys
        Key::F1  => Some("F1".into()),
        Key::F2  => Some("F2".into()),
        Key::F3  => Some("F3".into()),
        Key::F4  => Some("F4".into()),
        Key::F5  => Some("F5".into()),
        Key::F6  => Some("F6".into()),
        Key::F7  => Some("F7".into()),
        Key::F8  => Some("F8".into()),
        Key::F9  => Some("F9".into()),
        Key::F10 => Some("F10".into()),
        Key::F11 => Some("F11".into()),
        Key::F12 => Some("F12".into()),

        // Home / End / PageUp / PageDown / Insert / Delete
        Key::Home      => Some("Home".into()),
        Key::End       => Some("End".into()),
        Key::PageUp    => Some("PgUp".into()),
        Key::PageDown  => Some("PgDn".into()),
        Key::Insert    => Some("Ins".into()),
        Key::Delete    => Some("Del".into()),

        _ => None,
    }
}

/// Spawn a background thread that listens for both `KeyPress` and `KeyRelease`.
/// On press → send `KeyEvent::Down(label)`. On release → send `KeyEvent::Up(label)`.
pub fn start_key_listener(tx: Sender<KeyEvent>) {
    thread::spawn(move || {
        listen(move |event: Event| {
            match event.event_type {
                EventType::KeyPress(key) => {
                    if let Some(label) = map_key_code(key) {
                        let _ = tx.send(KeyEvent::Down(label));
                    }
                }
                EventType::KeyRelease(key) => {
                    if let Some(label) = map_key_code(key) {
                        let _ = tx.send(KeyEvent::Up(label));
                    }
                }
                _ => {}
            }
        })
        .unwrap();
    });
}
