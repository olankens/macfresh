#!/bin/zsh

# shellcheck shell=bash
# shellcheck disable=SC1091,SC2005,SC2016,SC2059,SC2128,SC2155,SC2178

#region UTILITIES

# @define Append application to the dock
# @params The application full path
append_dock_application() {

  # Handle parameters
  local element=${1}

  # Append application
  if [[ -d "$element" ]]; then
    defaults write com.apple.dock persistent-apps -array-add "<dict>
			<key>tile-data</key>
			<dict>
				<key>file-data</key>
				<dict>
					<key>_CFURLString</key>
					<string>${element}</string>
					<key>_CFURLStringType</key>
					<integer>0</integer>
				</dict>
			</dict>
		</dict>"
  fi

}

# @define Append folder to the dock
# @params The folder full path
# @params The arrangement integer (1: name, 2: added, 3: modified, 4: created, 5: kind)
# @params The display as integer (0: stack, 1: folder)
# @params The show as integer (0: automatic, 1: fan, 2: grid, 3: list)
append_dock_folder() {

  # Handle parameters
  local element=${1}
  local arrangement=${2:-1}
  local display_as=${3:-0}
  local show_as=${4:-0}

  # Append folder
  if [[ -d "$element" ]]; then
    defaults write com.apple.dock persistent-others -array-add "<dict>
			<key>tile-data</key>
			<dict>
				<key>arrangement</key>
				<integer>${arrangement}</integer>
				<key>displayas</key>
				<integer>${display_as}</integer>
				<key>file-data</key>
				<dict>
					<key>_CFURLString</key>
					<string>file://${element}</string>
					<key>_CFURLStringType</key>
					<integer>15</integer>
				</dict>
				<key>file-type</key>
				<integer>2</integer>
				<key>showas</key>
				<integer>${show_as}</integer>
			</dict>
			<key>tile-type</key>
			<string>directory-tile</string>
		</dict>"
  fi

}

# @define Append environment variables to .zshrc
# @params The checker string to verify if environment is already set
# @params The content lines to append to .zshrc
append_environment() {

  # Handle parameters
  local checker=${1}
  local content=("${@:2}")

  # Append environment
  if ! grep -q "$checker" "$HOME/.zshrc" 2>/dev/null; then
    [[ -s "$HOME/.zshrc" ]] || printf "#!/bin/zsh" >"$HOME/.zshrc"
    perl -i -0777 -pe "s/\n*\z/\n/s" "$HOME/.zshrc" 2>/dev/null || true
    for element in "${content[@]:0:$((${#content[@]} - 1))}"; do
      printf "\n%s" "$element" >>"$HOME/.zshrc"
    done
    printf "\n%s\n" "${content[-1]}" >>"$HOME/.zshrc"
    source "$HOME/.zshrc"
  fi

}

# @define Change default web browser
# @params The browser name (chrome, chromium, firefox, safari, vivaldi, ...)
change_browser() {

  # Handle parameters
  local browser=${1:-safari}

  # Handle dependencies
  update_brew defaultbrowser

  # Change browser
  defaultbrowser "$browser" && osascript <<-EOD
		tell application "System Events"
			try
				tell application process "CoreServicesUIAgent"
					tell window 1
						tell (first button whose name starts with "use") to perform action "AXPress"
					end tell
				end tell
			end try
		end tell
	EOD

}

# @define Change system hostname
# @params The new hostname
change_hostname() {

  # Handle parameters
  local payload=${1}

  # Change hostname
  sudo scutil --set ComputerName "$payload"
  sudo scutil --set HostName "$payload"
  sudo scutil --set LocalHostName "$payload"
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$payload"

}

# @define Change application or folder icon
# @params The distant icon name from repository
# @params The application or folder full path
change_icon() {

  # Handle parameters
  local distant=${1}
  local element=${2}

  # Handle dependencies
  update_brew curl fileicon

  # Change icon
  local address="https://github.com/olankens/nightwyn/raw/refs/heads/main/source/$distant/$distant.icns"
  local picture="$(mktemp -d)/$(basename "$address")"
  curl -LA "mozilla/5.0" "$address" -o "$picture"
  fileicon set "$element" "$picture" 2>/dev/null || sudo fileicon set "$element" "$picture"

}

# @define Change system sleep settings by enabling or disabling sleeping
# @params True to restore default sleep settings or false to disable it
change_sleeping() {

  # Handle parameters
  local enabled=${1:-true}

  # Enable sleeping
  if [[ "$enabled" == "true" ]]; then
    sudo pmset restoredefaults >/dev/null
  else
    sudo pmset -a displaysleep 0 && sudo pmset -a sleep 0
    (caffeinate -i -w $$ &) &>/dev/null
  fi

}

# @define Change sudo timeouts by enabling or disabling the password prompt
# @params True to enable the timeouts or false to disable it
change_timeouts() {

  # Handle parameters
  local enabled=${1:-true}

  # Enable timeouts
  if [[ "$enabled" == "true" ]]; then
    sudo rm /private/etc/sudoers.d/disable_timeout 2>/dev/null
  else
    echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /private/etc/sudoers.d/disable_timeout >/dev/null
  fi

}

# @define Change system timezone
# @params The timezone string
change_timezone() {

  # Handle parameters
  local payload=${1}

  # Change timezone
  sudo systemsetup -settimezone "$payload" &>/dev/null

}

# @define Change default wallpaper
# @params The distant wallpaper name from repository
change_wallpaper() {

  # Handle dependencies
  update_brew curl

  # Handle parameters
  local address=${1}

  # Change wallpaper
  local picture="$HOME/Pictures/Wallpapers/$(basename "$address")"
  mkdir -p "$(dirname "$picture")" && curl -LA "mozilla/5.0" "$address" -o "$picture"
  rm -v "$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
  killall WallpaperAgent
  osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$picture\""

}

# @define Expand archive
# @params The archive path or direct http url
# @params The deposit path for extraction
# @params The number of leading dirs to strip
# @return The extraction full path
expand_archive() {

  # Handle parameters
  local archive=${1}
  local deposit=${2:-.}
  local leading=${3:-0}

  # Expand archive
  if [[ -n $archive && ! -f $deposit && $leading =~ ^[0-9]+$ ]]; then
    mkdir -p "$deposit"
    if [[ $archive = http* ]]; then
      curl -L "$archive" | tar -zxf - -C "$deposit" --strip-components=$((leading))
    else
      tar -zxf "$archive" -C "$deposit" --strip-components=$((leading))
    fi
    printf "%s" "$deposit"
  fi

}

# @define Gather path using find command
# @params The search pattern or directory path
# @params The maximum depth for search
# @return The gathered full path
gather_pattern() {

  # Handle parameters
  local pattern=${1}
  local maximum=${2:-0}

  # Gather path
  echo "$(/bin/zsh -c "find $pattern -maxdepth $maximum" 2>/dev/null | sort -r | head -1)" || sudo !!

}

# @define Gather installed application version
# @params The application full path
# @return The gathered version for success, 0.0.0.0 for failure
gather_version() {

  # Handle parameters
  local deposit=${1}

  # Handle dependencies
  update_brew grep

  # Gather version
  local starter=$(gather_pattern "$deposit/*ontents/*nfo.plist")
  local version=$(defaults read "$starter" CFBundleShortVersionString 2>/dev/null)
  echo "$version" | ggrep -oP "[\d.]+" || echo "0.0.0.0"

}

# @define Invoke application, wait for first window and close
# @params The whole application name
# @params The whole process name
# @params The maximum wait time (seconds) for the window
invoke_once() {

  # Handle parameters
  local element=${1}
  local process=${2:-$1}
  local timeout=${3:-15}

  # Invoke application
  timeout "${timeout}" osascript <<-EOD
		tell application "/Applications/${element}.app"
			activate
			reopen
			tell application "System Events"
				tell process "${process}"
					repeat until (exists window 1)
						delay 1
					end repeat
				end tell
			end tell
			delay 4
			quit app "${element}"
			delay 4
		end tell
	EOD
  pkill -9 -f "$element"

}

