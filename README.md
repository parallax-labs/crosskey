# Crosskey

Crosskey is a lightweight overlay tool that displays global key presses in a transparent, always-on-top window. It’s perfect for screencasts, presentations, livestreams, or pair-programming sessions where viewers need real-time feedback on keyboard activity.

---

## Features

* **Global Key Capture**: Displays key down/up events system-wide.
* **Clear Labels**: Converts raw key codes into human-readable labels (letters, digits, punctuation, modifiers, arrows, function keys).
* **Fade-Out Animation**: Last released key fades out over 2 seconds.
* **Minimal Footprint**: Written in Rust with minimal dependencies (`rdev` + `egui`).
* **Cross-Platform**: Supports Linux (X11) and macOS.
* **Nix Flake Integration**: One-command build, run, and development shell via Nix.

---

## Quick Start

### Download a Release

1. Visit the [Releases](https://github.com/parallaxlabs/crosskey/releases) page.
2. Download the binary for your platform (Linux or macOS).
3. Make it executable and move it into your `$PATH`:

   ```bash
   chmod +x crosskey-<platform>
   mv crosskey-<platform> /usr/local/bin/crosskey
   ```

### Build & Install from Source

#### Using Nix Flake (recommended)

```bash
git clone https://github.com/parallaxlabs/crosskey.git
cd crosskey

# Build the binary
nix build .#crosskey

# The compiled binary is at ./result/bin/crosskey
./result/bin/crosskey
```

To install system-wide:

```bash
sudo cp result/bin/crosskey /usr/local/bin/
```

To enter a development shell with all dependencies:

```bash
nix develop
```

#### Using Cargo

1. Ensure Rust is installed via [rustup](https://rustup.rs).

2. On **Linux**, install X11 headers and pkg-config:

   ```bash
   sudo apt-get install libx11-dev libxi-dev libxtst-dev pkg-config
   ```

3. On **macOS**, install Xcode Command Line Tools (`xcode-select --install`) and grant Accessibility permissions to the app when prompted.

4. Clone and build:

   ```bash
   git clone https://github.com/parallaxlabs/crosskey.git
   cd crosskey
   cargo build --release
   ```

5. Run the binary:

   ```bash
   ./target/release/crosskey
   ```

---

## Usage

Once installed, run:

```bash
crosskey
```

* A small, semi-opaque strip appears on your screen.
* Press any key to see its label appear instantly.
* Modifiers (Shift/Ctrl/Alt/Meta) display only when held alone or if no other keys are pressed.
* The last key released fades out over 2 seconds.
* To exit, close the overlay window or press `Ctrl+C` in the terminal.

---

## Configuration

Currently, Crosskey runs with sensible defaults. Future versions will introduce:

* Font size, color, and opacity settings
* Custom overlay position (top, bottom, corners)
* Command-line flags or a simple configuration file

---

## Contributing

Contributions are welcome! Follow these steps:

1. **Fork the repo** and clone your fork:

   ```bash
   git clone https://github.com/parallaxlabs/crosskey.git
   cd crosskey
   ```

2. **Create a feature branch**:

   ```bash
   git checkout -b feat/your-feature-name
   ```

3. **Enter the dev environment** (if using Nix):

   ```bash
   nix develop
   ```

4. **Implement your changes**. Maintain Rust 2021 style. For formatting and linting:

   ```bash
   cargo fmt -- --check
   cargo clippy --all-targets --all-features -- -D warnings
   ```

5. **Run tests**:

   ```bash
   cargo test
   ```

6. **Submit a Pull Request** against the `main` branch:

   * Provide a clear description of your changes.
   * Reference related issues, if any.
   * Add tests or update documentation when appropriate.

### Issues & Feature Requests

* Open an [issue](https://github.com/parallaxlabs/crosskey/issues) for bugs or suggestions.
* Discuss ideas or ask questions in the issue tracker.

### Code of Conduct

This project follows a [Code of Conduct](CODE_OF_CONDUCT.md). Please review it for community guidelines.

---

## Roadmap

1. **Appearance Customization**

   * CLI flags or config file for font size, text color, background color/opacity, overlay size, and position.
2. **Hotkey Toggle & Tray Icon**

   * Global hotkey (e.g., `Ctrl+Shift+O`) to show/hide the overlay.
   * System tray icon to start/stop without closing the process.
3. **Wayland & Windows Support**

   * Explore Wayland compatibility and alternative backends.
   * Investigate a Windows port using platform-appropriate key-capture APIs.
4. **Mouse Visualization**

   * Optional display of mouse clicks or cursor position alongside key events.
5. **Plugin Framework**

   * Minimal plugin API (e.g., WASM) for custom overlays or integrations.
6. **Performance & Resource Optimization**

   * Reduce CPU usage when idle by adjusting repaint intervals.
   * Profile memory/CPU footprint on low-end hardware.
7. **Packaging & Distribution**

   * Native installers: `.deb`, `.rpm`, Homebrew formula, etc.
   * Automated GitHub Releases for seamless binary publishing.

Track progress and vote on features via the [Roadmap issue](https://github.com/parallaxlabs/crosskey/issues/1).

---

## Community & Support

* **Issues**: [https://github.com/parallaxlabs/crosskey/issues](https://github.com/parallaxlabs/crosskey/issues)
* **Pull Requests**: [https://github.com/parallaxlabs/crosskey/pulls](https://github.com/parallaxlabs/crosskey/pulls)

---

## License

Crosskey is released under the MIT License. See [LICENSE](LICENSE) for details.
