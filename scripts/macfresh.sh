#!/bin/zsh

# shellcheck disable=SC1091,SC2005,SC2016,SC2059,SC2128,SC2155,SC2178
# shellcheck shell=bash

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

# @define Change default application for file type
# @params The application bundle id, app name or path to .app bundle
# @params The file target bare extension, explicit extension, uniform id, url scheme or file path
change_association() {

	# Handle parameters
	local application="${1}"
	local target="${2}"

	# Update dependencies
	update_brew jmarette/tap/openwith

	# Handle association
	openwith set "$target" "$application" &

	# Handle dialogs
	local process=$!
	while kill -0 "$process" 2>/dev/null; do
		osascript <<-'EOF'
			tell application "System Events"
				tell process "CoreServicesUIAgent"
					repeat with w in windows
						repeat with b in buttons of w
							try
								if (name of b starts with "Use ") then
									click b
									return
								end if
							end try
						end repeat
					end repeat
				end tell
			end tell
		EOF
		sleep 0.5
	done
	wait "$process"

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
	local address="https://github.com/olankens/macatoni/raw/refs/heads/main/source/$distant/$distant.icns"
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
# @params The maximum wait time (seconds) for the first window
invoke_once() {

	# Handle parameters
	local element="${1}"
	local process="${2:-$1}"
	local timeout="${3:-20}"

	# Handle extinction
	pkill -9 -f "$element" 2>/dev/null
	sleep 2 && open -a "/Applications/${element}.app"

	# Handle gatekeeper
	osascript -e 'tell application "System Events" to tell process "CoreServicesUIAgent" to repeat 10 times
        try
            set frontmost to true
            tell window 1
                set bs to buttons whose description is "button"
                perform action "AXPress" of item 2 of bs
                exit repeat
            end tell
        end try
        delay 0.5
    end repeat'

	# Handle initialization
	local i=0 && while ! osascript -e "tell application \"System Events\" to tell process \"${process}\" to exists window 1" 2>/dev/null | grep -q true; do
		sleep 1
		((i++))
		[[ "$i" -ge "$timeout" ]] && return 1
	done

	# Handle extinction
	sleep 2 && osascript -e "tell application \"${process}\" to quit" 2>/dev/null
	sleep 2 && pkill -9 -f "$element" 2>/dev/null

}

# @define Invoke functions with a welcome message and tracks time
# @params The heading title
# @params The maximum length
# @params The project version
# @params The project website
# @params The timezone string
# @params The machine hostname
# @params The functions to invoke in sequence
invoke_wrapper() {

	# Handle parameters
	local heading="${1}"
	local maximum="${2}"
	local version="${3}"
	local website="${4}"
	local country="${5}"
	local machine="${6}"
	local members=("${@:7}")
	local bigness=${#members[@]}

	# Change headline
	printf "\033[22;0t" && clear && printf "\033]0;%s\007" "$heading"

	# Handle colors
	local subdued_ansi=$'\033[2m'
	local website_ansi=$'\033[34;4m'
	local loading_ansi=$'\033[93m'
	local success_ansi=$'\033[92m'
	local failure_ansi=$'\033[91m'
	local refresh_ansi=$'\033[0m'

	# Handle widths
	local heading_width=$((maximum - 23))
	local version_width=16
	local logfile_width=$(((maximum - 19) / 2))
	local website_width=$(((maximum - 19) - logfile_width))

	# Handle borders
	printf -v spacing '%*s' "$maximum" ''
	local heading_line="${spacing[1, $((heading_width + 2))]}"
	local version_line="${spacing[1, $((version_width + 2))]}"
	local counter_line="${spacing[1, 7]}"
	local runtime_line="${spacing[1, 10]}"
	local caption_line="${spacing[1, 5]}"
	local logfile_line="${spacing[1, $((logfile_width + 2))]}"
	local website_line="${spacing[1, $((website_width + 2))]}"
	# @formatter:off
	for outline in heading_line version_line counter_line runtime_line caption_line logfile_line website_line; do printf -v "$outline" '%s' "${(P)outline// /─}"; done
	# @formatter:on
	trap 'printf "\033[?25h"' EXIT && printf '\033[?25l'

	# Output heading
	printf '%s╭%s┬%s╮%s\n' "$subdued_ansi" "$heading_line" "$version_line" "$refresh_ansi"
	printf '%s│%*s│%*s│%s\n' "$subdued_ansi" $((heading_width + 2)) '' $((version_width + 2)) '' "$refresh_ansi"
	printf '%s│%s %-*s %s│%s %*s %s│%s\n' "$subdued_ansi" "$refresh_ansi" "$heading_width" "$heading" "$subdued_ansi" "$refresh_ansi" "$version_width" "v$version" "$subdued_ansi" "$refresh_ansi"
	printf '%s│%*s│%*s│%s\n' "$subdued_ansi" $((heading_width + 2)) '' $((version_width + 2)) '' "$refresh_ansi"
	printf '%s╰%s┴%s╯%s\n' "$subdued_ansi" "$heading_line" "$version_line" "$refresh_ansi"

	# Verify executor
	verify_executor || return 1

	# Prompt password
	sudo -v
	local results=$?
	printf "\n"
	[[ $results -ne 0 ]] && return 1

	# Output heading
	clear && printf '%s╭%s┬%s╮%s\n' "$subdued_ansi" "$heading_line" "$version_line" "$refresh_ansi"
	printf '%s│%*s│%*s│%s\n' "$subdued_ansi" $((heading_width + 2)) '' $((version_width + 2)) '' "$refresh_ansi"
	printf '%s│%s %-*s %s│%s %*s %s│%s\n' "$subdued_ansi" "$refresh_ansi" "$heading_width" "$heading" "$subdued_ansi" "$refresh_ansi" "$version_width" "v$version" "$subdued_ansi" "$refresh_ansi"
	printf '%s│%*s│%*s│%s\n' "$subdued_ansi" $((heading_width + 2)) '' $((version_width + 2)) '' "$refresh_ansi"
	printf '%s╰%s┴%s╯%s\n' "$subdued_ansi" "$heading_line" "$version_line" "$refresh_ansi"

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

	# Output information
	local logfile="$(mktemp -d /tmp/XXXXXXXXXXX)/${heading}.log"
	local logpath="FILE://${logfile:u}"
	local weblink="${website:u}"
	printf '\r%s╭%s┬%s┬%s┬%s╮%s\n' "$subdued_ansi" "$caption_line" "$logfile_line" "$caption_line" "$website_line" "$refresh_ansi"
	printf '%s│%s %s %s│%s %s%-*s%s %s│%s %s %s│%s %s%-*s%s %s│%s\n' "$subdued_ansi" "$refresh_ansi" "LOG" "$subdued_ansi" "$refresh_ansi" "$website_ansi" "$logfile_width" "$logpath" "$refresh_ansi" "$subdued_ansi" "$refresh_ansi" "GIT" "$subdued_ansi" "$refresh_ansi" "$website_ansi" "$website_width" "$weblink" "$refresh_ansi" "$subdued_ansi" "$refresh_ansi"
	printf '%s╰%s┴%s┴%s┴%s╯%s\n' "$subdued_ansi" "$caption_line" "$logfile_line" "$caption_line" "$website_line" "$refresh_ansi"

	# Output progress
	# @formatter:off
	local topline="${subdued_ansi}╭${heading_line}┬${counter_line}┬${runtime_line}╮${refresh_ansi}"
	local divider="${subdued_ansi}├${heading_line}┼${counter_line}┼${runtime_line}┤${refresh_ansi}"
	local botline="${subdued_ansi}╰${heading_line}┴${counter_line}┴${runtime_line}╯${refresh_ansi}"
	printf '%s\n' "$topline"
	printf '%s│%s %-*s %s│%s %-5s %s│%s %-8s %s│%s\n' "$subdued_ansi" "$refresh_ansi" "$heading_width" "FUNCTION" "$subdued_ansi" "$refresh_ansi" "ITEMS" "$subdued_ansi" "$refresh_ansi" "DURATION" "$subdued_ansi" "$refresh_ansi"
	printf '%s\n' "$divider"
	local counter=0 && for running in "${members[@]}"; do
		((counter += 1)) && printf '\n%s\n\033[2A\r' "$botline"
		local started=$SECONDS
		printf '\n%s ' "${running:u}" >>"$logfile"
		printf '%*s\n\n' $((80 - ${#running} - 1)) '' | tr ' ' '-' >>"$logfile" && eval "$running" >>"$logfile" 2>&1 &
		local taskpid=$! && local wrapped=0
		while ((! wrapped)); do
			local context=$loading_ansi
			if ! kill -0 "$taskpid" 2>/dev/null; then wrapped=1 && if wait "$taskpid"; then context=$success_ansi; else context=$failure_ansi; fi; fi
			[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"; local elapsed=$((SECONDS - started))
			printf '\r%s│%s %s%-*s%s %s│%s %s%02d/%02d%s %s│%s %s%02d:%02d:%02d%s %s│%s' "$subdued_ansi" "$refresh_ansi" "$context" "$heading_width" "${running:u}" "$refresh_ansi" "$subdued_ansi" "$refresh_ansi" "$context" "$counter" "$bigness" "$refresh_ansi" "$subdued_ansi" "$refresh_ansi" "$context" $((elapsed / 3600)) $((elapsed % 3600 / 60)) $((elapsed % 60)) "$refresh_ansi" "$subdued_ansi" "$refresh_ansi"
			((wrapped)) || sleep 0.1
		done
		if ((counter < bigness)); then printf '\033[1B\r%s\n' "$divider"; else printf '\033[2B\r'; fi
	done
	printf '\033[?25h'
	# @formatter:on

	# Enable sleeping
	change_sleeping true

	# Enable timeouts
	change_timeouts true

	# Revert headline
	trap 'printf "\033[23;0t"' EXIT

	# Output newline
	printf "\n"

}

# @define Update brew packages
# @params The brew package names
update_brew() {

	# Handle parameters
	local factors=("$@")

	# Update packages
	printf "y\n" | brew install "${factors[@]}" 2>/dev/null
	printf "y\n" | brew upgrade "${factors[@]}" 2>/dev/null

}

# @define Update cask packages
# @params The cask package names
update_cask() {

	# Handle parameters
	local factors=("$@")

	# Update packages
	printf "y\n" | brew install --cask "${factors[@]}" 2>/dev/null
	printf "y\n" | brew upgrade --cask "${factors[@]}" 2>/dev/null

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
		local heading=$(basename "$ZSH_ARGZERO" | cut -d . -f 1)
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

	# Change theme
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
		[[ $(stat -f %B "$datadir/Default/Extensions/$uuid"/*/manifest.json 2>/dev/null | head -n1) -gt $(($(date +%s) - maximum)) ]] && return 0
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
		local version="$(curl -s "$website" | ggrep -oP "commandlinetools-mac_arm64-\K(\d+)" | head -1)"
		local address="https://dl.google.com/android/repository/commandlinetools-mac_arm64-${version}_latest.zip"
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

	# Update package
	local present="$([[ -d "/Applications/Android Studio.app" ]] && echo true || echo false)"
	local updated=false && (brew list --formula "android-studio" &>/dev/null || brew list --cask "android-studio" &>/dev/null) && ! brew outdated --quiet | grep -Fxq "android-studio" && updated=true
	update_cask android-studio

	# Finish install
	[[ "$updated" == "false" ]] && invoke_once "Android Studio"

	# Refine performance
	local vmoptions=(
		"-Dsun.java2d.metal=false"
		"-Dsun.java2d.opengl=false"
		"-Dide.mac.message.dialogs.as.sheets=false"
		"-Didea.max.intellisense.filesize=2500"
		"-Didea.indexing.threads=2"
		"-Djava.util.concurrent.ForkJoinPool.common.parallelism=4"
	)
	local removal=()
	for option in "${vmoptions[@]}"; do
		removal+=(-e "${option%%=*}")
	done
	while IFS= read -r configs; do
		configs="$configs/idea.vmoptions"
		[[ -f "$configs" ]] || cp "/Applications/Android Studio.app/Contents/bin/studio.vmoptions" "$configs"
		grep -v -F "${removal[@]}" "$configs" >"$configs.tmp" 2>/dev/null || true
		mv "$configs.tmp" "$configs"
		printf "%s\n" "${vmoptions[@]}" >>"$configs"
	done < <(find "$HOME/Library/Application Support/Google" -maxdepth 1 -type d -name "AndroidStudio*" -print 2>/dev/null)

	# Update plugins
	studio installPlugins "com.intellij.air"

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
	defaults write com.apple.dock tilesize -int 48
	defaults write com.apple.dock wvous-bl-corner -int 0
	defaults write com.apple.dock wvous-br-corner -int 0
	defaults write com.apple.dock wvous-tl-corner -int 0
	defaults write com.apple.dock wvous-tr-corner -int 0

	# Change dock elements
	defaults delete com.apple.dock persistent-apps
	defaults delete com.apple.dock persistent-others
	append_dock_application "/Applications/Chromium.app"
	append_dock_application "/Applications/JDownloader 2/JDownloader2.app"
	append_dock_application "/Applications/Transmission.app"
	append_dock_application "/Applications/Calibre.app"
	append_dock_application "/Applications/Notion.app"
	append_dock_application "/System/Applications/Passwords.app"
	append_dock_application "/Applications/IntelliJ IDEA.app"
	append_dock_application "/Applications/Visual Studio Code.app"
	append_dock_application "/Applications/Android Studio.app"
	append_dock_application "/Applications/Xcode.app"
	append_dock_application "/Applications/Postman.app"
	append_dock_application "/Applications/UTM.app"
	append_dock_application "/Applications/Figma.app"
	append_dock_application "/Applications/Xcode.app/Contents/Applications/Icon Composer.app"
	append_dock_application "/Applications/DaVinci Resolve/DaVinci Resolve.app"
	append_dock_application "/Applications/IINA.app"
	append_dock_application "/Applications/OBS.app"
	append_dock_application "/Applications/GameHub.app"
	append_dock_application "/System/Applications/Utilities/Terminal.app"
	append_dock_folder "$HOME/Downloads" 1 1 2
	append_dock_folder "$HOME/Repositories" 1 1 2
	killall Dock

	# Change wallpaper
	change_wallpaper "https://github.com/olankens/devpaper/raw/HEAD/source/java-04.avif"

}

# @define Update belgian-eid
update_belgian_eid() {

	# Update package
	update_cask beid-viewer

}

# @define Update calibre
update_calibre() {

	# Update package
	local present="$([[ -d "/Applications/Calibre.app" ]] && echo true || echo false)"
	local updated=false && (brew list --formula "calibre" &>/dev/null || brew list --cask "calibre" &>/dev/null) && ! brew outdated --quiet | grep -Fxq "calibre" && updated=true
	update_cask calibre

	# Finish install
	[[ "$present" == "false" ]] && invoke_once "calibre"

	# Update goodreads
	local website="https://api.github.com/repos/kiwidude68/calibre_plugins/releases"
	local address=$(curl -s "$website" | jq -r '.[] | select(.tag_name | startswith("goodreads-")) | .assets[].browser_download_url' | head -1)
	local archive=$(mktemp -d)/$(basename "$address") && curl -LA "mozilla/5.0" "$address" -o "$archive"
	local program="/Applications/calibre.app/Contents/MacOS/calibre-customize"
	"$program" --add-plugin "$archive"
	"$program" --enable-plugin "Goodreads"

	# Update kobo-metadata
	local website="https://api.github.com/repos/NotSimone/Kobo-Metadata/releases"
	local version=$(curl -s "$website" | jq -r '.[0].tag_name')
	local address="https://github.com/NotSimone/Kobo-Metadata/releases/download/${version}/KoboMetadata.zip"
	local archive=$(mktemp -d)/$(basename "$address") && curl -LA "mozilla/5.0" "$address" -o "$archive"
	local program="/Applications/calibre.app/Contents/MacOS/calibre-customize"
	"$program" --add-plugin "$archive"
	"$program" --enable-plugin "KoboMetadata"

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

	# Finish install
	[[ "$present" == "false" ]] && invoke_once "Chromium"

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
		update_chromium_extension "ddkjiahejlhfcafbddmgiahcphecmpfh" # ublock-origin-lite
		update_chromium_extension "fcjmgeodgobggcppooncdagfkogfffdm" # imagus-reborn
		update_chromium_extension "ibplnjkanclpjokhdolnendpplpjiace" # simple-translate
		update_chromium_extension "kdplapeciagkkjoignnkfpbfkebcfbpb" # uautopagerize
		update_chromium_extension "mnjggcdmjocbbbhaepdhchncahnbgone" # sponsorblock-for-youtube
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

	# Change settings
	local configs="$HOME/.claude.json" && mkdir -p "$(dirname "$configs")"
	[[ -s "$configs" ]] || echo "{}" >"$configs"
	jq ".hasCompletedOnboarding = true" "$configs" | sponge "$configs"
	jq ".includeCoAuthoredBy = false" "$configs" | sponge "$configs"
	jq ".spinnerTipsEnabled = false" "$configs" | sponge "$configs"

	# Change environment
	append_environment "CLAUDE_CODE_MAX_OUTPUT_TOKENS" 'export CLAUDE_CODE_MAX_OUTPUT_TOKENS=128000'

	# Update marketplaces
	claude plugin marketplace add anthropics/claude-plugins-official && claude plugin marketplace update claude-plugins-official
	claude plugin marketplace add DietrichGebert/ponytail && claude plugin marketplace update ponytail

	# Update plugins
	claude plugin install code-review@claude-plugins-official && claude plugin update code-review
	claude plugin install github@claude-plugins-official && claude plugin update github
	claude plugin install security-guidance@claude-plugins-official && claude plugin update security-guidance
	claude plugin install superpowers@claude-plugins-official && claude plugin update superpowers
	claude plugin install ponytail@ponytail && claude plugin update ponytail

}

# @define Update davinci-resolve
update_davinci_resolve() {

	# Change appearance
	change_icon "davinci-resolve" "/Applications/DaVinci Resolve/DaVinci Resolve.app" || true

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

}

# @define Update figma
update_figma() {

	# Handle dependencies
	update_brew jq sponge

	# Update package
	local present="$([[ -d "/Applications/Figma.app" ]] && echo true || echo false)"
	update_cask figma

	# Finish install
	[[ "$present" == "false" ]] && invoke_once "Figma"

	# Change settings
	local configs="$HOME/Library/Application Support/Figma/settings.json"
	jq ".showFigmaInMenuBar = false" "$configs" | sponge "$configs"

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

# @define Update gamehub
update_gamehub() {

	# Update package
	update_cask gamehub

	# Change appearance
	local address="https://github.com/olankens/macatoni/raw/refs/heads/main/source/gamehub/gamehub.icns"
	local picture="$(mktemp -d)/$(basename "$address")"
	curl -LA "mozilla/5.0" "$address" -o "$picture"
	fileicon set "/Applications/GameHub.app" "$picture" || sudo !!
	cp "$picture" "/Applications/GameHub.app/Contents/Resources/icon.icns"
	sudo xattr -cr "/Applications/GameHub.app"
	sudo codesign --remove-signature "/Applications/GameHub.app"
	sudo codesign --deep --sign - "/Applications/GameHub.app"

}

# @define Update git
update_git() {

	# Handle parameters
	local default=${1:-main}

	# Update package
	update_brew gh git

	# Update gh extensions
	gh extension install github/gh-stack

	# Change settings
	local gituser=$(gh api user --jq '.name // .login' 2>/dev/null || true)
	local gitmail=$(gh api user --jq '"\(.id)+\(.login)@users.noreply.github.com"' 2>/dev/null || true)
	[[ -n "$gitmail" ]] && git config --global user.email "$gitmail"
	[[ -n "$gituser" ]] && git config --global user.name "$gituser"
	git config --global checkout.workers 0
	git config --global credential.helper "store"
	git config --global http.postBuffer 1048576000
	git config --global init.defaultBranch "$default"
	git config --global pull.rebase true
	git config --global push.autoSetupRemote true

}

# @define Update headroom
update_headroom() {

	# Handle dependencies
	update_nodejs
	update_brew uv

	# Update package
	uv tool install --python 3.13 "headroom-ai[all]"
	uv tool update-shell
	source "$HOME/.zshenv" && headroom update --yes

}

# @define Update homebrew
update_homebrew() {

	# Handle dependencies
	sudo touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
	local package="$(softwareupdate -l 2>&1 | grep '\*.*Command Line Tools' | head -1 | sed 's/^[*[:space:]]*//; s/^Label: //')"
	sudo softwareupdate -i "$package"
	sudo xcode-select --switch /Library/Developer/CommandLineTools
	sudo rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

	# Update package
	local command=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)
	CI=1 /bin/bash -c "$command" &>/dev/null

	# Change environment
	if ! grep -q "/opt/homebrew/bin/brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
		[[ -s "$HOME/.zprofile" ]] || printf "#!/bin/zsh" >"$HOME/.zprofile"
		perl -i -0777 -pe "s/\n*\z/\n/s" "$HOME/.zprofile" 2>/dev/null || true
		printf "\n%s" "# Invoke homebrew environment" >>"$HOME/.zprofile"
		printf "\n%s\n" 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
		eval "$(/opt/homebrew/bin/brew shellenv)"
	fi

	# Change settings
	brew analytics off

}

# @define Update iina
update_iina() {

	# Update dependencies
	update_brew curl jq

	# Update package
	local present="$([[ -d "/Applications/IINA.app" ]] && echo "true" || echo "false")"
	local updated=false && (brew list --formula "iina" &>/dev/null || brew list --cask "iina" &>/dev/null) && ! brew outdated --quiet | grep -Fxq "iina" && updated=true
	update_cask iina

	# Finish install
	[[ "$updated" == "false" ]] && invoke_once "IINA"
	[[ "$updated" == "false" ]] && update_chromium_extension "pdnojahnhpgmdhjdhgphgdcecehkbhfo" # open-in-iina

	# Change settings
	defaults write com.colliderli.iina recordPlaybackHistory -integer 0
	defaults write com.colliderli.iina recordRecentFiles -integer 0
	defaults write com.colliderli.iina SUEnableAutomaticChecks -integer 0
	defaults write com.colliderli.iina ytdlSearchPath "/usr/local/bin"

	# Change association
	change_association com.colliderli.iina mkv
	change_association com.colliderli.iina mov
	change_association com.colliderli.iina mp4
	change_association com.colliderli.iina avi
	change_association com.colliderli.iina webm

	# Change appearance
	change_icon "iina" "/Applications/IINA.app"

}

# @define Update intellij-idea
update_intellij_idea() {

	# Update package
	local present="$([[ -d "/Applications/IntelliJ IDEA.app" ]] && echo "true" || echo "false")"
	local updated=false && (brew list --formula "intellij-idea" &>/dev/null || brew list --cask "intellij-idea" &>/dev/null) && ! brew outdated --quiet | grep -Fxq "intellij-idea" && updated=true
	update_cask intellij-idea

	# Finish install
	[[ "$updated" == "false" ]] && invoke_once "IntelliJ IDEA"

	# Refine performance
	local vmoptions=(
		"-Dsun.java2d.metal=false"
		"-Dsun.java2d.opengl=false"
		"-Dide.mac.message.dialogs.as.sheets=false"
		"-Didea.max.intellisense.filesize=2500"
		"-Didea.indexing.threads=2"
		"-Djava.util.concurrent.ForkJoinPool.common.parallelism=4"
	)
	local removal=()
	for option in "${vmoptions[@]}"; do
		removal+=(-e "${option%%=*}")
	done
	while IFS= read -r configs; do
		configs="$configs/idea.vmoptions"
		[[ -f "$configs" ]] || cp "/Applications/IntelliJ IDEA.app/Contents/bin/idea.vmoptions" "$configs"
		grep -v -F "${removal[@]}" "$configs" >"$configs.tmp" 2>/dev/null || true
		mv "$configs.tmp" "$configs"
		printf "%s\n" "${vmoptions[@]}" >>"$configs"
	done < <(find "$HOME/Library/Application Support/JetBrains" -maxdepth 1 -type d -name "IntelliJIdea*" -print 2>/dev/null)

	# Update plugins
	idea installPlugins "com.intellij.air"

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

	# Change settings
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

	# Change appearance
	local address="https://github.com/olankens/macatoni/raw/refs/heads/main/source/jdownloader/jdownloader.icns"
	local picture="$(mktemp -d)/$(basename "$address")"
	curl -LA "mozilla/5.0" "$address" -o "$picture"
	fileicon set "/Applications/JDownloader 2/JDownloader2.app" "$picture" || sudo !!
	fileicon set "/Applications/JDownloader 2/Uninstall JDownloader.app" "$picture" || sudo !!
	cp "$picture" "/Applications/JDownloader 2/JDownloader2.app/Contents/Resources/app.icns"
	local sitting="/Applications/JDownloader 2/themes/standard/org/jdownloader/images/logo/jd_logo_128_128.png"
	sips -Z 128 -s format png "$picture" --out "$sitting"

}

# @define Update keepingyouawake
update_keepingyouawake() {

	# Update package
	local present="$([[ -d "/Applications/KeepingYouAwake.app" ]] && echo "true" || echo "false")"
	update_cask keepingyouawake

	# Finish install
	[[ "$present" == "false" ]] && invoke_once "KeepingYouAwake" "" 5

	# Change settings
	defaults write info.marcel-dierkes.KeepingYouAwake ActivateOnLaunch -bool true

}

# @define Update keka
update_keka() {

	# Update package
	local present="$([[ -d "/Applications/Keka.app" ]] && echo "true" || echo "false")"
	update_cask keka kekaexternalhelper

	# Finish install
	[[ "$present" == "false" ]] && invoke_once "Keka"

	# Change association
	/Applications/KekaExternalHelper.app/Contents/MacOS/KekaExternalHelper --set-as-default &
	local process=$!
	sleep 4 && while kill -0 "$process" 2>/dev/null; do
		osascript <<-'EOF'
			tell application "System Events"
				tell process "CoreServicesUIAgent"
					repeat with w in windows
						repeat with b in buttons of w
							try
								if (name of b starts with "Use ") then
									click b
									return
								end if
							end try
						end repeat
					end repeat
				end tell
			end tell
		EOF
		sleep 0.5
	done
	wait "$process"

}

# @define Update miniforge
update_miniforge() {

	# Update package
	update_cask miniforge

	# Change settings
	conda init zsh
	conda config --set auto_activate false

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
	update_brew node@"$version" pnpm

	# Change environment
	append_environment "/opt/homebrew/opt/node" "export PATH=\"\$PATH:/opt/homebrew/opt/node@$version/bin\""
	sed -i "" -e "s#/opt/homebrew/opt/node.*/bin#/opt/homebrew/opt/node@$version/bin#" "$HOME/.zshrc"
	source "$HOME/.zshrc"

	# Change settings
	pnpm config set ignore-scripts false --global
	pnpm config set dangerouslyAllowAllBuilds true --global

}

# @define Update notion
update_notion() {

	# Handle dependencies
	update_brew coreutils jq

	# Update package
	local present="$([[ -d "/Applications/Notion.app" ]] && echo "true" || echo "false")"
	update_cask notion

	# Finish install
	[[ "$present" == "false" ]] && invoke_once "Notion"

	# Change settings
	local configs="$HOME/Library/Application Support/Notion/state.json"
	mkdir -p "$(dirname "$configs")"
	[[ -s "$configs" ]] || echo "{}" >"$configs"
	jq '.appState.preferences.isMenuBarIconEnabled = false' "$configs" | sponge "$configs"
	jq '.appState.preferences.isAutoUpdaterDisabled = true' "$configs" | sponge "$configs"
	jq '.appState.preferences.isOpenAtLoginEnabled = false' "$configs" | sponge "$configs"

	# Change appearance
	change_icon "notion" "/Applications/Notion.app"

}

# @define Update obs
update_obs() {

	# Update package
	update_cask obs

	# Change appearance
	change_icon "obs" "/Applications/OBS.app"

}

# @define Update passwords
update_passwords() {

	# Update chromium
	update_chromium_extension "pejdijmoenmkgeppbflobdenhhabjlaj" # icloud-passwords

}

# @define Update postman
update_postman() {

	# Update package
	update_cask postman

	# Change appearance
	change_icon "postman" "/Applications/Postman.app"

}

# @define Update powershell
update_powershell() {

	# Update package
	update_brew powershell

	# Change environment
	append_environment "POWERSHELL_TELEMETRY_OPTOUT" \
		'export POWERSHELL_TELEMETRY_OPTOUT=1' \
		'export POWERSHELL_UPDATECHECK=Off'

}

# @define Update rclone
update_rclone() {

	# Update package
	update_brew rclone

}

# @define Update system
update_system() {

	# Change finder
	defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
	defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
	defaults write com.apple.finder ShowPathbar -bool true
	local deposit="$HOME/Repositories"
	mkdir -p "$deposit" && osascript <<-EOF
		tell application "Finder"
			activate
			set targetFolder to POSIX file "$deposit" as alias
			reveal targetFolder
		end tell
		tell application "System Events"
			tell process "Finder"
				click menu item "Add to Sidebar" of menu "File" of menu bar 1
			end tell
		end tell
		tell application "Finder" to quit
	EOF

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
	local present="$([[ -d "/Applications/Transmission.app" ]] && echo "true" || echo "false")"
	local updated=false && (brew list --formula "transmission" &>/dev/null || brew list --cask "transmission" &>/dev/null) && ! brew outdated --quiet | grep -Fxq "transmission" && updated=true
	update_cask transmission

	# Finish install
	[[ "$present" == "false" ]] && invoke_once "Transmission"

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
	local present="$([[ -d "/Applications/UTM.app" ]] && echo "true" || echo "false")"
	update_cask utm

	# Finish install
	[[ "$present" == "false" ]] && invoke_once "UTM"

	# Change appearance
	change_icon "utm" "/Applications/UTM.app"

}

# @define Update visual-studio-code
update_visual_studio_code() {

	# Handle dependencies
	update_brew font-jetbrains-mono jq sponge

	# Update package
	local present="$([[ -d "/Applications/Visual Studio Code.app" ]] && echo "true" || echo "false")"
	update_cask visual-studio-code

	# Finish install
	[[ "$present" == "false" ]] && invoke_once "Visual Studio Code" "Code"

	# Update extensions
	sleep 5 && code --install-extension "mikestead.dotenv" --force
	sleep 5 && code --install-extension "streetsidesoftware.code-spell-checker-cspell-bundled-dictionaries" --force
	sleep 5 && code --install-extension "usernamehw.errorlens" --force

	# Change settings
	local configs="$HOME/Library/Application Support/Code/User/settings.json"
	[[ -s "$configs" ]] || echo "{}" >"$configs"
	# jq '."chat.disableAIFeatures" = true' "$configs" | sponge "$configs"
	jq '."chat.agentHost.allowSignedOutWhenUsable" = true' "$configs" | sponge "$configs"
	jq '."chat.titleBar.openInAgentsWindow.enabled" = false' "$configs" | sponge "$configs"
	jq '."chat.titleBar.signIn.enabled" = false' "$configs" | sponge "$configs"
	jq '."editor.codeActionsOnSave" = {"source.fixAll": "explicit"}' "$configs" | sponge "$configs"
	jq '."editor.fontFamily" = "JetBrains Mono"' "$configs" | sponge "$configs"
	jq '."editor.fontSize" = 13' "$configs" | sponge "$configs"
	jq '."editor.formatOnSave" = true' "$configs" | sponge "$configs"
	jq '."editor.guides.bracketPairs" = "active"' "$configs" | sponge "$configs"
	jq '."editor.lineHeight" = 1.6' "$configs" | sponge "$configs"
	jq '."editor.linkedEditing" = true' "$configs" | sponge "$configs"
	jq '."editor.renderWhitespace" = "boundary"' "$configs" | sponge "$configs"
	jq '."errorLens.enabledDiagnosticLevels" = ["error", "warning"]' "$configs" | sponge "$configs"
	jq '."git.addAICoAuthor" = "off"' "$configs" | sponge "$configs"
	jq '."security.workspace.trust.enabled" = false' "$configs" | sponge "$configs"
	jq '."telemetry.telemetryLevel" = "crash"' "$configs" | sponge "$configs"
	jq '."update.mode" = "none"' "$configs" | sponge "$configs"

	# Refine performance
	jq '."extensions.autoCheckUpdates" = false' "$configs" | sponge "$configs"
	jq '."extensions.autoUpdate" = "off"' "$configs" | sponge "$configs"
	jq '."files.watcherExclude" = {"**/.git/**": true, "**/node_modules/**": true, "**/.next/**": true, "**/dist/**": true, "**/build/**": true, "**/target/**": true, "**/.idea/**": true, "**/.gradle/**": true, "**/out/**": true, "**/coverage/**": true, "**/.turbo/**": true, "**/.cache/**": true}' "$configs" | sponge "$configs"
	jq '."js/ts.tsserver.maxMemory" = 2048' "$configs" | sponge "$configs"
	jq '."search.exclude" ={"**/node_modules": true, "**/.git": true, "**/.next": true, "**/dist": true, "**/build": true, "**/target": true, "**/.idea": true, "**/.gradle": true, "**/out": true, "**/coverage": true, "**/.turbo": true, "**/.cache": true}' "$configs" | sponge "$configs"
	jq '."search.followSymlinks" = false' "$configs" | sponge "$configs"
	jq '."search.useGlobalIgnoreFiles" = true' "$configs" | sponge "$configs"
	jq '."search.useIgnoreFiles" = true' "$configs" | sponge "$configs"

}

# @define Update xcode
update_xcode() {

	# Handle dependencies
	update_brew cocoapods grep xcodesorg/made/xcodes

	# Change appearance
	[[ -d "/Applications/Xcode.app" ]] && change_icon "xcode" "/Applications/Xcode.app"

	# Verify credentials
	[[ -z "$XCODES_USERNAME" || -z "$XCODES_PASSWORD" ]] && return 1

	# Update package
	xcodes install --latest --experimental-unxip

	# Finish install
	sudo xcode-select --switch "/Applications/Xcode.app/Contents/Developer"
	sudo xcodebuild -runFirstLaunch
	sudo xcodebuild -license accept

	# Change appearance
	change_icon "xcode" "/Applications/Xcode.app"

}

#endregion

#region DEVELOPER

update_devtools_android() {

	# Handle parameters
	local version=${1:-37}

	# Handle dependencies
	update_android_cmdline
	update_android_studio
	update_brew apktool bundletool jadx scrcpy
	brew tap kdbhalala/avdslim https://github.com/kdbhalala/avdslim.git
	update_brew kdbhalala/avdslim/avdslim

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
	avdmanager create avd -n "Pixel_10_API_${version}" -d "pixel_10" -k "system-images;android-${version};google_apis;arm64-v8a" -f

	# Refine performance
	avdslim tune-avd "Pixel_10_API_${version}" || true
	avdslim install-shim || true
	avdslim on --aggressive || true

}

update_devtools_angular() {

	# Handle parameters
	local datadir="${1:-$HOME/Library/Application Support/Chromium Debug}"

	# Handle dependencies
	update_chromium_debug
	update_devtools_js_ts

	# Update angular
	export NG_CLI_ANALYTICS="ci" && npm i -g @angular/cli
	ng analytics off

	# Change environment
	append_environment "ng completion script" "source <(ng completion script)"
	source "$HOME/.zshrc"

	# Update code
	sleep 5 && code --install-extension "angular.ng-template" --force

	# Update chromium
	update_chromium_extension "ienfalfjdbdpebioblfackkekamfmbnh" "$datadir" # angular-devtools

}

update_devtools_apple() {

	# Handle dependencies
	update_xcode
	update_brew jq swiftformat xcbeautify xcode-build-server
	update_brew mobai-app/tap/simslim

	# Update platforms
	# xcodebuild -downloadPlatform iOS

	# Refine performance
	while IFS= read -r device; do
		[[ -n "$device" ]] && simslim on "$device" --preserve-boot-state || true
	done < <(simslim list --json 2>/dev/null | jq -r '.[].udid')

	# Update code
	sleep 5 && code --install-extension "sweetpad.sweetpad" --force

}

update_devtools_astro() {

	# Handle dependencies
	update_chromium_debug
	update_devtools_js_ts

	# Update code
	sleep 5 && code --install-extension "astro-build.astro-vscode" --force

}

update_devtools_bash() {

	# Handle dependencies
	update_intellij_idea
	update_visual_studio_code
	update_brew bash shellcheck shfmt

	# Update code
	sleep 5 && code --install-extension "mads-hartmann.bash-ide-vscode" --force

	# Update idea
	idea installPlugins "pro.bashsupport"

}

update_devtools_claude_code() {

	# Handle parameters
	local variant=${1}

	# Handle dependencies
	update_claude_code
	update_headroom
	headroom install apply --preset persistent-service --scope provider --providers auto

	# Handle opencode
	if [[ "$variant" == "opencode" ]]; then
		update_brew routatic/tap/routatic-proxy
		routatic-proxy update-channel stable
		routatic-proxy update
		append_environment "ROUTATIC_PROXY_API_KEY" \
			'export ANTHROPIC_AUTH_TOKEN="unused"' \
			'export ANTHROPIC_BASE_URL="http://127.0.0.1:8787"' \
			'export ANTHROPIC_TARGET_API_URL="http://127.0.0.1:3456"' \
			'export ROUTATIC_PROXY_API_KEY="YOUR_OPENCODE_API_KEY"'
		# sed -i "" -e 's|^export ROUTATIC_PROXY_API_KEY=.*|export ROUTATIC_PROXY_API_KEY="YOUR_OPENCODE_API_KEY"|' "$HOME/.zshrc"
		routatic-proxy init
		local configs="$HOME/.config/routatic-proxy/config.json"
		jq '.enable_streaming_scenario_routing = true' "$configs" | sponge "$configs"
		# jq '.respect_requested_model = true' "$configs" | sponge "$configs"
		# jq 'del(.model_family_overrides)' "$configs" | sponge "$configs"
		# jq '.model_family_overrides.opus.model_id = "gpt-5.6-luna" | .model_family_overrides.opus.wire_format = "responses"' "$configs" | sponge "$configs"
		# jq '.model_family_overrides.sonnet.model_id = "gpt-5.6-luna" | .model_family_overrides.sonnet.wire_format = "responses"' "$configs" | sponge "$configs"
		# jq '.model_family_overrides.haiku.model_id = "glm-5.3-flash"' "$configs" | sponge "$configs"
		jq '.model_family_overrides.opus.model_id = "gpt-6-luna" | .model_family_overrides.opus.wire_format = "responses"' "$configs" | sponge "$configs"
		jq '.model_family_overrides.sonnet.model_id = "gpt-6-luna" | .model_family_overrides.sonnet.wire_format = "responses"' "$configs" | sponge "$configs"
		jq '.model_family_overrides.haiku.model_id = "gpt-6-luna" | .model_family_overrides.haiku.wire_format = "responses"' "$configs" | sponge "$configs"
		headroom install apply --preset persistent-service --scope provider --providers auto
		routatic-proxy autostart enable
		routatic-proxy stop || true && sleep 5 && routatic-proxy start -b || true
	fi

	# Handle zai
	if [[ "$variant" == "zai" ]]; then
		# npx -y @z_ai/coding-helper auth glm_coding_plan_global YOUR_ZAI_API_KEY
		npx -y @z_ai/coding-helper auth reload claude
		headroom install apply --preset persistent-service --scope provider --providers auto \
			--env ANTHROPIC_TARGET_API_URL=https://api.z.ai/api/anthropic
	fi

	# Update jetbrains
	# INFO: Use default Claude Agent
	# - Select Anthropic Console authentication
	# - Finish the launched browser and CTRL-C in the opened terminal
	# - Claude Agent is now configured as "managed by agent"
	# if grep -qsE "com\.jetbrains|com\.google\.android\.studio" /Applications/*.app/Contents/Info.plist ~/Applications/*.app/Contents/Info.plist; then
	# 	local configs="$HOME/.jetbrains/acp.json" && mkdir -p "$(dirname "$configs")"
	# 	[[ -s "$configs" ]] || echo "{}" >"$configs"
	# 	npm install -g @agentclientprotocol/claude-agent-acp
	# 	jq '
	# 		.default_mcp_settings = {
	# 		  use_idea_mcp: true,
	# 		  use_custom_mcp: true
	# 		  }
	# 		| .tools = {
	# 			  auto_approve_all: true,
	# 			  forbidden_tools: []
	# 		  }
	# 		| .execution = {
	# 			  mode: "unrestricted",
	# 			  always_allow_shell: true
	# 		  }
	# 		| .agent_servers //= {}
	# 		| .agent_servers["Claude (ACP)"] = {
	# 			  command: "/opt/homebrew/bin/claude-agent-acp",
	# 			  args: ["acp"]
	# 		  }
	# 	' "$configs" | sponge "$configs"
	# fi

	# Update visual-studio-code
	if [[ -d "/Applications/Visual Studio Code.app" ]]; then
		local configs="$HOME/Library/Application Support/Code/User/settings.json" && mkdir -p "$(dirname "$configs")"
		[[ -s "$configs" ]] || echo "{}" >"$configs"
		jq '."chat.agentHost.allowSignedOutWhenUsable" = true' "$configs" | sponge "$configs"
		jq '."chat.byokUtilityModelDefault" = "mainAgent"' "$configs" | sponge "$configs"
		jq '."chat.defaultToCopilotHarness" = false' "$configs" | sponge "$configs"
		jq '."chat.editor.localAgent.enabled" = true' "$configs" | sponge "$configs"
		jq '."chat.editor.preferCopilotHarness" = false' "$configs" | sponge "$configs"
	fi

}

update_devtools_flutter() {

	# Handle dependencies
	update_devtools_android
	update_devtools_apple
	update_flutter
	update_visual_studio_code

	# Update code
	sleep 5 && code --install-extension "dart-code.flutter" --force
	sleep 5 && code --install-extension "pflannery.vscode-versionlens" --force
	local configs="$HOME/Library/Application Support/Code/User/settings.json"
	jq '."[dart]"."editor.codeActionsOnSave"."source.fixAll" = "explicit"' "$configs" | sponge "$configs"
	jq '."[dart]"."editor.codeActionsOnSave"."source.organizeImports" = "explicit"' "$configs" | sponge "$configs"
	jq '."[dart]"."editor.defaultFormatter" = "Dart-Code.dart-code"' "$configs" | sponge "$configs"

	# Update studio
	studio installPlugins "Dart"
	studio installPlugins "io.flutter"

	# TODO: Add `readlink -f $(which flutter)` to studio
	# NOTE: /usr/local/Caskroom/flutter/*/flutter

}

update_devtools_js_ts() {

	# Handle dependencies
	update_nodejs
	update_visual_studio_code

	# Update code
	sleep 5 && code --install-extension "dbaeumer.vscode-eslint" --force
	sleep 5 && code --install-extension "esbenp.prettier-vscode" --force
	local configs="$HOME/Library/Application Support/Code/User/settings.json"
	jq '."js/ts.suggest.autoImports" = true' "$configs" | sponge "$configs"
	jq '."js/ts.updateImportsOnFileMove.enabled" = "always"' "$configs" | sponge "$configs"
	jq '."js/ts.preferences.importModuleSpecifier" = "shortest"' "$configs" | sponge "$configs"
	jq '."js/ts.preferences.importModuleSpecifierEnding" = "minimal"' "$configs" | sponge "$configs"

}

update_devtools_kmp() {

	# Handle dependencies
	update_devtools_android
	update_devtools_apple

	# Update studio plugins
	studio installPlugins "com.intellij.marketplace"
	studio installPlugins "com.jetbrains.kmm"
	studio installPlugins "org.jetbrains.kotlin-toolchain"

}

update_devtools_nestjs() {

	# Handle dependencies
	update_docker
	update_nodejs
	update_devtools_js_ts

	# Update nestjs
	npm i -g @nestjs/cli

	# Update code
	sleep 5 && code --install-extension "imgildev.vscode-nestjs-snippets-extension" --force
	sleep 5 && code --install-extension "ms-azuretools.vscode-containers" --force

}

update_devtools_powershell() {

	# Handle dependencies
	update_intellij_idea
	update_powershell

	# Update idea
	idea installPlugins "com.intellij.plugin.adernov.powershell"

}

update_devtools_spring() {

	# Handle dependencies
	# update_brew arconia-io/tap/arconia-cli
	update_docker
	update_intellij_idea
	update_temurin
	update_visual_studio_code

	# Update code
	sleep 5 && code --install-extension "ms-azuretools.vscode-containers" --force
	sleep 5 && code --install-extension "vmware.vscode-spring-boot" --force
	sleep 5 && code --install-extension "vscjava.vscode-spring-boot-dashboard" --force
	sleep 5 && code --install-extension "vscjava.vscode-spring-initializr" --force
	local configs="$HOME/Library/Application Support/Code/User/settings.json"
	jq '."[java]"."editor.defaultFormatter" = "redhat.java"' "$configs" | sponge "$configs"
	jq '."boot-java.java.reconcilers" = true' "$configs" | sponge "$configs"
	jq '."java.configuration.updateBuildConfiguration" = "automatic"' "$configs" | sponge "$configs"
	jq '."redhat.telemetry.enabled" = false' "$configs" | sponge "$configs"
	jq '."spring-boot.ls.cds.enabled" = true' "$configs" | sponge "$configs"

	# Update idea
	idea installPlugins "com.github.chengpohi"
	idea installPlugins "com.intellij.bigdatatools.kafka"
	idea installPlugins "com.intellij.spring.debugger"
	idea installPlugins "com.intellij.spring.messaging"
	idea installPlugins "com.jetbrains.opentelemetry"

}

#endregion

main() {

	[[ "$ZSH_EVAL_CONTEXT" != *:file || "$TERM_PROGRAM" == "vscode" || $(ps -p $PPID -o comm=) =~ idea ]] || return 0

	local heading="MACFRESH"
	local version="1.0.0" # x-release-please-version
	local website="https://github.com/olankens/macfresh"
	local maximum="91"
	local country="Europe/Brussels"
	local machine="macintosh"
	local members=(
		"update_homebrew"
		"update_system"
		"update_android_cmdline"
		"update_android_studio"
		"update_belgian_eid"
		"update_calibre"
		"update_chromium"
		"update_chromium_debug"
		"update_claude_code"
		"update_davinci_resolve"
		"update_docker"
		"update_figma"
		"update_flutter"
		"update_gamehub"
		"update_git"
		"update_headroom"
		"update_iina"
		"update_intellij_idea"
		"update_jdownloader"
		"update_keepingyouawake"
		"update_keka"
		"update_miniforge"
		"update_mole"
		"update_nightlight"
		"update_nodejs"
		"update_notion"
		"update_obs"
		"update_passwords"
		"update_postman"
		"update_powershell"
		"update_rclone"
		"update_temurin"
		"update_transmission"
		"update_utm"
		"update_visual_studio_code"
		"update_xcode"
		"update_devtools_android"
		"update_devtools_apple"
		"update_devtools_js_ts"
		"update_devtools_angular"
		"update_devtools_astro"
		"update_devtools_bash"
		"update_devtools_claude_code 'opencode'"
		"update_devtools_flutter"
		"update_devtools_kmp"
		"update_devtools_nestjs"
		"update_devtools_powershell"
		"update_devtools_spring"
		"update_appearance"
	)

	invoke_wrapper "$heading" "$maximum" "$version" "$website" "$country" "$machine" "${members[@]}"

}

main "$@"
