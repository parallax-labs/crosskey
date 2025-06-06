// src/key_listener.rs

use rdev::{listen, Event, EventType, Key};
use crossbeam_channel::Sender;

/// Simplified enum for the keys we want to display.
pub enum CapturedKey {
    Printable(char),
    Special(String),
}

/// Map an rdev `Event` → our `CapturedKey` (or `None` if we don’t care).
/// – Letters A–Z (lowercase)
/// – Numbers 0–9
/// – Common punctuation keys
/// – Function keys F1–F12
/// – Arrow keys, Enter, Backspace, Tab, Escape, Shift, Ctrl, Alt, Meta, etc.
fn map_event_to_key(ev: &Event) -> Option<CapturedKey> {
    if let EventType::KeyPress(key) = ev.event_type {
        match key {
            // ─────────── Letters ───────────
            Key::KeyA => Some(CapturedKey::Printable('a')),
            Key::KeyB => Some(CapturedKey::Printable('b')),
            Key::KeyC => Some(CapturedKey::Printable('c')),
            Key::KeyD => Some(CapturedKey::Printable('d')),
            Key::KeyE => Some(CapturedKey::Printable('e')),
            Key::KeyF => Some(CapturedKey::Printable('f')),
            Key::KeyG => Some(CapturedKey::Printable('g')),
            Key::KeyH => Some(CapturedKey::Printable('h')),
            Key::KeyI => Some(CapturedKey::Printable('i')),
            Key::KeyJ => Some(CapturedKey::Printable('j')),
            Key::KeyK => Some(CapturedKey::Printable('k')),
            Key::KeyL => Some(CapturedKey::Printable('l')),
            Key::KeyM => Some(CapturedKey::Printable('m')),
            Key::KeyN => Some(CapturedKey::Printable('n')),
            Key::KeyO => Some(CapturedKey::Printable('o')),
            Key::KeyP => Some(CapturedKey::Printable('p')),
            Key::KeyQ => Some(CapturedKey::Printable('q')),
            Key::KeyR => Some(CapturedKey::Printable('r')),
            Key::KeyS => Some(CapturedKey::Printable('s')),
            Key::KeyT => Some(CapturedKey::Printable('t')),
            Key::KeyU => Some(CapturedKey::Printable('u')),
            Key::KeyV => Some(CapturedKey::Printable('v')),
            Key::KeyW => Some(CapturedKey::Printable('w')),
            Key::KeyX => Some(CapturedKey::Printable('x')),
            Key::KeyY => Some(CapturedKey::Printable('y')),
            Key::KeyZ => Some(CapturedKey::Printable('z')),

            // ─────────── Numbers ───────────
            Key::Num0 => Some(CapturedKey::Printable('0')),
            Key::Num1 => Some(CapturedKey::Printable('1')),
            Key::Num2 => Some(CapturedKey::Printable('2')),
            Key::Num3 => Some(CapturedKey::Printable('3')),
            Key::Num4 => Some(CapturedKey::Printable('4')),
            Key::Num5 => Some(CapturedKey::Printable('5')),
            Key::Num6 => Some(CapturedKey::Printable('6')),
            Key::Num7 => Some(CapturedKey::Printable('7')),
            Key::Num8 => Some(CapturedKey::Printable('8')),
            Key::Num9 => Some(CapturedKey::Printable('9')),

            // ───────── Punctuation (US‐ANSI layout) ─────────
            Key::Minus        => Some(CapturedKey::Printable('-')),  // “–”
            Key::Equal        => Some(CapturedKey::Printable('=')),
            Key::LeftBracket  => Some(CapturedKey::Printable('[')),
            Key::RightBracket => Some(CapturedKey::Printable(']')),
            Key::BackSlash    => Some(CapturedKey::Printable('\\')),
            Key::SemiColon    => Some(CapturedKey::Printable(';')),
            Key::Quote        => Some(CapturedKey::Printable('\'')),
            // Key::Backtick     => Some(CapturedKey::Printable('`')),  // “~” requires Shift detection
            Key::Comma        => Some(CapturedKey::Printable(',')),
            Key::Dot          => Some(CapturedKey::Printable('.')),
            Key::Slash        => Some(CapturedKey::Printable('/')),
            
            // ─────────── Specials ───────────
            Key::Return     => Some(CapturedKey::Special("⏎".into())),
            Key::Backspace  => Some(CapturedKey::Special("⌫".into())),
            Key::Tab        => Some(CapturedKey::Special("↹".into())),
            Key::Escape     => Some(CapturedKey::Special("Esc".into())),
            Key::Space      => Some(CapturedKey::Special("␣".into())),

            // Modifiers
            Key::ShiftLeft    | Key::ShiftRight    => Some(CapturedKey::Special("Shift".into())),
            Key::ControlLeft  | Key::ControlRight  => Some(CapturedKey::Special("Ctrl".into())),
            Key::Alt          /* Alt gr is platform‐specific */ => Some(CapturedKey::Special("Alt".into())),
            Key::MetaLeft     | Key::MetaRight     => Some(CapturedKey::Special("Meta".into())),

            // Arrow keys
            Key::UpArrow    => Some(CapturedKey::Special("↑".into())),
            Key::DownArrow  => Some(CapturedKey::Special("↓".into())),
            Key::LeftArrow  => Some(CapturedKey::Special("←".into())),
            Key::RightArrow => Some(CapturedKey::Special("→".into())),

            // Function keys
            Key::F1  => Some(CapturedKey::Special("F1".into())),
            Key::F2  => Some(CapturedKey::Special("F2".into())),
            Key::F3  => Some(CapturedKey::Special("F3".into())),
            Key::F4  => Some(CapturedKey::Special("F4".into())),
            Key::F5  => Some(CapturedKey::Special("F5".into())),
            Key::F6  => Some(CapturedKey::Special("F6".into())),
            Key::F7  => Some(CapturedKey::Special("F7".into())),
            Key::F8  => Some(CapturedKey::Special("F8".into())),
            Key::F9  => Some(CapturedKey::Special("F9".into())),
            Key::F10 => Some(CapturedKey::Special("F10".into())),
            Key::F11 => Some(CapturedKey::Special("F11".into())),
            Key::F12 => Some(CapturedKey::Special("F12".into())),

            // Home / End / PageUp / PageDown / Insert / Delete
            Key::Home      => Some(CapturedKey::Special("Home".into())),
            Key::End       => Some(CapturedKey::Special("End".into())),
            Key::PageUp    => Some(CapturedKey::Special("PgUp".into())),
            Key::PageDown  => Some(CapturedKey::Special("PgDn".into())),
            Key::Insert    => Some(CapturedKey::Special("Ins".into())),
            Key::Delete    => Some(CapturedKey::Special("Del".into())),

            // Any other key we don’t care about
            _ => None,
        }
    } else {
        None
    }
}

/// Spawn a background thread that listens for global key presses and sends them as `String` over `tx`.
///
/// On macOS, you will need to grant “Accessibility” permission to your built binary (System Settings → Privacy & Security → Accessibility → allow this app).
/// On Windows, you may see a UAC prompt the first time.
/// On most Linux setups, this will work out of the box (X11/Wayland support via rdev).
pub fn start_key_listener(tx: Sender<String>) {
    std::thread::spawn(move || {
        listen(move |event| {
            if let Some(k) = map_event_to_key(&event) {
                let text = match k {
                    CapturedKey::Printable(c) => c.to_string(),
                    CapturedKey::Special(s) => s,
                };
                // We ignore send errors here (if the receiver side has gone away).
                let _ = tx.send(text);
            }
        })
        .unwrap();
    });
}
