#!/bin/sh
# Cross-build (build-cross.sh), copy the programs to the VM's /boot/home/SwiftHaiku-demo, run
# SwiftHaikuChecks, then start Counter in the VM's desktop and screenshot it; press its button
# twice and type into its text field through `hey` scripting, screenshot again, and quit it. The
# screenshots land in .build/screens/{before,after}.png: "Count: 0" / "Hello, !" before, and
# "Count: 2" / "Hello, Haiku!" after. Leaves nothing on the VM.
# The button is pressed with a B_KEY_DOWN (" ") sent straight to the BButton's own messenger
# (`let ... do`), since BView ignores key messages that still carry specifiers; the text field
# gets a mouse down/up and then key downs the same way, on its inner BTextView "_input_".
# The count text and the field must stay the same native views across the presses (same port,
# handler token and team in their messengers), which shows the content was updated in place
# rather than rebuilt.
# Usage: VM=<name> run-vm.sh (the VM's desktop must be running). Exits 0 if the checks passed,
# every hey command and quit succeeded, the views were kept, the field reads "Haiku" and both
# screenshots came back; look at the PNGs.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
rs=$(cd "${RENKUOS_SWIFT:-$here/../RenkuOS-Swift}" && pwd)
ssh=$(cd "$rs/../RenkuOS-on-Parallels/build-vm" && pwd)/ssh.sh
remote=/boot/home/SwiftHaiku-demo
sig=application/x-vnd.swifthaiku-counterapp
screens=$here/.build/screens

"$here/scripts/build-cross.sh"
rm -rf "$screens"
mkdir -p "$screens"
echo "== run on $(PRINT_IP=1 "$ssh")"
"$ssh" "rm -rf $remote"
SCP=1 "$ssh" -q -r "$here/.build/haiku-arm64/app" "vm:$remote"
fail=0
"$ssh" "cd $remote && ./SwiftHaikuChecks" || fail=1
# screenshot -s exits 112 even when it saved the file, hence the test -s.
shot() { "$ssh" "screenshot -s $remote/$1.png; test -s $remote/$1.png" || fail=1; }
"$ssh" "cd $remote && (./Counter > stdout 2> stderr &) && sleep 3" || fail=1
shot before
# The first 12 bytes of a flattened BMessenger are its port, handler token and team.
ids() {
	for v in "View 0 of View 0 of View 0 of View 0 of Window 0" "View field1 of Window 0"; do
		"$ssh" "hey $sig get Messenger of $v" | grep '"result"' | cut -d: -f2 | cut -d, -f1-12
	done
}
ids > "$screens/views-before.txt"
for i in 1 2; do
	"$ssh" "hey $sig let View button0 of Window 0 do _KYD with 'bytes= '" || fail=1
done
ids > "$screens/views-after.txt"
cat "$screens/views-after.txt"
[ "$(wc -l < "$screens/views-before.txt")" -eq 2 ] && cmp -s "$screens/views-before.txt" "$screens/views-after.txt" \
	|| { echo "the views were rebuilt, not updated in place"; fail=1; }
# Click into the field, then type one key at a time: each key refreshes the window, so the text
# only comes out in order if the focus and caret survive the refresh.
field="View _input_ of View field1 of Window 0"
"$ssh" "hey $sig let $field do _MDN with 'screen_where=BPoint(200,190)' and 'buttons=int32(1)' and 'clicks=int32(1)' && hey $sig let $field do _MUP with 'screen_where=BPoint(200,190)'" || fail=1
for c in H a i k u; do "$ssh" "hey -s $sig let $field do _KYD with bytes=$c" || fail=1; done
"$ssh" "sleep 1; hey -o $sig get Value of View field1 of Window 0" | tee "$screens/field.txt"
[ "$(cat "$screens/field.txt")" = Haiku ] || { echo "field text is not Haiku"; fail=1; }
shot after
SCP=1 "$ssh" -q "vm:$remote/before.png" "vm:$remote/after.png" "$screens/" || fail=1
"$ssh" "hey -s $sig quit" || fail=1
sleep 1
# Haiku's ps prints whole command lines, so anchor the match to skip grep itself.
"$ssh" "echo '[stdout]'; cat $remote/stdout; echo '[stderr]'; cat $remote/stderr; ! ps | grep -q '^\./Counter' || { echo still running; kill Counter; exit 1; }" || fail=1
"$ssh" "rm -rf $remote"
echo "== screenshots: $screens/before.png $screens/after.png"
if [ "$fail" -eq 0 ]; then echo "== RESULT: PASS"; else echo "== RESULT: FAIL"; fi
exit "$fail"
