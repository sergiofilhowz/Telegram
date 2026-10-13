#!/bin/bash
# Evidence scenarios on the dedicated foldable emulator.
# Usage: scenario.sh <restore|install master|install fix|open_chat NAME|home|fold|unfold|front|rec_start NAME|rec_stop NAME|state>
export ANDROID_SERIAL=${ANDROID_SERIAL:-emulator-5560}
A=${ADB:-adb}
SP=${SP:-$(cd "$(dirname "$0")" && pwd)}
PKG=org.telegram.messenger.beta

restore() {
  $A shell am force-stop $PKG
  $A shell run-as $PKG sh -c 'rm -rf files shared_prefs databases cache no_backup app_*' 2>/dev/null
  $A exec-in run-as $PKG tar -xf - -C /data/data/$PKG < $SP/seed_backup.tar
  $A shell cmd connectivity set-chain3-enabled true >/dev/null
  $A shell cmd connectivity set-package-networking-enabled false $PKG >/dev/null
  echo "restored ($($A shell cmd connectivity get-package-networking-enabled $PKG))"
}

# Fresh fake account: get an (unbound) auth key online, cut the network, seed, back up.
make_seed() {
  $A install -r -t $SP/apks/seed-test.apk | tail -1
  $A shell am force-stop $PKG
  $A shell pm clear $PKG >/dev/null
  for p in POST_NOTIFICATIONS READ_MEDIA_IMAGES READ_MEDIA_VIDEO READ_MEDIA_AUDIO READ_CONTACTS; do $A shell pm grant $PKG android.permission.$p 2>/dev/null; done
  $A shell cmd connectivity set-chain3-enabled true >/dev/null
  $A shell cmd connectivity set-package-networking-enabled true $PKG >/dev/null
  launch; sleep 15
  $A shell am force-stop $PKG
  $A shell cmd connectivity set-package-networking-enabled false $PKG >/dev/null
  $A shell am instrument -w org.telegram.messenger.beta.test/org.telegram.mock.SeedInstrumentation | head -1
  launch; sleep 10
  $A shell am force-stop $PKG; sleep 1
  $A exec-out run-as $PKG tar -cf - -C /data/data/$PKG . > $SP/seed_backup.tar
  ls -la $SP/seed_backup.tar
}

install() {
  $A shell am force-stop $PKG
  $A install -r -t $SP/apks/$1-x86_64.apk | tail -1
  for p in POST_NOTIFICATIONS READ_MEDIA_IMAGES READ_MEDIA_VIDEO READ_MEDIA_AUDIO READ_CONTACTS; do $A shell pm grant $PKG android.permission.$p 2>/dev/null; done
}

launch() {
  $A shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
}

wake() {
  $A shell input keyevent KEYCODE_WAKEUP
  $A shell wm dismiss-keyguard
  $A shell dumpsys power | grep -m1 mWakefulness= | sed 's/^ *//'
}
open_chat() { $A shell input tap ${1:-360} ${2:-450}; }
home() { $A shell input keyevent KEYCODE_HOME; }
fold() { $A emu fold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; }
unfold() { $A emu unfold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; }
front() { launch; }

state() {
  $A shell wm size | tail -1
  $A shell dumpsys activity activities | grep -m1 topResumedActivity | sed 's/^ *//'
}

rec_start() {
  $A shell rm -f /sdcard/$1.mp4
  ( $A shell screenrecord --bit-rate 8000000 --time-limit 180 /sdcard/$1.mp4 >/dev/null 2>&1 & )
  sleep 1
}

rec_stop() {
  $A shell pkill -INT screenrecord
  sleep 3
  mkdir -p $SP/rec
  $A pull /sdcard/$1.mp4 $SP/rec/$1.mp4 >/dev/null && echo "$SP/rec/$1.mp4"
}

"$@"
