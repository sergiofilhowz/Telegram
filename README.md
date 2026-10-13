# Evidências — fix/fold-layout-switch

Vídeos gravados no emulador Android para o PR `fix/fold-layout-switch`
(tela em branco/preta e travamentos ao dobrar/desdobrar foldables).

## Ambiente

- Emulador **Pixel 9 Pro Fold**, Android 16 (API 36, `google_apis` x86_64), fold/unfold via `adb emu fold|unfold`.
- APKs `afatDebug` x86_64: `master` (`f32ffeec7`) e `fix/fold-layout-switch` (`e38634ca8`), mesma assinatura e mesmos dados.
- **Conta 100% mockada e offline**: o servidor de testes do Telegram recusa os códigos de login
  de teste (`PHONE_CODE_INVALID`), então os dados foram semeados localmente por uma instrumentação
  (`tools/androidTest`) e a rede do app foi bloqueada no firewall do Android
  (`cmd connectivity set-package-networking-enabled false`). Por isso o título mostra "Connecting…".
- "Mostrar toques" ligado para o gesto aparecer na gravação. A tela "Swipe up to continue" que aparece
  ~1 s após dobrar é o comportamento padrão do Pixel ao dobrar, não do app.

## Vídeos

| Arquivo | Build | Cenário |
|---|---|---|
| `videos/gesture_master_vs_fix.mp4` / `.gif` | ambos | lado a lado do cenário abaixo |
| `videos/gesture_master.mp4` | master | **reproduz**: desdobrar durante o gesto de voltar deixa a lista presa/escurecida; ao dobrar de novo o app fica com a tela preta |
| `videos/gesture_fix.mp4` | fix | mesmos passos, layout correto em todas as etapas |
| `videos/background_fix.mp4` / `.gif` | fix | dobrar/desdobrar com o app em segundo plano e voltar (cenário relatado no Z Fold 7) |
| `videos/rapid_fix.mp4` | fix | 6 dobras/desdobras rápidas com o chat aberto |
| `videos/deeplink_fix.mp4` | fix | troca de modo em segundo plano e abertura de conversa por link (mesmo caminho de uma notificação) |

## Como reproduzir

1. Compile os APKs (`./gradlew :TMessagesProj_App:assembleAfatDebug -Pandroid.injected.build.abi=x86_64`) do `master` e do branch e
   copie para `tools/apks/master-x86_64.apk` e `tools/apks/fix-x86_64.apk`.
2. Copie `tools/androidTest` para `TMessagesProj_App/src/androidTest`, rode `assembleAfatDebugAndroidTest` e copie o APK para
   `tools/apks/seed-test.apk`.
3. Com o emulador dobrável ligado: `ANDROID_SERIAL=emulator-XXXX tools/scenario.sh install master && tools/scenario.sh make_seed`
   (gera `seed_backup.tar` com a conta falsa).
4. `tools/rec.sh gesture master`, `tools/rec.sh gesture fix`, etc. Cada execução restaura os mesmos dados antes de gravar.
