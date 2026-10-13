#!/bin/bash
# Records one evidence scenario on the dedicated emulator.
# Usage: rec.sh <scenario> <build: master|fix>
# Output: rec/<scenario>_<build>.mp4 (raw) + rec/<scenario>_<build>.steps (t<TAB>caption)
export ANDROID_SERIAL=${ANDROID_SERIAL:-emulator-5560}
A=${ADB:-adb}
SP=${SP:-$(cd "$(dirname "$0")" && pwd)}
S=$SP/scenario.sh
SCEN=$1
BUILD=$2
NAME=${SCEN}_${BUILD}
STEPS=$SP/rec/$NAME.steps
T0=0

step() {
  printf '%s\t%s\n' "$(python3 -c "import time;print(round(time.time()-$T0,2))")" "$1" >> $STEPS
}

start_rec() {
  : > $STEPS
  $A shell rm -f /sdcard/$NAME.mp4
  ( $A shell screenrecord --bit-rate 8000000 --time-limit 180 /sdcard/$NAME.mp4 >/dev/null 2>&1 & )
  sleep 0.8
  T0=$(python3 -c "import time;print(time.time())")
}

stop_rec() {
  sleep 1
  $A shell pkill -INT screenrecord
  sleep 3
  $A pull /sdcard/$NAME.mp4 $SP/rec/$NAME.mp4 >/dev/null && echo "$SP/rec/$NAME.mp4"
}

back_gesture_start() {
  $A shell "input motionevent DOWN 20 1200; sleep 0.15; input motionevent MOVE 60 1200; sleep 0.15; input motionevent MOVE 100 1200; sleep 0.15; input motionevent MOVE 140 1201"
}
back_gesture_cancel() {
  $A shell "input motionevent MOVE 80 1201; sleep 0.15; input motionevent MOVE 30 1201; sleep 0.15; input motionevent MOVE 5 1201; sleep 0.2; input motionevent UP 5 1201"
}

$S install $BUILD >/dev/null
$A shell settings put system show_touches 1
$A shell settings put system fold_lock_behavior_setting stay_awake_on_fold_key

case $SCEN in
  gesture)
    # Fold/unfold while the system back gesture is in progress.
    $S fold; $S restore >/dev/null; $S wake >/dev/null; $S launch; sleep 6; $S open_chat 400 450; sleep 2
    start_rec
    step "1. Chat aberto, aparelho dobrado"; sleep 2
    step "2. Inicia o gesto de voltar"; back_gesture_start; sleep 0.6
    step "3. Desdobra no meio do gesto"; $A emu unfold >/dev/null; sleep 2.5
    step "4. Desiste do gesto (dedo volta a borda)"; back_gesture_cancel; sleep 3
    step "5. Abre outra conversa"; $A shell input tap 400 1100; sleep 3
    step "6. Dobra de novo"; $A emu fold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; sleep 3
    stop_rec
    ;;
  background)
    # Fold/unfold while the app is in background, then come back.
    $S unfold; $S restore >/dev/null; $S wake >/dev/null; $S launch; sleep 6; $S open_chat; sleep 2
    start_rec
    step "1. Chat aberto, aparelho desdobrado"; sleep 2
    step "2. App em segundo plano (Home)"; $S home; sleep 2
    step "3. Dobra em segundo plano"; $A emu fold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; sleep 1.5
    step "4. Desdobra em segundo plano"; $A emu unfold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; sleep 1.5
    step "5. Dobra em segundo plano"; $A emu fold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; sleep 1.5
    step "6. Volta ao app (dobrado)"; $S front; sleep 3
    step "7. Desdobra com o app aberto"; $A emu unfold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; sleep 3
    step "8. Home, dobra e volta ao app"; $S home; sleep 1.5; $A emu fold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; sleep 1; $S front; sleep 3
    stop_rec
    ;;
  rapid)
    # Many quick fold/unfold toggles with the chat open.
    $S unfold; $S restore >/dev/null; $S wake >/dev/null; $S launch; sleep 6; $S open_chat; sleep 2
    start_rec
    step "1. Chat aberto, aparelho desdobrado"; sleep 2
    step "2. Dobra/desdobra 6x rapidamente"; for i in 1 2 3 4 5 6; do $A emu fold >/dev/null; sleep 0.4; $A emu unfold >/dev/null; sleep 0.4; done
    sleep 1; $A shell wm dismiss-keyguard; sleep 2
    step "3. Resultado desdobrado"; sleep 2
    step "4. Dobra"; $A emu fold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; sleep 3
    stop_rec
    ;;
  deeplink)
    # Layout mode changes in background, then the app is opened by a link (same path as a notification).
    $S fold; $S restore >/dev/null; $S wake >/dev/null; $S launch; sleep 6
    start_rec
    step "1. Lista de conversas, aparelho dobrado"; sleep 2
    step "2. App em segundo plano (Home)"; $S home; sleep 2
    step "3. Desdobra em segundo plano"; $A emu unfold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; sleep 1.5
    step "4. Abre conversa por link (como notificacao)"; $A shell am start -a android.intent.action.VIEW -d "tg://openmessage?user_id=100000004" org.telegram.messenger.beta >/dev/null; sleep 3
    step "5. Home, dobra e abre outra conversa por link"; $S home; sleep 1.5; $A emu fold >/dev/null; sleep 1; $A shell wm dismiss-keyguard; sleep 1; $A shell am start -a android.intent.action.VIEW -d "tg://openmessage?user_id=100000006" org.telegram.messenger.beta >/dev/null; sleep 3
    stop_rec
    ;;
esac
cat $STEPS
