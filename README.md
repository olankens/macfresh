<div align="center">
  <p><img src=".assets/icon.avif" align="center" width="128"></p>
  <h1><code>MACFRESH</code></h1>
</div>

<table>
  <tbody><tr><td align="center" width="99999"><div>
    <a href="https://olankens.com">WEBSITE</a> ·
    <a href="https://ko-fi.com/olankens">FUNDING</a>
  </div></td></tr></tbody>
  <tbody><tr><td align="center" width="99999">&nbsp;<div>
    Configure your macOS machine automatically with this highly opinionated post-installation script. Update and install all necessary development tools and apply strict defaults without manual intervention.
  </div>&nbsp;</td></tr></tbody>
  <tbody><tr><td align="center" width="99999">
    <a href="https://www.apple.com/os/macos"><img src=".assets/logo-apple.svg" align="center" width="56"></a>
    <picture><img src=".assets/splitter.gif" align="center" height="40" width="1"/></picture>
    <a href="https://brew.sh"><img src=".assets/logo-homebrew.svg" align="center" width="56"></a>
    <picture><img src=".assets/splitter.gif" align="center" height="40" width="1"/></picture>
    <a href="https://wikipedia.org/wiki/Bash_(Unix_shell)"><img src=".assets/logo-bash.svg" align="center" width="56"></a>
  </td></tr></tbody>
</table>

## PREVIEWS

<table><tbody><tr><td width="99999">
  <img src=".assets/preview-01.avif" align="center" width="49.21875%"><picture><img src=".assets/spacer.gif" align="center" width="1.5625%"></picture><img src=".assets/preview-02.avif" align="center" width="49.21875%">
</td></tr></tbody></table>

## FEATURES

<table>
  <tbody><tr><td width="99999">Installs Homebrew, configures the shell environment in zprofile, accepts the Xcode license, verifies accessibility permissions and enables unattended sudo for seamless system automation.</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Configures system defaults including computer names, mutes the boot chime, enables tap-to-click with Homebrew, enables zsh autosuggestions and applies strict finder and global defaults.</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Deploys Ungoogled Chromium as the default browser with a custom new tab page, dark mode, uBlock Origin Lite, iCloud Passwords sync and additional extensions for enhanced online privacy.</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Provisions Java Temurin, Node LTS with pnpm, Miniforge Conda, PowerShell without telemetry, Android SDK with Pixel emulator, Xcode via Xcodes, Flutter and Docker with Colima virtual machine.</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Automates first launch setup for IntelliJ Idea, Android Studio and Visual Studio Code with JetBrains Mono font, format on save, dotenv, Error Lens and carefully tuned telemetry settings.</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Equips the workspace with Eslint, Prettier, Angular, Astro, Spring Boot Initializr, NestJS CLI, Github CLI, ShellCheck, shfmt, Bash IDE and other essential developer tooling packages installed.</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Integrates Claude Code globally with onboarding skipped, raises the token ceiling, adds Headroom context manager via uv, Routatic proxy and bridges the agent to JetBrains editors securely.</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Brings everyday utilities like Figma, UTM, Calibre with plugins, JDownloader, Transmission, Keka, KeepingYouAwake, IINA, DaVinci Resolve, GameHub, OBS Studio, Postman and Nightlight applications.</td><td>✅</td></tr></tbody>
</table>

## LEARNING

### INVOKE WITHOUT FLAGS

```sh
/bin/zsh -c "$(curl -fsL https://github.com/olankens/macfresh/releases/latest/download/macfresh.sh)"
```

### IMPORT ANY FUNCTIONS

```sh
source <(curl -fsL https://github.com/olankens/macfresh/releases/latest/download/macfresh.sh)
```

### PREPARE NODE TOOLING

```shell
command -v pnpm >/dev/null && pnpm install || npm install
```
