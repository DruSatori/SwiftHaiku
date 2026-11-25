#!/bin/sh
# Cross-build (build-cross.sh), copy the programs to the VM's /boot/home/SwiftHaiku-demo, start
# Gallery in the VM's desktop and drive each control through `hey` scripting, checking after each
# change that some text bound to its state reads as expected:
#   Basics tab: the check box and slider get key downs (" " and B_RIGHT_ARROW), a radio button a
#   " ", the secure field typed keys, the pop-up menu an execute of its item.
#   More tab (picked with B_RIGHT_ARROW and " " to the tab view): the editor gets typed keys, the
#   list a scripted selection, the color control a new red value and B_ENTER in its red field.
# It checks that value changes keep the same native views (same messengers, see run-vm.sh) and
# that ticking "Show details" adds the details section with new native views (a rebuild), then
# scrolls the ScrollView with a mouse wheel message. Screenshots land in
# .build/screens/gallery-{before,after,details,more}.png. Leaves nothing on the VM.
# Usage: VM=<name> run-gallery-vm.sh (the VM's desktop must be running). Exits 0 if every hey
# command succeeded, Gallery quit, every bound text and view check matched and the screenshots
# came back; look at the PNGs.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
rs=$(cd "${RENKUOS_SWIFT:-$here/../RenkuOS-Swift}" && pwd)
ssh=$(cd "$rs/../RenkuOS-on-Parallels/build-vm" && pwd)/ssh.sh
remote=/boot/home/SwiftHaiku-demo
sig=application/x-vnd.swifthaiku-galleryapp
screens=$here/.build/screens
W="of Window 0"

"$here/scripts/build-cross.sh"
mkdir -p "$screens"
rm -f "$screens"/gallery-*
echo "== run on $(PRINT_IP=1 "$ssh")"
"$ssh" "rm -rf $remote"
SCP=1 "$ssh" -q -r "$here/.build/haiku-arm64/app" "vm:$remote"
fail=0
shot() { "$ssh" "screenshot -s $remote/gallery-$1.png; test -s $remote/gallery-$1.png" || fail=1; }
hey() { "$ssh" "hey -s $sig $*" || { echo "hey failed: $*"; fail=1; }; }
key() { hey "let $1 $W do _KYD with bytes=$2"; }
# texts: the window's texts (named text<n>, n counting every leaf view), as "<n> <text>" lines.
texts() { "$ssh" "sleep 0.5; for i in \$(seq 0 70); do echo \$i \$(hey -o $sig get Text of View text\$i $W); done"; }
# expect <text>: one of the window's texts must read exactly <text>.
expect() {
	if texts | cut -d' ' -f2- | grep -Fqx "$1"; then echo "ok: $1"; else echo "missing text: $1"; fail=1; fi
}
# ids <view name>...: the first 12 bytes (port, handler token, team) of each view's messenger.
ids() {
	for v in "$@"; do
		"$ssh" "hey $sig get Messenger of View $v $W" | grep '"result"' | cut -d: -f2 | cut -d, -f1-12
	done
}
# same <file> <file> <what>: both id lists must be complete and equal.
same() {
	[ "$(wc -l < "$1")" -eq "$3" ] && cmp -s "$1" "$2" || { echo "$4 rebuilt the views"; fail=1; }
}

"$ssh" "cd $remote && (./Gallery > stdout 2> stderr &) && sleep 3" || fail=1
shot before
# Gallery's control names (action ids in render order): tabs0 button1 field2 field3 toggle4
# picker5 picker6 slider7 toggle8, and on the More tab field9 list10 color11.
key "View toggle4" "' '"
expect "Enabled: yes"
hey "do MenuItem 2 of Menu 0 of View 0 of View picker5 $W"
expect "Size: Large"
# View 0 of the radio picker is its title.
key "View 2 of View picker6" "' '"
expect "Flavor: Chocolate"
for c in s e c; do key "View _input_ of View field3" $c; done
expect "Password: 3 characters"
ids slider7 field2 > "$screens/gallery-ids-1.txt"
key "View slider7" "\$(printf '\\035')"
expect 51
ids slider7 field2 > "$screens/gallery-ids-2.txt"
same "$screens/gallery-ids-1.txt" "$screens/gallery-ids-2.txt" 2 "the slider change"
shot after
key "View toggle8" "' '"
expect "Added and removed by a rebuild."
ids slider7 field2 > "$screens/gallery-ids-3.txt"
! cmp -s "$screens/gallery-ids-2.txt" "$screens/gallery-ids-3.txt" \
	|| { echo "showing the details did not rebuild the views"; fail=1; }
expect 51
got=$("$ssh" "hey -o $sig get Value of View field3 $W")
[ "$got" = sec ] || { echo "the rebuilt secure field reads '$got', not sec"; fail=1; }
shot details
key "View tabs0" "\$(printf '\\035')"
key "View tabs0" "' '"
expect "Tab: 2"
ids field9 list10 color11 > "$screens/gallery-ids-4.txt"
for c in a b c; do key "View field9" $c; done
expect "Notes: 3 characters"
hey "set Selection 2 of View list10 $W to true"
expect "Selected: Cherry"
# A quoted value is sent as a string, which a text control's Value takes.
hey "set Value of View _red of View color11 $W to '\"200\"'"
key "View _input_ of View _red of View color11" "\$'\\n'"
expect "Color: 200, 102, 153"
ids field9 list10 color11 > "$screens/gallery-ids-5.txt"
same "$screens/gallery-ids-4.txt" "$screens/gallery-ids-5.txt" 3 "editing, selecting or picking a color"
# Sent to the first row, the wheel message goes up the views to the one the scroll bar scrolls.
row=$(texts | grep -x '[0-9]* Row 1' | cut -d' ' -f1)
hey "let View text$row $W do _MWC with 'be:wheel_delta_y=float(3)'"
shot more
SCP=1 "$ssh" -q "vm:$remote/gallery-before.png" "vm:$remote/gallery-after.png" \
	"vm:$remote/gallery-details.png" "vm:$remote/gallery-more.png" "$screens/" || fail=1
# The app can be gone before hey gets the reply, so only the ps check below counts.
"$ssh" "hey -s $sig quit" || true
sleep 1
# Haiku's ps prints whole command lines, so anchor the match to skip grep itself.
"$ssh" "echo '[stdout]'; cat $remote/stdout; echo '[stderr]'; cat $remote/stderr; ! ps | grep -q '^\./Gallery' || { echo still running; kill Gallery; exit 1; }" || fail=1
"$ssh" "rm -rf $remote"
echo "== screenshots: $screens/gallery-{before,after,details,more}.png"
if [ "$fail" -eq 0 ]; then echo "== RESULT: PASS"; else echo "== RESULT: FAIL"; fi
exit "$fail"
