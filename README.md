<div align="center">
  <p><img src=".assets/icon.avif" align="center" width="112"></p>
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
    <a href="https://www.apple.com/os/macos"><img src=".assets/apple.svg" alt="apple" align="center" width="56"></a>
    <picture><img src=".assets/divider.gif" align="center" height="40" width="1"/></picture>
    <a href="https://brew.sh"><img src=".assets/homebrew.svg" alt="homebrew" align="center" width="56"></a>
    <picture><img src=".assets/divider.gif" align="center" height="40" width="1"/></picture>
    <a href="https://wikipedia.org/wiki/Bash_(Unix_shell)"><img src=".assets/bash.svg" alt="bash" align="center" width="56"></a>
  </td></tr></tbody>
</table>

## PREVIEWS

<table><tbody><tr><td width="99999">
  <img src=".assets/preview-01.avif" align="center" width="49.21875%"><picture><img src=".assets/blank.gif" align="center" width="1.5625%"></picture><img src=".assets/preview-02.avif" align="center" width="49.21875%">
</td></tr></tbody></table>

## FEATURES

<table>
  <tbody><tr><td width="99999">Set Homebrew and shell env</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set macOS defaults, telemetry, chime</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set theme, wallpaper, dock, icons</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set Git, gh, and Zsh</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set JDK, Node, Conda, Flutter</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set Ungoogled Chromium</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set Ungoogled extensions</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set IDEs, themes, and plugins</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set Android SDK and emulator</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set development presets</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set Docker, Colima, and UTM</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set Claude Code and Headroom</td><td>✅</td></tr></tbody>
  <tbody><tr><td>Set daily applications</td><td>✅</td></tr></tbody>
</table>

## LEARNING

### LAUNCH SCRIPT

```sh
/bin/zsh -c "$(curl -fsL https://raw.githubusercontent.com/olankens/macfresh/HEAD/scripts/macfresh.sh)"
```

### IMPORT FUNCTIONS

```sh
source <(curl -fsL https://raw.githubusercontent.com/olankens/macfresh/HEAD/scripts/macfresh.sh)
```

### MERGE DEVELOP BRANCH

```sh
git fetch origin
git switch main
git pull --ff-only origin main
git merge develop
git push origin main
git switch develop
```
