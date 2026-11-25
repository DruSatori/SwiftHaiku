#!/bin/sh
# Cross-build (build-cross.sh), copy the programs to the VM's /boot/home/SwiftHaiku-demo, start
# Gallery in the VM's desktop and drive each control through `hey` scripting, reading back the
# text bound to its state after each change: the check box and the slider get key downs
# (" " and B_RIGHT_ARROW), a radio button a " ", the secure field typed keys, and the pop-up
# menu an execute of its item. Then it checks that the slider change kept the same native views
# (same messengers, see run-vm.sh), and that ticking "Show details" adds the details section with
# new native views (a rebuild). Screenshots land in .build/screens/gallery-{before,after,details}.png.
# Leaves nothing on the VM.
# Usage: VM=<name> run-gallery-vm.sh (the VM's desktop must be running). Exits 0 if every hey
# command succeeded, Gallery quit, every bound text and view check matched and the screenshots came
# back; look at the PNGs.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
rs=$(cd "${RENKUOS_SWIFT:-$here/../RenkuOS-Swift}" && pwd)
ssh=$(cd "$rs/../RenkuOS-on-Parallels/build-vm" && pwd)/ssh.sh
remote=/boot/home/SwiftHaiku-demo
sig=application/x-vnd.swifthaiku-galleryapp
screens=$here/.build/screens
# Gallery's control view names; its texts are named text<n>, n counting every leaf view.
toggle=toggle3 menu=picker4 radio=picker5 slider=slider6 secure=field2 details=toggle7

"$here/scripts/build-cross.sh"
mkdir -p "$screens"
rm -f "$screens"/gallery-*
echo "== run on $(PRINT_IP=1 "$ssh")"
"$ssh" "rm -rf $remote"
SCP=1 "$ssh" -q -r "$here/.build/haiku-arm64/app" "vm:$remote"
fail=0
shot() { "$ssh" "screenshot -s $remote/gallery-$1.png; test -s $remote/gallery-$1.png" || fail=1; }
hey() { "$ssh" "hey -s $sig $*" || { echo "hey failed: $*"; fail=1; }; }
# expect <text view number> <text>: the bound text must read <text>.
expect() {
	got=$("$ssh" "sleep 0.5; hey -o $sig get Text of View text$1 of Window 0")
	echo "text$1: $got"
	[ "$got" = "$2" ] || { echo "  expected: $2"; fail=1; }
}
# The first 12 bytes of a flattened BMessenger are its port, handler token and team.
ids() {
	for v in "View $slider of Window 0" "View text15 of Window 0"; do
		"$ssh" "hey $sig get Messenger of $v" | grep '"result"' | cut -d: -f2 | cut -d, -f1-12
	done
}

"$ssh" "cd $remote && (./Gallery > stdout 2> stderr &) && sleep 3" || fail=1
shot before
hey "let View $toggle of Window 0 do _KYD with 'bytes= '"
expect 7 "Enabled: yes"
hey "do MenuItem 2 of Menu 0 of View 0 of View $menu of Window 0"
expect 9 "Size: Large"
# View 0 of the radio picker is its title.
hey "let View 2 of View $radio of Window 0 do _KYD with 'bytes= '"
expect 11 "Flavor: Chocolate"
for c in s e c; do hey "let View _input_ of View $secure of Window 0 do _KYD with bytes=$c"; done
expect 5 "Password: 3 characters"
ids > "$screens/gallery-views-before.txt"
hey "let View $slider of Window 0 do _KYD with bytes=\$(printf '\\035')"
expect 15 51
ids > "$screens/gallery-views-after.txt"
[ "$(wc -l < "$screens/gallery-views-before.txt")" -eq 2 ] \
	&& cmp -s "$screens/gallery-views-before.txt" "$screens/gallery-views-after.txt" \
	|| { echo "the slider change rebuilt the views"; fail=1; }
shot after
hey "let View $details of Window 0 do _KYD with 'bytes= '"
ids > "$screens/gallery-views-details.txt"
! cmp -s "$screens/gallery-views-after.txt" "$screens/gallery-views-details.txt" \
	|| { echo "showing the details did not rebuild the views"; fail=1; }
expect 19 "This section is added and removed by a rebuild."
expect 15 51
got=$("$ssh" "hey -o $sig get Value of View $secure of Window 0")
[ "$got" = sec ] || { echo "the rebuilt secure field reads '$got', not sec"; fail=1; }
shot details
SCP=1 "$ssh" -q "vm:$remote/gallery-before.png" "vm:$remote/gallery-after.png" \
	"vm:$remote/gallery-details.png" "$screens/" || fail=1
# The app can be gone before hey gets the reply, so only the ps check below counts.
"$ssh" "hey -s $sig quit" || true
sleep 1
# Haiku's ps prints whole command lines, so anchor the match to skip grep itself.
"$ssh" "echo '[stdout]'; cat $remote/stdout; echo '[stderr]'; cat $remote/stderr; ! ps | grep -q '^\./Gallery' || { echo still running; kill Gallery; exit 1; }" || fail=1
"$ssh" "rm -rf $remote"
echo "== screenshots: $screens/gallery-before.png $screens/gallery-after.png $screens/gallery-details.png"
if [ "$fail" -eq 0 ]; then echo "== RESULT: PASS"; else echo "== RESULT: FAIL"; fi
exit "$fail"