# @define Invoke functions with a welcome message and tracks time
# @params The welcome message to display at the start
# @params The timezone string
# @params The machine hostname
# @params The functions to invoke in sequence
invoke_wrapper() {

  # Handle parameters
  local welcome=${1}
  local country=${2}
  local machine=${3}
  local members=("${@:4}")

  # Change headline
  printf "\033]0;%s\007" "$(basename "$ZSH_ARGZERO" | cut -d . -f 1 | tr '[:lower:]' '[:upper:]')"

  # Verify executor
  clear && printf "\033[92m%s\033[00m\n\n" "$welcome"
  verify_executor || return 1

  # Prompt password
  sudo -v
  local results=$?
  printf "\n"
  [[ $results -ne 0 ]] && return 1
  clear && printf "\033[92m%s\033[00m\n\n" "$welcome"

  # Remove timeouts
  change_timeouts false

  # Remove sleeping
  change_sleeping false

  # Verify requirements
  verify_security || return 1

  # Change timezone
  change_timezone "$country"

  # Change hostname
  change_hostname "$machine"

  # Output progress
  # local bigness=$((${#welcome} / $(echo "$welcome" | wc -l)))
  local bigness=$(printf "%s\n" "$welcome" | awk '{ if (length > max) max = length } END { print max }')
  local heading="\r%-"$((bigness - 19))"s   %-5s   %-8s\n\n"
  local loading="\033[93m\r%-"$((bigness - 19))"s   %02d/%02d   %-8s\b\033[0m"
  local failure="\033[91m\r%-"$((bigness - 19))"s   %02d/%02d   %-8s\n\033[0m"
  local success="\033[92m\r%-"$((bigness - 19))"s   %02d/%02d   %-8s\n\033[0m"
  printf "$heading" "FUNCTION" "ITEMS" "DURATION"
  local minimum=1 && local maximum=${#members[@]}
  for element in "${members[@]}"; do
    local written=$(basename "$(echo "$element" | cut -d "'" -f 1)" | tr "[:lower:]" "[:upper:]")
    local started=$(date +"%s") && printf "$loading" "$written" "$minimum" "$maximum" "--:--:--"
    eval "$element" >/dev/null 2>&1 && local current="$success" || local current="$failure"
    local extinct=$(date +"%s") && elapsed=$((extinct - started))
    local elapsed=$(printf "%02d:%02d:%02d\n" $((elapsed / 3600)) $(((elapsed % 3600) / 60)) $((elapsed % 60)))
    printf "$current" "$written" "$minimum" "$maximum" "$elapsed" && ((minimum++))
  done

  # Enable sleeping
  change_sleeping true

  # Enable timeouts
  change_timeouts true

  # Output newline
  printf "\n"

}

# @define Update brew packages
# @params The brew package names
update_brew() {

  # Handle parameters
  local factors=("$@")

  # Update packages
  brew install "${factors[@]}" 2>/dev/null
  brew upgrade "${factors[@]}" 2>/dev/null

}

# @define Update cask packages
# @params The cask package names
update_cask() {

  # Handle parameters
  local factors=("$@")

  # Update packages
  # brew install --cask --no-quarantine "${factors[@]}" 2>/dev/null
  # brew upgrade --cask --no-quarantine "${factors[@]}" 2>/dev/null
  brew install --cask "${factors[@]}" 2>/dev/null
  brew upgrade --cask "${factors[@]}" 2>/dev/null

}

# @define Handle verifying the executor's privileges
# @return 0 for success, 1 for failure
verify_executor() {

  if [[ $EUID = 0 ]]; then
    printf "\r\033[K"
    printf "\r\033[91m%s\033[00m\n\n" "EXECUTING DEVSETUP AS ROOT IS FORBIDDEN"
    return 1
  fi

}

# @define Handle current shell privileges, requires user interaction
# @return 0 for success, 1 for failure
verify_security() {

  printf "\r\033[K"
  printf "\r\033[93m%s\033[00m" "VERIFYING TERMINAL SECURITY, FOLLOW DIALOGS"
  # allowed() { osascript -e 'tell application "System Events" to log ""' &>/dev/null; }
  capable() { osascript -e 'tell application "System Events" to key code 60' &>/dev/null; }
  granted() { ls "$HOME/Library/Messages" &>/dev/null; }
  display() {
    heading=$(basename "$ZSH_ARGZERO" | cut -d . -f 1)
    osascript <<-EOD &>/dev/null
			tell application "${TERM_PROGRAM//Apple_/}"
				display alert "$heading" message "$1" as informational giving up after 10
			end tell
		EOD
  }
  # while ! allowed; do
  # 	display "You have to tap the OK button to continue."
  # 	tccutil reset AppleEvents &>/dev/null
  # done
  while ! capable; do
    display "You have to add your current terminal application to accessibility. When it's done, close the System Settings application to continue."
    open -W "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
  done
  while ! granted; do
    display "You have to add your current terminal application to full disk access. When it's done, close the System Settings application to continue."
    open -W "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  done
  return 0

}

#endregion

#region JETBRAINS

# @define Change default project directory for jetbrains products
# @params The jetbrains product name (e.g., "Google/AndroidStudio", "JetBrains/IntelliJIdea")
# @params The default project directory full path
change_jetbrains_deposit() {

  # Handle parameters
  local product=${1}
  local deposit=${2}

  # Handle dependencies
  update_brew xmlstarlet

  # Change deposit
  local configs=$(
    find "$HOME/Library/Application Support/$product"*/options -name "ide.general.local.xml" 2>/dev/null | sort -r |
      head -1
  )
  if [[ -f "$configs" ]]; then
    xmlstarlet ed -L -u "//option[@name='defaultProjectDirectory']/@value" -v "$deposit" "$configs" 2>/dev/null ||
      xmlstarlet ed -L -s "//application" -t elem -n "option" -v "" \
        -i "//option[not(@name)]" -t attr -n "name" -v "defaultProjectDirectory" \
        -i "//option[@name='defaultProjectDirectory']" -t attr -n "value" -v "$deposit" \
        "$configs" 2>/dev/null
  fi

}

# @define Change color scheme for jetbrains products
# @params The jetbrains product name (e.g., "Google/AndroidStudio", "JetBrains/IntelliJIdea")
# @params The color scheme name
change_jetbrains_scheme() {

  # Handle parameters
  local product=${1}
  local payload=${2:-Islands Dark}

  # Handle dependencies
  update_brew xmlstarlet

  # Change scheme
  local configs=$(
    find "$HOME/Library/Application Support/$product"*/options -name "colors.scheme.xml" 2>/dev/null | sort -r | head -1
  )
  if [[ -f "$configs" ]]; then
    xmlstarlet ed -L -u "//component[@name='EditorColorsManagerImpl']/global_color_scheme/@name" -v "$payload" "$configs" 2>/dev/null ||
      xmlstarlet ed -L -s "//application" -t elem -n "component" -v "" \
        -i "//component[not(@name)]" -t attr -n "name" -v "EditorColorsManagerImpl" \
        -s "//component[@name='EditorColorsManagerImpl']" -t elem -n "global_color_scheme" -v "" \
        -i "//global_color_scheme" -t attr -n "name" -v "$payload" \
        "$configs" 2>/dev/null
  fi

}

# @define Change theme for jetbrains products
# @params The jetbrains product name (e.g., "Google/AndroidStudio", "JetBrains/IntelliJIdea")
# @params The theme name
change_jetbrains_theme() {

  # Handle parameters
  local product=${1}
  local payload=${2:-Islands Dark}

  # Handle dependencies
  update_brew xmlstarlet

  # Change theme
  local configs=$(
    find "$HOME/Library/Application Support/$product"*/options -name "laf.xml" 2>/dev/null | sort -r | head -1
  )
  if [[ -f "$configs" ]]; then
    xmlstarlet ed -L -u "//component[@name='LafManager']/laf/@themeId" -v "$payload" "$configs" 2>/dev/null ||
      xmlstarlet ed -L -s "//application" -t elem -n "component" -v "" \
        -i "//component[not(@name)]" -t attr -n "name" -v "LafManager" \
        -s "//component[@name='LafManager']" -t elem -n "laf" -v "" \
        -i "//laf[not(@themeId)]" -t attr -n "themeId" -v "$payload" \
        "$configs" 2>/dev/null
  fi

}

#endregion

#region UNGOOGLED

# @define Change chromium download folder
# @params The download location full path
# @params The user-data-dir full path, empty for default one
change_chromium_download() {

  # Handle parameters
  local deposit=${1:-$HOME/Downloads/DDL}
  local datadir=${2}

  # Ensure presence
  [[ -d "/Applications/Chromium.app" ]] || return 1

  # Change deposit
  defaults write org.chromium.Chromium AppleLanguages "(en-US)"
  mkdir -p "$deposit" && killall "Chromium" 2>/dev/null && sleep 4
  osascript <<-EOD
		do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
		delay 4
		tell application "Chromium"
			activate
			reopen
			delay 4
			open location "chrome://settings/"
			delay 2
			tell application "System Events"
				keystroke "before downloading"
				delay 4
				repeat 3 times
					key code 48
				end repeat
				delay 2
				key code 36
				delay 4
				key code 5 using {command down, shift down}
				delay 4
				keystroke "${deposit}"
				delay 2
				key code 36
				delay 2
				key code 36
				delay 2
				key code 48
				key code 36
			end tell
			delay 2
			quit
			delay 2
		end tell
	EOD

}

# @define Change chromium flag
# @params The chromium flag to change
# @params The payload value to set for the specified flag
# @params The user-data-dir full path, empty for default one
change_chromium_flag() {

  # Handle parameters
  local element=${1}
  local payload=${2}
  local datadir=${3}

  # Ensure presence
  [[ -d "/Applications/Chromium.app" ]] || return 1

  # Change flag
  defaults write org.chromium.Chromium AppleLanguages "(en-US)"
  killall "Chromium" 2>/dev/null && sleep 4
  if [[ "$element" == "custom-ntp" ]]; then
    osascript <<-EOD
			do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
			delay 4
			tell application "Chromium"
				activate
				reopen
				delay 4
				open location "chrome://flags/"
				delay 2
				tell application "System Events"
					keystroke "custom-ntp"
					delay 2
					repeat 4 times
						key code 48
					end repeat
					delay 2
					keystroke "a" using {command down}
					delay 1
					keystroke "${payload}"
					delay 2
					key code 48
					key code 48
					delay 2
					key code 125
					delay 2
					key code 125
					delay 2
					key code 49
				end tell
				delay 2
				quit
				delay 2
			end tell
		EOD
  elif [[ "$element" == "enable-force-dark" ]]; then
    osascript <<-EOD
			do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
			delay 4
			tell application "Chromium"
				activate
				reopen
				delay 4
				open location "chrome://flags/"
				delay 2
				tell application "System Events"
					keystroke "enable-force-dark"
					delay 2
					repeat 5 times
						key code 48
					end repeat
					delay 2
					key code 125
					delay 2
					keystroke "${payload}"
					delay 2
					key code 49
				end tell
				delay 2
				quit
				delay 2
			end tell
		EOD
  elif [[ "$element" = "extension-disable-unsupported-developer-mode-extensions" ]]; then
    osascript <<-EOD
			do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
			delay 4
			tell application "Chromium"
				activate
				reopen
				delay 4
				open location "chrome://flags/"
				delay 2
				tell application "System Events"
					keystroke "extension-disable-unsupported-developer-mode-extensions"
					delay 2
					repeat 5 times
						key code 48
					end repeat
					delay 2
					key code 125
					delay 2
					keystroke "${payload}"
					delay 2
					key code 49
				end tell
				delay 2
				quit
				delay 2
			end tell
		EOD
  elif [[ "$element" == "extension-mime-request-handling" ]]; then
    osascript <<-EOD
			do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
			delay 4
			tell application "Chromium"
				activate
				reopen
				delay 4
				open location "chrome://flags/"
				delay 2
				tell application "System Events"
					keystroke "extension-mime-request-handling"
					delay 2
					repeat 5 times
						key code 48
					end repeat
					delay 2
					key code 125
					delay 2
					keystroke "${payload}"
					delay 2
					key code 49
				end tell
				delay 2
				quit
				delay 2
			end tell
		EOD
  elif [[ "$element" == "remove-tabsearch-button" ]]; then
    osascript <<-EOD
			do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
			delay 4
			tell application "Chromium"
				activate
				reopen
				delay 4
				open location "chrome://flags/"
				delay 2
				tell application "System Events"
					keystroke "remove-tabsearch-button"
					delay 2
					repeat 5 times
						key code 48
					end repeat
					delay 2
					key code 125
					delay 2
					keystroke "${payload}"
					delay 2
					key code 49
				end tell
				delay 2
				quit
				delay 2
			end tell
		EOD
  elif [[ "$element" == "show-avatar-button" ]]; then
    osascript <<-EOD
			do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
			delay 4
			tell application "Chromium"
				activate
				reopen
				delay 4
				open location "chrome://flags/"
				delay 2
				tell application "System Events"
					keystroke "show-avatar-button"
					delay 2
					repeat 5 times
						key code 48
					end repeat
					delay 2
					key code 125
					delay 2
					keystroke "${payload}"
					delay 2
					key code 49
				end tell
				delay 2
				quit
				delay 2
			end tell
		EOD
  fi

}

# @define Change chromium default profile theme
# @params The number of times to press the right arrow key
# @params The user-data-dir full path, empty for default one
change_chromium_theme() {

  # Handle parameters
  local repeats=${1:-0}
  local datadir=${2}

  # # Change theme
  killall "Chromium" 2>/dev/null && sleep 4
  osascript <<-EOD
		do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
		delay 4
		tell application "Chromium"
			activate
			reopen
			delay 4
			open location "chrome://settings/manageProfile"
			delay 2
			tell application "System Events"
				repeat 2 times
					key code 48
				end repeat
				repeat $repeats times
					key code 124
				end repeat
				delay 2
				key code 49
			end tell
			delay 2
			quit
			delay 2
		end tell
	EOD

}

# @define Update chromium extension
# @params The payload (crx url or extension uuid)
# @params The user-data-dir full path, empty for default one
# @params The maximum age in seconds before extension is considered outdated (default: 2592000)
update_chromium_extension() {

  # Handle parameters
  local payload=${1}
  local datadir=${2:-$HOME/Library/Application Support/Chromium}
  local maximum=${3:-2592000}

  # Verify presence
  [[ ! -d "/Applications/Chromium.app" ]] && return 1

  # Verify outdated
  if [[ ${payload:0:4} == "http" ]] && [[ "$payload" == *.crx ]]; then
    local package=$(mktemp) && curl -LA "mozilla/5.0" "$payload" -o "$package" || return 1
    local key=$(python3 -c "import zipfile,json;print(zipfile.ZipFile('$package').open('manifest.json').read().decode().split('\"key\": \"')[1].split('\"')[0] if 'key' in zipfile.ZipFile('$package').open('manifest.json').read().decode() else '')" 2>/dev/null)
    local uuid=$(python3 -c "import base64,hashlib;h=hashlib.sha256(base64.b64decode('$key')).digest()[:16];a='abcdefghijklmnop';print(''.join([a[b>>4&0xF]+a[b&0xF] for b in h])[:32])" 2>/dev/null)
    [[
      $(
        stat -f %B "$datadir/Default/Extensions/$uuid"/*/manifest.json 2>/dev/null | head -n1
      ) -gt $(($(date +%s) - maximum))
    ]] &&
      return 0
  elif [[ ${payload:0:4} != "http" ]]; then
    local configs=$(ls -1t "$datadir/Default/Extensions/$payload"/*/manifest.json 2>/dev/null | head -n1)
    [[ $(stat -f %B "$configs" 2>/dev/null) -gt $(($(date +%s) - maximum)) ]] && return 0
  fi

  # Create address
  if [[ ${payload:0:4} != "http" ]]; then
    local version=$(defaults read "/Applications/Chromium.app/Contents/Info" CFBundleShortVersionString)
    local baseurl="https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx2,crx3"
    local payload="${baseurl}&prodversion=${version}&x=id%3D${payload}%26installsource%3Dondemand%26uc"
  fi

  # Update extension
  defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
  osascript <<-EOD
		do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
		delay 4
		tell application "Chromium"
			activate
			reopen
			delay 4
			open location "$payload"
			delay 4
			tell application "System Events"
				key code 125
				delay 2
				key code 49
			end tell
			delay 6
			quit
			delay 2
		end tell
	EOD

}

#endregion

#region UPGRADING

# @define Update air
update_air() {

  # Update package
  update_cask jetbrains-air

  # TODO: Change settings

  # Change appearance
  change_icon "air" "/Applications/Air.app"

}

# @define Update android-cmdline
update_android_cmdline() {

  # Handle dependencies
  update_temurin
  update_brew curl grep jq

  # Update package
  local sdkroot="$HOME/Library/Android/sdk"
  local deposit="$sdkroot/cmdline-tools"
  if [[ ! -d $deposit ]]; then
    mkdir -p "$deposit"
    local website="https://developer.android.com/studio#command-tools"
    local version="$(curl -s "$website" | ggrep -oP "commandlinetools-mac-\K(\d+)" | head -1)"
    local address="https://dl.google.com/android/repository/commandlinetools-mac-${version}_latest.zip"
    local archive="$(mktemp -d)/$(basename "$address")"
    curl -L "$address" -o "$archive"
    expand_archive "$archive" "$deposit"
    yes | "$deposit/cmdline-tools/bin/sdkmanager" --sdk_root="$sdkroot" "cmdline-tools;latest"
    rm -rf "$deposit/cmdline-tools"
  fi

  # Change environment
  append_environment "ANDROID_HOME" \
    'export ANDROID_HOME="$HOME/Library/Android/sdk"' \
    'export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"' \
    'export PATH="$PATH:$ANDROID_HOME/emulator"' \
    'export PATH="$PATH:$ANDROID_HOME/platform-tools"'
  source "$HOME/.zshrc"

}

# @define Update android-studio
update_android_studio() {

  # Handle parameters
  local deposit=${1:-$HOME/Documents}

  # Update package
  local present="$([[ -d "/Applications/Android Studio.app" ]] && echo true || echo false)"
  update_cask android-studio
  pkill -9 -f "Android Studio"

  # Finish install
  [[ "$present" == "false" ]] && invoke_once "Android Studio"

  # Change settings
  change_jetbrains_deposit "Google/AndroidStudio" "$deposit"
  change_jetbrains_scheme "Google/AndroidStudio" "Islands Dark"
  change_jetbrains_theme "Google/AndroidStudio" "Islands Dark"

  # Update plugins
  # studio installPlugins "com.github.idea-claude-code-gui"

  # Change appearance
  change_icon "android-studio" "/Applications/Android Studio.app"

}

# @define Update appearance
update_appearance() {

  # Enable dark theme
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'

  # Enable dark icons
  osascript <<-EOF
		tell application "System Settings"
			activate
			delay 1
		end tell
		tell application "System Events"
			tell process "System Settings"
				click menu item "Appearance" of menu "View" of menu bar 1
				delay 2
				tell window "Appearance"
					click button 2 of group 3 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1
				end tell
			end tell
		end tell
		quit application "System Settings"
	EOF

  # Remove tinted windows
  osascript <<-EOF
		tell application "System Settings"
			activate
			delay 1
		end tell
		tell application "System Events"
			tell process "System Settings"
				click menu item "Appearance" of menu "View" of menu bar 1
				delay 2
				tell window "Appearance"
					set theCheckbox to checkbox "Tint window background with wallpaper color" of group 4 of scroll area 1 of group 1 of group 3 of splitter group 1 of group 1
					if value of theCheckbox is 1 then
						click theCheckbox
					end if
				end tell
			end tell
		end tell
		quit application "System Settings"
	EOF

  # Change dock settings
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0.25
  defaults write com.apple.dock minimize-to-application -bool true
  defaults write com.apple.dock orientation bottom
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock size-immutable -bool yes
  defaults write com.apple.dock tilesize -int 38
  defaults write com.apple.dock wvous-bl-corner -int 0
  defaults write com.apple.dock wvous-br-corner -int 0
  defaults write com.apple.dock wvous-tl-corner -int 0
  defaults write com.apple.dock wvous-tr-corner -int 0

  # Change dock elements
  defaults delete com.apple.dock persistent-apps
  defaults delete com.apple.dock persistent-others
  append_dock_application "/Applications/Chromium.app"
  append_dock_application "/Applications/Discord.app"
  append_dock_application "/Applications/JDownloader 2/JDownloader2.app"
  append_dock_application "/Applications/Transmission.app"
  append_dock_application "/Applications/Calibre.app"
  append_dock_application "/Applications/Notion.app"
  append_dock_application "/Applications/Air.app"
  append_dock_application "/Applications/Orca.app"
  append_dock_application "/Applications/Antigravity IDE.app"
  # append_dock_application "/Applications/Visual Studio Code.app"
  append_dock_application "/Applications/IntelliJ IDEA.app"
  #  append_dock_application "/Applications/PyCharm.app"
  append_dock_application "/Applications/WebStorm.app"
  append_dock_application "/Applications/Android Studio.app"
  append_dock_application "/Applications/Xcode.app"
  append_dock_application "/Applications/Figma.app"
  append_dock_application "/Applications/Frame0.app"
  append_dock_application "/Applications/Icon Composer.app"
  append_dock_application "/Applications/IINA.app"
  append_dock_application "/Applications/CrossOver.app"
  append_dock_application "/Applications/Pearcleaner.app"
  append_dock_application "/Applications/UTM.app"
  append_dock_application "/System/Applications/Utilities/Terminal.app"
  append_dock_folder "$HOME/Downloads" 1 1 2
  append_dock_folder "$HOME/Documents" 1 1 2
  killall Dock

  # Change wallpaper
  change_wallpaper "https://github.com/olankens/codewall/raw/refs/heads/main/src/node-02.avif"

}

# @define Update antigravity
update_antigravity() {

  # Handle dependencies
  update_brew font-jetbrains-mono jq sponge

  # Update package
  update_cask antigravity-ide

  # Update extensions
  agy-ide --install-extension "dbaeumer.vscode-eslint" --force
  agy-ide --install-extension "esbenp.prettier-vscode" --force

  # Change globals
  local configs="$HOME/Library/Application Support/Antigravity IDE/User/settings.json"
  [[ -s "$configs" ]] || echo "{}" >"$configs"
  jq '."chat.disableAIFeatures" = true' "$configs" | sponge "$configs"
  jq '."editor.guides.bracketPairs" = "active"' "$configs" | sponge "$configs"
  jq '."editor.minimap.enabled" = false' "$configs" | sponge "$configs"
  jq '."security.workspace.trust.enabled" = false' "$configs" | sponge "$configs"
  jq '."telemetry.telemetryLevel" = "crash"' "$configs" | sponge "$configs"
  jq '."update.mode" = "none"' "$configs" | sponge "$configs"
  jq '."window.zoomLevel" = -0.15' "$configs" | sponge "$configs"

  # Change settings
  local configs="$HOME/Library/Application Support/Antigravity IDE/User/settings.json"
  local factors="[astro][css][javascript][javascriptreact][json][jsonc][html][md][typescript][typescriptreact][vue]"
  jq ".\"$factors\".\"editor.codeActionsOnSave\".\"source.fixAll\" = \"explicit\"" "$configs" | sponge "$configs"
  jq ".\"$factors\".\"editor.defaultFormatter\" = \"esbenp.prettier-vscode\"" "$configs" | sponge "$configs"
  jq ".\"$factors\".\"editor.formatOnSave\" = true" "$configs" | sponge "$configs"
  jq ".\"$factors\".\"editor.linkedEditing\" = true" "$configs" | sponge "$configs"
  jq ".\"$factors\".\"editor.tabSize\" = 2" "$configs" | sponge "$configs"
  jq ".\"$factors\".\"prettier.printWidth\" = 100" "$configs" | sponge "$configs"

}

# @define Update calibre
update_calibre() {

  # Update package
  update_cask calibre

  # Finish install
  invoke_once "calibre"

  # Update goodreads
  local program="/Applications/calibre.app/Contents/MacOS/calibre-customize"
  local version="1.8.3" # TODO: Scrape the latest version from github api
  local address="https://github.com/kiwidude68/calibre_plugins/releases/download/goodreads-v${version}/goodreads-v${version}.zip"
  local archive=$(mktemp -d)/$(basename "$address") && curl -LA "mozilla/5.0" "$address" -o "$archive"
  "$program" --add-plugin "$archive"
  "$program" --enable-plugin "Goodreads"

  # Change appearance
  sudo /usr/libexec/PlistBuddy -c "Set :CFBundleName Calibre" /Applications/calibre.app/Contents/Info.plist 2>/dev/null
  sudo /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Calibre" /Applications/calibre.app/Contents/Info.plist 2>/dev/null
  sudo xattr -cr /Applications/calibre.app
  sudo codesign --remove-signature /Applications/calibre.app
  sudo codesign --deep --sign - /Applications/calibre.app
  sudo mv /Applications/calibre.app /Applications/Calibre.app
  change_icon "calibre" "/Applications/Calibre.app"

}

# @define Update chromium
update_chromium() {

  # Handle parameters
  local deposit="${1:-$HOME/Downloads/DDL}"
  local tabpage="${2:-about:blank}"
  local datadir="${3:-$HOME/Library/Application Support/Chromium}"

  # Handle dependencies
  update_brew coreutils curl jq

  # Update package
  local present=$([[ (-n "$datadir" && -d "$datadir") || (-z "$datadir" && -d "/Applications/Chromium.app") ]] && echo true || echo false)
  update_cask ungoogled-chromium
  killall Chromium || true

  # Change default
  change_browser "chromium"

  # Create datadir
  [[ -n "$datadir" ]] && mkdir -p "$datadir"

  # Finish install
  if [[ "$present" == "false" ]]; then
    # Handle notifications
    open -a "/Applications/Chromium.app"
    osascript <<-EOD
			if running of application "Chromium" then tell application "Chromium" to quit
			do shell script "/usr/bin/osascript -e 'tell application \"Chromium\" to do shell script \"\"' &>/dev/null &"
			repeat 5 times
				try
					tell application "System Events"
						tell application process "UserNotificationCenter"
							click button 3 of window 1
						end tell
					end tell
				end try
				delay 1
			end repeat
			if running of application "Chromium" then tell application "Chromium" to quit
			delay 4
		EOD
    killall "Chromium" && sleep 4

    # Change settings
    change_chromium_download "$deposit" "$datadir"
    change_chromium_flag "custom-ntp" "$tabpage" "$datadir"
    change_chromium_flag "extension-disable-unsupported-developer-mode-extensions" "disabled" "$datadir"
    change_chromium_flag "extension-mime-request-handling" "always" "$datadir"
    change_chromium_flag "remove-tabsearch-button" "enabled" "$datadir"
    change_chromium_flag "show-avatar-button" "never" "$datadir"

    # Toggle bookmarks
    osascript <<-EOD
			do shell script "open -na '/Applications/Chromium.app' --args --user-data-dir='$datadir'"
			delay 4
			tell application "Chromium"
				activate
				reopen
				delay 4
				open location "about:blank"
				delay 2
				tell application "System Events"
					keystroke "b" using {shift down, command down}
				end tell
				delay 2
				quit
				delay 2
			end tell
		EOD

    # Update chromium-web-store
    local website="https://api.github.com/repos/NeverDecaf/chromium-web-store/releases"
    local version=$(curl -s "$website" | jq -r ".[0].tag_name" | tr -d "v")
    local address="https://github.com/NeverDecaf/chromium-web-store/releases/download/v$version/Chromium.Web.Store.crx"
    update_chromium_extension "$address" "$datadir"
  fi

  # Update extensions
  if [[ -z "$datadir" || "$datadir" == "$HOME/Library/Application Support/Chromium" ]]; then
    update_chromium_extension "bcjindcccaagfpapjjmafapmmgkkhgoa" # json-formatter
    update_chromium_extension "bjogjfinolnhfhkbipphpdlldadpnmhc" # seo-meta-in-1-click
    update_chromium_extension "cjpalhdlnbpafiamejdnhcphjbkeiagm" # ublock-origin
    update_chromium_extension "enocadmdedhoajldcnlajbjaihpkccml" # freedium-link-converter
    update_chromium_extension "ibplnjkanclpjokhdolnendpplpjiace" # simple-translate
    update_chromium_extension "mnjggcdmjocbbbhaepdhchncahnbgone" # sponsorblock-for-youtube
    update_chromium_extension "nngceckbapebfimnlniiiahkandclblb" # bitwarden-password-manage
    update_chromium_extension "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass-paywalls-chrome-clean-latest.crx"
  fi

  # Change appearance
  change_icon "chromium" "/Applications/Chromium.app"

}

# @define Update chromium debug
update_chromium_debug() {

  # Handle parameters
  local deposit="${1:-$HOME/Downloads/DDL}"
  local tabpage="${2:-about:blank}"
  local datadir="${3:-$HOME/Library/Application Support/Chromium Debug}"

  # Update package
  local present=$([[ (-n "$datadir" && -d "$datadir") || (-z "$datadir" && -d "/Applications/Chromium.app") ]] && echo true || echo false)
  update_chromium "$deposit" "$tabpage" "$datadir"

  # Change theme
  [[ "$present" == "false" ]] && change_chromium_theme 8 "$datadir" # citron

  # Update extensions
  update_chromium_extension "bcjindcccaagfpapjjmafapmmgkkhgoa" "$datadir" # json-formatter
  update_chromium_extension "blipmdconlkpinefehnmjammfjpmpbjk" "$datadir" # lighthouse

}

# @define Update claude-code
update_claude_code() {

  # Handle dependencies
  update_nodejs
  update_brew jq sponge

  # Update package
  npm install -g @anthropic-ai/claude-code

  # Finish install
  local configs="$HOME/.claude.json" && mkdir -p "$(dirname "$configs")"
  [[ -s "$configs" ]] || echo "{}" >"$configs"
  jq '.hasCompletedOnboarding = true' "$configs" | sponge "$configs"

  # Change settings
  local configs="$HOME/.claude/settings.json" && mkdir -p "$(dirname "$configs")"
  [[ -s "$configs" ]] || echo "{}" >"$configs"
  jq '.includeCoAuthoredBy = false' "$configs" | sponge "$configs"

}

# @define Update claude-code-zai
update_claude_code_zai() {

  # Handle dependencies
  update_claude_code

  # Change settings
  local configs="$HOME/.claude/settings.json" && mkdir -p "$(dirname "$configs")"
  [[ -s "$configs" ]] || echo "{}" >"$configs"
  jq '.env = {
    ANTHROPIC_AUTH_TOKEN: (.env.ANTHROPIC_AUTH_TOKEN // "your_zai_api_key"),
    ANTHROPIC_BASE_URL: "https://api.z.ai/api/anthropic",
    API_TIMEOUT_MS: "3000000",
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: 1,
    ANTHROPIC_DEFAULT_OPUS_MODEL: "glm-5.2",
    ANTHROPIC_DEFAULT_SONNET_MODEL: "glm-4.7",
    ANTHROPIC_DEFAULT_HAIKU_MODEL: "glm-4.5-air"
  }' "$configs" | sponge "$configs"

}

# @define Update codex
update_codex() {

  # Update package
  update_cask codex

  # TODO: Change settings

}

# @define Update crossover
update_crossover() {

  # Update package
  local present="$([[ -d "/Applications/CrossOver.app" ]] && echo true || echo false)"
  update_cask crossover

  # Change settings
  defaults write com.codeweavers.CrossOver AskForRatings -bool false
  defaults write com.codeweavers.CrossOver SUAutomaticallyUpdate -bool false
  defaults write com.codeweavers.CrossOver SUEnableAutomaticChecks -bool false
  defaults write com.codeweavers.CrossOver SUHasLaunchedBefore -bool true

  # Finish install
  [[ "$present" == "false" ]] && invoke_once "CrossOver"
  setopt nullglob && local bottles=("$HOME/Library/Application Support/CrossOver/Bottles"/*)
  while true; do
    pids=$(pgrep -f "CrossOver")
    [ -z "$pids" ] && break
    kill -9 "$pids" >/dev/null 2>&1
    sleep 4
  done
  local configs="$HOME/Library/Preferences/com.codeweavers.CrossOver.plist"
  while /usr/libexec/PlistBuddy -c "Print :FirstRunDate" "$configs" &>/dev/null; do
    defaults delete com.codeweavers.CrossOver FirstRunDate
    plutil -remove FirstRunDate "$configs" &>/dev/null
    sleep 2
  done
  IFS=$'\n'
  find "$bottles" -type d -maxdepth 0 -print0 | while IFS= read -r -d '' i; do
    [ -d "$i" ] || continue
    while grep -q '\[Software\\\\CodeWeavers\\\\CrossOver\\\\cxoffice\]' "$i/system.reg"; do
      sed -i '' '/\[Software\\\\CodeWeavers\\\\CrossOver\\\\cxoffice\].*/,+5d' "$i/system.reg"
      sleep 1
    done
  done

  # Change appearance
  change_icon "crossover" "/Applications/CrossOver.app"

}

# @define Update discord
update_discord() {

  # Update package
  update_cask discord

  # Change appearance
  change_icon "discord" "/Applications/Discord.app"

}

# @define Update docker
update_docker() {

  # Handle dependencies
  update_brew colima docker-buildx docker-compose jq sponge

  # Update package
  update_brew docker

  # Finish install
  colima start && colima stop

  # Change settings
  local configs="$HOME/.docker/config.json"
  jq '. + {cliPluginsExtraDirs: ["/opt/homebrew/lib/docker/cli-plugins"]}' "$configs" | sponge "$configs"

  # TODO: Make colima docker working with dev containers

}

# @define Update draw-things
update_draw_things() {

  # Update package
  update_brew drawthingsai/draw-things/draw-things-cli
  update_cask draw-things

}

# @define Update figma
update_figma() {

  # Handle dependencies
  update_brew jq sponge

  # Update package
  update_cask figma

  # Change settings
  local configs="$HOME/Library/Application Support/Figma/settings.json"
  jq '.showFigmaInMenuBar = false' "$configs" | sponge "$configs"

  # Change appearance
  change_icon "figma" "/Applications/Figma.app"

}

# @define Update flutter
update_flutter() {

  # Update dependencies
  update_brew dart

  # Update package
  update_cask flutter

  # Finish install
  flutter precache && flutter upgrade
  dart --disable-analytics
  flutter config --no-analytics
  yes | flutter doctor --android-licenses

  # Change environment
  if [[ -d "/Applications/Chromium.app" ]]; then
    append_environment "CHROME_EXECUTABLE" 'export CHROME_EXECUTABLE="/Applications/Chromium.app/Contents/MacOS/Chromium"'
  fi

}

# @define Update frame0
update_frame0() {

  # Update package
  update_cask frame0

  # Change association
  local address="https://api.github.com/repos/jdek/openwith/releases/latest"
  local version=$(curl -LA "mozilla/5.0" "$address" | jq -r ".tag_name" | tr -d "v")
  local address="https://github.com/jdek/openwith/releases/download/v$version/openwith-v$version.tar.xz"
  local archive=$(mktemp -d)/$(basename "$address") && curl -LA "mozilla/5.0" "$address" -o "$archive"
  local deposit=$(mktemp -d)
  expand_archive "$archive" "$deposit"
  "$deposit/openwith" com.electron.frame0 f0

  # Change appearance
  change_icon "frame0" "/Applications/Frame0.app"

}

# @define Update git
update_git() {

  # Handle parameters
  local default=${1:-main}
  local gituser=${2}
  local gitmail=${3}

  # Update package
  update_brew gh git

  # Change settings
  [[ -n "$gitmail" ]] && git config --global user.email "$gitmail"
  [[ -n "$gituser" ]] && git config --global user.name "$gituser"
  git config --global checkout.workers 0
  git config --global credential.helper "store"
  git config --global http.postBuffer 1048576000
  git config --global init.defaultBranch "$default"
  git config --global pull.rebase true
  git config --global push.autoSetupRemote true

}

# @define Update handy
update_handy() {

  # Update package
  local present="$([[ -d "/Applications/Handy.app" ]] && echo "true" || echo "false")"
  update_cask handy

  # Finish install
  [[ "$present" == "false" ]] && invoke_once "Handy"

  # Change settings
  local configs="$HOME/Library/Application Support/com.pais.handy/settings_store.json"
  jq '.settings.autostart_enabled = true' "$configs" | sponge "$configs"
  jq '.settings.overlay_position = "top"' "$configs" | sponge "$configs"
  jq '.settings.push_to_talk = false' "$configs" | sponge "$configs"
  jq '.settings.start_hidden = true' "$configs" | sponge "$configs"

}

# @define Update homebrew
update_homebrew() {

  # Handle dependencies
  command -v xcodebuild >/dev/null 2>&1 && sudo xcodebuild -license accept

  # Update package
  local command=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
  CI=1 /bin/bash -c "$command" &>/dev/null

  # Change environment
  local configs="$HOME/.zprofile"
  if ! grep -q "/opt/homebrew/bin/brew shellenv" "$configs" 2>/dev/null; then
    [[ -s "$configs" ]] || printf "#!/bin/zsh" >"$configs"
    perl -i -0777 -pe "s/\n*\z/\n/s" "$configs" 2>/dev/null || true
    printf "\n%s" "# Invoke homebrew environment" >>"$configs"
    printf "\n%s\n" 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$configs"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  # Change settings
  brew analytics off

}

# @define Update icon-composer
update_icon_composer() {

  # Update package
  update_cask icon-composer

}

# @define Update iina
update_iina() {

  # Update dependencies
  update_brew curl jq

  # Update package
  local present=$([[ -d "/Applications/IINA.app" ]] && echo "true" || echo "false")
  update_cask iina

  # Finish install
  if [[ "$present" == "false" ]]; then
    osascript <<-EOD
			set checkup to "/Applications/IINA.app"
			tell application checkup
				activate
				reopen
				tell application "System Events"
					with timeout of 10 seconds
						repeat until (exists window 1 of application process "IINA")
							delay 0.02
						end repeat
						tell application process "IINA" to set visible to false
					end timeout
				end tell
				delay 4
				quit
				delay 4
			end tell
		EOD
    update_chromium_extension "pdnojahnhpgmdhjdhgphgdcecehkbhfo"
  fi

  # Change settings
  defaults write com.colliderli.iina recordPlaybackHistory -integer 0
  defaults write com.colliderli.iina recordRecentFiles -integer 0
  defaults write com.colliderli.iina SUEnableAutomaticChecks -integer 0
  defaults write com.colliderli.iina ytdlSearchPath "/usr/local/bin"

  # Change association
  local address="https://api.github.com/repos/jdek/openwith/releases/latest"
  local version=$(curl -LA "mozilla/5.0" "$address" | jq -r ".tag_name" | tr -d "v")
  local address="https://github.com/jdek/openwith/releases/download/v$version/openwith-v$version.tar.xz"
  local archive=$(mktemp -d)/$(basename "$address") && curl -LA "mozilla/5.0" "$address" -o "$archive"
  local deposit=$(mktemp -d)
  expand_archive "$archive" "$deposit"
  "$deposit/openwith" com.colliderli.iina mkv mov mp4 avi

  # Change appearance
  change_icon "iina" "/Applications/IINA.app"

}

# @define Update intellij-idea
update_intellij_idea() {

  # Handle parameters
  local deposit=${1:-$HOME/Documents}

  # Update package
  local present="$([[ -d "/Applications/IntelliJ IDEA.app" ]] && echo "true" || echo "false")"
  update_cask intellij-idea
  pkill -9 -f "IntelliJ IDEA"

  # Finish install
  [[ "$present" == "false" ]] && invoke_once "IntelliJ IDEA"

  # Change settings
  change_jetbrains_deposit "JetBrains/IntelliJIdea" "$deposit"
  change_jetbrains_scheme "JetBrains/IntelliJIdea" "Islands Dark"
  change_jetbrains_theme "JetBrains/IntelliJIdea" "Islands Dark"

  # Update plugins
  idea installPlugins "org.jetbrains.junie"

  # Change appearance
  change_icon "intellij-idea" "/Applications/IntelliJ IDEA.app"

}

# @define Update jdownloader
update_jdownloader() {

  # Handle parameters
  local deposit=${1:-$HOME/Downloads/JD2}

  # Handle dependencies
  update_brew coreutils curl fileicon jq

  # Update package
  local present="$([[ -d "/Applications/JDownloader 2/JDownloader2.app" ]] && echo "true" || echo "false")"
  update_cask jdownloader

  # Finish install
  local appdata="/Applications/JDownloader 2/cfg"
  local config1="$appdata/org.jdownloader.settings.GraphicalUserInterfaceSettings.json"
  local config2="$appdata/org.jdownloader.settings.GeneralSettings.json"
  local config3="$appdata/org.jdownloader.gui.jdtrayicon.TrayExtension.json"
  local config4="$appdata/org.jdownloader.extensions.extraction.ExtractionExtension.json"
  osascript <<-EOD
		set checkup to "/Applications/JDownloader 2/JDownloader2.app"
		tell application checkup
			activate
			reopen
			tell application "System Events"
				repeat until (exists window 1 of application process "JDownloader2")
					delay 0.02
				end repeat
				tell application process "JDownloader2" to set visible to false
				repeat until (do shell script "test -f '$config1' && echo true || echo false") as boolean is true
					delay 1
				end repeat
			end tell
			delay 8
			quit
			delay 4
		end tell
	EOD
  jq ".bannerenabled = false" "$config1" | sponge "$config1"
  jq ".clipboardmonitored = false" "$config1" | sponge "$config1"
  jq ".donatebuttonlatestautochange = 4102444800000" "$config1" | sponge "$config1"
  jq ".donatebuttonstate = \"AUTO_HIDDEN\"" "$config1" | sponge "$config1"
  jq ".myjdownloaderviewvisible = false" "$config1" | sponge "$config1"
  jq ".premiumalertetacolumnenabled = false" "$config1" | sponge "$config1"
  jq ".premiumalertspeedcolumnenabled = false" "$config1" | sponge "$config1"
  jq ".premiumalerttaskcolumnenabled = false" "$config1" | sponge "$config1"
  jq ".specialdealoboomdialogvisibleonstartup = false" "$config1" | sponge "$config1"
  jq ".specialdealsenabled = false" "$config1" | sponge "$config1"
  jq ".speedmetervisible = false" "$config1" | sponge "$config1"
  mkdir -p "$deposit" && jq ".defaultdownloadfolder = \"$deposit\"" "$config2" | sponge "$config2"
  jq ".enabled = false" "$config3" | sponge "$config3"
  jq ".enabled = false" "$config4" | sponge "$config4"
  # update_chromium_extension "fbcohnmimjicjdomonkcbcpbpnhggkip"

  # Changes icons
  local address="https://github.com/olankens/nightwyn/raw/refs/heads/main/source/jdownloader/jdownloader.icns"
  local picture="$(mktemp -d)/$(basename "$address")"
  curl -LA "mozilla/5.0" "$address" -o "$picture"
  fileicon set "/Applications/JDownloader 2/JDownloader2.app" "$picture" || sudo !!
  fileicon set "/Applications/JDownloader 2/Uninstall JDownloader.app" "$picture" || sudo !!
  cp "$picture" "/Applications/JDownloader 2/JDownloader2.app/Contents/Resources/app.icns"
  local sitting="/Applications/JDownloader 2/themes/standard/org/jdownloader/images/logo/jd_logo_128_128.png"
  sips -Z 128 -s format png "$picture" --out "$sitting"

}

# @define Update joal-desktop
update_joal_desktop() {

  # Handle dependencies
  brew install curl grep jq
  brew upgrade curl grep jq

  # Update package
  # local present="$([[ -d "/Applications/Joal Desktop.app" ]] && echo "true" || echo "false")"
  local address="https://api.github.com/repos/anthonyraymond/joal-desktop/releases/latest"
  local version=$(curl -LA "mozilla/5.0" "$address" | jq -r ".tag_name" | tr -d "v")
  local current=$(gather_version "/*ppl*/*oal*esk*")
  autoload is-at-least
  local updated=$(is-at-least "$version" "$current" && echo "true" || echo "false")
  if [[ "$updated" == "false" ]]; then
    local address="https://github.com/anthonyraymond/joal-desktop/releases"
    local address="$address/download/v$version/JoalDesktop-$version-mac-x64.dmg"
    local package=$(mktemp -d)/$(basename "$address") && curl -LA "mozilla/5.0" "$address" -o "$package"
    hdiutil attach "$package" -noautoopen -nobrowse
    cp -fr /Volumes/Joal*/Joal*.app /Applications
    hdiutil detach /Volumes/Joal*
    sudo xattr -rd com.apple.quarantine /Applications/Joal*.app
  fi

  # Change settings
  local configs="$HOME/Library/Application Support/JoalDesktop/joal-core/config.json"
  mkdir -p "$(dirname "$configs")"
  [[ -s "$configs" ]] || echo "{}" >"$configs"
  jq '."minUploadRate" = 300' "$configs" | sponge "$configs"
  jq '."maxUploadRate" = 450' "$configs" | sponge "$configs"
  jq '."simultaneousSeed" = 200' "$configs" | sponge "$configs"
  jq '."client" = "transmission-3.00.client"' "$configs" | sponge "$configs"
  jq '."keepTorrentWithZeroLeechers" = true' "$configs" | sponge "$configs"
  jq '."uploadRatioTarget" = -1' "$configs" | sponge "$configs"

  # Change appearance
  change_icon "joal-desktop" "/Applications/JoalDesktop.app"

}

# @define Update keepingyouawake
update_keepingyouawake() {

  # Update package
  update_cask keepingyouawake

}

# @define Update keka
update_keka() {

  # Update package
  update_cask keka kekaexternalhelper

  # Finish install
  /Applications/KekaExternalHelper.app/Contents/MacOS/KekaExternalHelper --set-as-default

}

# @define Update miniforge
update_miniforge() {

  # Update package
  update_cask miniforge

  # Change settings
  conda init zsh
  conda config --set auto_activate_base false

}

# @define Update mole
update_mole() {

  # Update package
  update_brew tw93/tap/mole

}

# @define Update nightlight
update_nightlight() {

  # Handle parameters
  local percent=${1:-60}
  local forever=${2:-true}

  # Update package
  update_brew smudge/smudge/nightlight

  # Change settings
  [[ "$forever" == "true" ]] && nightlight schedule 3:00 2:59
  nightlight temp "$percent" && nightlight on

}

# @define Update nodejs
update_nodejs() {

  # Handle dependencies
  update_brew curl grep jq

  # Update package
  local address="https://raw.githubusercontent.com/scoopinstaller/main/master/bucket/nodejs-lts.json"
  local version="$(curl -LA "mozilla/5.0" "$address" | jq '.version' | ggrep -oP "[\d]+" | head -1)"
  update_brew node@"$version"

  # Change environment
  append_environment "/opt/homebrew/opt/node" "export PATH=\"\$PATH:/opt/homebrew/opt/node@$version/bin\""
  sed -i "" -e "s#/opt/homebrew/opt/node.*/bin#/opt/homebrew/opt/node@$version/bin#" "$HOME/.zshrc"
  source "$HOME/.zshrc"

  # Update pnpm
  corepack enable && corepack install -g pnpm@latest

}

# @define Update notion
update_notion() {

  # Handle dependencies
  update_brew coreutils jq

  # Update package
  local present="$([[ -d "/Applications/Notion.app" ]] && echo "true" || echo "false")"
  update_cask notion

  # Finish install
  [[ "$present" == "false" ]] && ninvoke_once "Notion"

  # Change settings
  local configs="$HOME/Library/Application Support/Notion/state.json"
  mkdir -p "$(dirname "$configs")"
  [[ -s "$configs" ]] || echo "{}" >"$configs"
  jq '.appState.preferences.isMenuBarIconEnabled = false' "$configs" | sponge "$configs"
  jq '.appState.preferences.isAutoUpdaterDisabled = true' "$configs" | sponge "$configs"

  # Change appearance
  change_icon "notion" "/Applications/Notion.app"

}

# @define Update orca
update_orca() {

  # Update package
  update_cask stablyai/orca/orca

  # TODO: Change settings

}

# @define Update pearcleaner
update_pearcleaner() {

  # Update package
  update_cask pearcleaner

  # Change appearance
  change_icon "pearcleaner" "/Applications/Pearcleaner.app"

}

# @define Update postgresql
update_postgresql() {

  # Handle parameters
  local version=${1:-17}

  # Update package
  update_brew postgresql@"$version"

  # Launch service
  # INFO: Default credentials are $USER with empty password
  brew services restart postgresql@"$version"

}

# @define Update pycharm
update_pycharm() {

  # Handle parameters
  local deposit=${1:-$HOME/Documents}

  # Update package
  local present="$([[ -d "/Applications/PyCharm.app" ]] && echo true || echo false)"
  update_cask pycharm
  pkill -9 -f "PyCharm"

  # Finish install
  [[ "$present" == "false" ]] && invoke_once "PyCharm"

  # Change settings
  change_jetbrains_deposit "JetBrains/PyCharm" "$deposit"
  change_jetbrains_scheme "JetBrains/PyCharm" "Islands Dark"
  change_jetbrains_theme "JetBrains/PyCharm" "Islands Dark"

  # Update plugins
  pycharm installPlugins "org.jetbrains.junie"

  # Change appearance
  change_icon "pycharm" "/Applications/PyCharm.app"

}

# @define Update system
update_system() {

  # Change finder
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults write com.apple.finder ShowPathbar -bool true

  # Change globals
  defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

  # Change preview
  defaults write com.apple.Preview NSRecentDocumentsLimit 0
  defaults write com.apple.Preview NSRecentDocumentsLimit 0

  # Change screencapture
  defaults write com.apple.screencapture disable-shadow -bool true

  # Change services
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true
  defaults write com.apple.LaunchServices "LSQuarantine" -bool false

  # Enable autosuggestions
  update_brew zsh-autosuggestions
  append_environment "autosuggestions" \
    "autoload -Uz compinit && compinit" \
    "source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh"

  # Enable firewall
  # sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1

  # Enable tap-to-click
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

  # Remove last login message
  touch ~/.hushlogin

  # Remove remnants
  find ~ -name ".DS_Store" -delete

  # Remove chime
  sudo nvram StartupMute=%01

  # Update rosetta
  /usr/sbin/softwareupdate --install-rosetta --agree-to-license &>/dev/null

  # Update system
  # sudo softwareupdate --download --all --force --agree-to-license --verbose

}

# @define Update temurin
update_temurin() {

  # Update package
  update_cask temurin

}

# @define Update transmission
update_transmission() {

  # Handle parameters
  local deposit=${1:-$HOME/Downloads/P2P}
  local seeding=${2:-0.1}

  # Update package
  update_cask transmission

  # Change settings
  mkdir -p "$deposit/Incompleted"
  defaults write org.m0k.transmission DownloadFolder -string "$deposit"
  defaults write org.m0k.transmission DownloadLocationConstant -int "1"
  defaults write org.m0k.transmission IncompleteDownloadFolder -string "$deposit/Incompleted"
  defaults write org.m0k.transmission RatioCheck -bool true
  defaults write org.m0k.transmission RatioLimit -int "$seeding"
  defaults write org.m0k.transmission UseIncompleteDownloadFolder -bool true
  defaults write org.m0k.transmission WarningDonate -bool false
  defaults write org.m0k.transmission WarningLegal -bool false

  # Change appearance
  change_icon "transmission" "/Applications/Transmission.app"

}

# @define Update utm
update_utm() {

  # Update package
  update_cask utm

}

# @define Update webstorm
update_webstorm() {

  # Handle parameters
  local deposit=${1:-$HOME/Documents}

  # Update package
  local present="$([[ -d "/Applications/WebStorm.app" ]] && echo true || echo false)"
  update_cask webstorm
  pkill -9 -f "WebStorm"

  # Finish install
  [[ "$present" == "false" ]] && invoke_once "WebStorm"

  # Change settings
  change_jetbrains_deposit "JetBrains/WebStorm" "$deposit"
  change_jetbrains_scheme "JetBrains/WebStorm" "Islands Dark"
  change_jetbrains_theme "JetBrains/WebStorm" "Islands Dark"

  # Update plugins
  webstorm installPlugins "io.github.lukmccall.better-exclude"
  webstorm installPlugins "org.jetbrains.junie"

  # Change appearance
  change_icon "webstorm" "/Applications/WebStorm.app"

}

# @define Update xcode
update_xcode() {

  # Handle parameters
  local version=${1:-26.0}

  # Handle dependencies
  update_brew cocoapods grep xcodesorg/made/xcodes

  # Verify credentials
  [[ -z "$XCODES_USERNAME" || -z "$XCODES_PASSWORD" ]] && return 1

  # Update package
  xcodes install "$version"

  # Finish install
  sudo xcode-select --switch "/Applications/Xcode.app/Contents/Developer"
  sudo xcodebuild -runFirstLaunch
  sudo xcodebuild -license accept

}

#endregion

#region DEVELOPER

update_devtools_android() {

  # Handle parameters
  local version=${1:-36}

  # Handle dependencies
  update_android_cmdline
  update_android_studio
  update_brew apktool bundletool jadx scrcpy

  # Update sdks
  yes | sdkmanager "cmdline-tools;latest"
  yes | sdkmanager "build-tools;${version}.0.0"
  yes | sdkmanager "emulator"
  yes | sdkmanager "platform-tools"
  yes | sdkmanager "platforms;android-${version}"
  yes | sdkmanager "sources;android-${version}"
  yes | sdkmanager "system-images;android-${version};google_apis;arm64-v8a"
  yes | sdkmanager --licenses
  yes | sdkmanager --update

  # Create emulators
  avdmanager create avd -n "Pixel_7a_API_${version}" -d "pixel_7a" -k "system-images;android-${version};google_apis;arm64-v8a" -f

  # Update studio extensions
  studio installPlugins "com.github.airsaid.androidlocalize"
  studio installPlugins "io.kotzilla.koin"

}

update_devtools_angular() {

  # Handle parameters
  local datadir="${1:-$HOME/Library/Application Support/Chromium Debug}"

  # Handle dependencies
  update_antigravity
  update_chromium_debug
  update_nodejs
  update_webstorm

  # Update angular
  export NG_CLI_ANALYTICS="ci" && npm i -g @angular/cli
  ng analytics off

  # Change environment
  append_environment "ng completion script" "source <(ng completion script)"
  source "$HOME/.zshrc"

  # Update antigravity
  agy-ide --install-extension "angular.ng-template"
  agy-ide --install-extension "bradlc.vscode-tailwindcss"
  agy-ide --install-extension "mikestead.dotenv"
  agy-ide --install-extension "usernamehw.errorlens"
  agy-ide --install-extension "yoavbls.pretty-ts-errors"

  # Update chromium
  update_chromium_extension "ienfalfjdbdpebioblfackkekamfmbnh" "$datadir" # angular-devtools
  update_chromium_extension "kgpbgfjgjanmdcoefmofbmlhhkmeipng" "$datadir" # angulariad

  # Update webstorm
  idea installPlugins "com.github.ahmedwelhakim.ngxtranslateintellisense"
  idea installPlugins "com.github.dinbtechit.ngxs"

}

update_devtools_apple() {

  # Handle dependencies
  update_xcode

  # Update platforms
  xcodebuild -downloadPlatform iOS

}

update_devtools_astro() {

  # Handle dependencies
  update_antigravity
  update_chromium_debug
  update_nodejs
  update_webstorm

  # Update antigravity
  agy-ide --install-extension "astro-build.astro-vscode"

  # Update webstorm
  webstorm installPlugins "org.jetbrains.plugins.astro"

}

update_devtools_bash() {

  # Handle dependencies
  update_antigravity
  update_intellij_idea
  update_brew shellcheck shfmt

  # Update antigravity
  agy-ide --install-extension "mads-hartmann.bash-ide-vscode"

  # Update idea
  idea installPlugins "pro.bashsupport"

}

update_devtools_flutter() {

  # Handle dependencies
  update_devtools_android
  update_devtools_apple
  update_antigravity
  update_flutter

  # Update antigravity
  agy-ide --install-extension "dart-code.flutter"
  agy-ide --install-extension "pflannery.vscode-versionlens"
  agy-ide --install-extension "usernamehw.errorlens"
  local configs="$HOME/Library/Application Support/Antigravity IDE/User/settings.json"
  jq '."[dart]"."editor.codeActionsOnSave"."source.fixAll" = "explicit"' "$configs" | sponge "$configs"
  jq '."[dart]"."editor.codeActionsOnSave"."source.organizeImports" = "explicit"' "$configs" | sponge "$configs"
  jq '."[dart]"."editor.defaultFormatter" = "Dart-Code.dart-code"' "$configs" | sponge "$configs"

  # Update studio
  studio installPlugins "Dart"
  studio installPlugins "com.github.skleprozzz.intellijfluttercleanfeature"
  studio installPlugins "io.flutter"
  studio installPlugins "shop.itbug.FlutterCheckVersionX"

  # TODO: Add `readlink -f $(which flutter)` to studio
  # NOTE: /usr/local/Caskroom/flutter/*/flutter

}

update_devtools_kmm() {

  # Handle dependencies
  update_devtools_android
  update_devtools_apple

  # Update studio plugins
  studio installPlugins "com.intellij.marketplace"
  studio installPlugins "com.jetbrains.kmm"

}

update_devtools_nestjs() {

  # Handle dependencies
  update_antigravity
  update_docker
  update_nodejs
  update_webstorm

  # Update antigravity
  agy-ide --install-extension "mikestead.dotenv"
  agy-ide --install-extension "usernamehw.errorlens"
  agy-ide --install-extension "yoavbls.pretty-ts-errors"

  # Update webstorm
  webstorm installPlugins "com.github.dinbtechit.jetbrainsnestjs"

}

update_devtools_spring() {

  # Handle dependencies
  update_antigravity
  update_docker
  update_intellij_idea
  update_brew spring-io/tap/spring-boot

  # Update antigravity
  agy-ide --install-extension "vmware.vscode-spring-boot"
  local configs="$HOME/Library/Application Support/Antigravity IDE/User/settings.json"
  jq '."redhat.telemetry.enabled" = false' "$configs" | sponge "$configs"

  # Update idea
  idea installPlugins "com.intellij.spring.debugger"
  idea installPlugins "com.intellij.spring.messaging"
  # idea installPlugins "dev.eltonsandre.kafka"
  # idea installPlugins "org.elasticsearch4idea"

}

#endregion

main() {

  [[ "$ZSH_EVAL_CONTEXT" != *:file || "$TERM_PROGRAM" == "vscode" || $(ps -p $PPID -o comm=) =~ idea ]] || return 0

  read -r -d "" welcome <<-EOD
		mmm  mmm     mm        mmmm   mmmmmmmm  mmmmmm    mmmmmmmm    mmmm    mm    mm
		###  ###    ####     ##""""#  ##""""""  ##""""##  ##""""""  m#""""#   ##    ##
		########    ####    ##"       ##        ##    ##  ##        ##m       ##    ##
		## ## ##   ##  ##   ##        #######   #######   #######    "####m   ########
		## "" ##   ######   ##m       ##        ##  "##m  ##             "##  ##    ##
		##    ##  m##  ##m   ##mmmm#  ##        ##    ##  ##mmmmmm  #mmmmm#"  ##    ##
		""    ""  ""    ""     """"   ""        ""    """ """"""""   """""    ""    ""
	EOD

  local country="Europe/Brussels"
  local machine="macintosh"

  local members=(
    "update_homebrew"
    "update_system"
    #
    "update_air"
    "update_android_cmdline"
    "update_android_studio"
    "update_antigravity"
    "update_calibre"
    "update_chromium"
    "update_chromium_debug"
    "update_claude_code"
    "update_claude_code_zai"
    # "update_codex"
    "update_crossover"
    "update_discord"
    "update_docker"
    "update_draw_things"
    "update_figma"
    "update_flutter"
    "update_frame0"
    "update_git 'main' 'olankens' 'olankens@users.noreply.github.com'"
    # "update_handy"
    "update_icon_composer"
    "update_iina"
    "update_intellij_idea"
    "update_jdownloader"
    # "update_joal_desktop"
    "update_keepingyouawake"
    "update_keka"
    "update_miniforge"
    "update_mole"
    "update_nightlight"
    "update_nodejs"
    "update_notion"
    "update_pearcleaner"
    # "update_postgresql"
    # "update_pycharm"
    # "update_orca"
    "update_temurin"
    "update_transmission"
    "update_utm"
    "update_webstorm"
    "update_xcode"
    #
    "update_devtools_android"
    "update_devtools_angular"
    "update_devtools_apple"
    "update_devtools_astro"
    "update_devtools_bash"
    "update_devtools_flutter"
    "update_devtools_kmm"
    "update_devtools_nestjs"
    "update_devtools_spring"
    #
    "update_appearance"
  )

  invoke_wrapper "$welcome" "$country" "$machine" "${members[@]}"

}

main "$@"
