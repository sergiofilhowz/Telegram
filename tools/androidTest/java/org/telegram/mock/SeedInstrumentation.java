package org.telegram.mock;

import android.app.Activity;
import android.app.Instrumentation;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import org.telegram.messenger.ApplicationLoader;
import org.telegram.messenger.MessagesController;
import org.telegram.messenger.MessagesStorage;
import org.telegram.messenger.UserConfig;
import org.telegram.tgnet.TLRPC;

import java.util.ArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Evidence tooling only (not part of the fix): seeds a fake, offline account
 * (self user, contacts and chat history) straight into the local cache so the
 * app opens logged in without talking to Telegram servers.
 *
 * adb shell am instrument -w org.telegram.messenger.beta.test/org.telegram.mock.SeedInstrumentation
 */
public class SeedInstrumentation extends Instrumentation {

    private static final String TAG = "FoldSeed";
    private static final long SELF_ID = 100000001L;

    private static final String[][] CONTACTS = {
            {"Ana", "Souza"},
            {"Bruno", "Lima"},
            {"Carla", "Mendes"},
            {"Diego", "Rocha"},
            {"Fernanda", "Alves"},
            {"Gustavo", "Pereira"},
            {"Helena", "Costa"},
    };

    private static final String[] LINES = {
            "Oi! Tudo certo por aí?",
            "Tudo ótimo, e você?",
            "Bem também. Vamos almoçar amanhã?",
            "Bora! Meio-dia?",
            "Fechado, no lugar de sempre",
            "Você viu o e-mail da reunião?",
            "Vi sim, mudou para quinta às 10h",
            "Perfeito, já atualizei a agenda",
            "Me manda o arquivo da apresentação?",
            "Mando daqui a pouco",
            "Valeu!",
            "Chegou aí?",
            "Chegou, obrigado 🙌",
            "Depois me fala o que achou",
            "Ficou muito bom",
            "Só ajustaria o slide 4",
            "Boa, vou ajustar",
            "Pronto, atualizado",
            "Show!",
            "Até amanhã!",
    };

    @Override
    public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        start();
    }

    @Override
    public void onStart() {
        Bundle result = new Bundle();
        try {
            Log.i(TAG, "waiting for main thread");
            waitForIdleSync();
            Log.i(TAG, "main thread idle, seeding");
            CountDownLatch seeded = new CountDownLatch(1);
            new Handler(Looper.getMainLooper()).post(() -> {
                try {
                    Log.i(TAG, "seed start");
                    seed();
                } catch (Throwable t) {
                    Log.e(TAG, "seed failed", t);
                    result.putString("error", Log.getStackTraceString(t));
                }
                seeded.countDown();
            });
            seeded.await(30, TimeUnit.SECONDS);

            CountDownLatch flushed = new CountDownLatch(1);
            MessagesStorage.getInstance(0).getStorageQueue().postRunnable(flushed::countDown);
            flushed.await(30, TimeUnit.SECONDS);
            // UserConfig.saveConfig() uses SharedPreferences.apply(); give it time to hit disk
            Thread.sleep(3000);

            result.putString("seed", result.containsKey("error") ? "failed" : "ok");
            finish(result.containsKey("error") ? Activity.RESULT_CANCELED : Activity.RESULT_OK, result);
        } catch (Throwable t) {
            result.putString("error", Log.getStackTraceString(t));
            finish(Activity.RESULT_CANCELED, result);
        }
    }

    private static TLRPC.User user(long id, String first, String last, boolean self) {
        TLRPC.TL_user u = new TLRPC.TL_user();
        u.id = id;
        u.access_hash = id * 31;
        u.first_name = first;
        u.last_name = last;
        u.phone = self ? "5511900000000" : null;
        u.self = self;
        u.contact = !self;
        u.mutual_contact = !self;
        u.flags = 1 | 2 | 4 | (self ? 16 : 0);
        return u;
    }

    private static TLRPC.Message message(int id, long dialogId, long fromId, boolean out, int date, String text) {
        TLRPC.TL_message m = new TLRPC.TL_message();
        m.id = id;
        m.out = out;
        m.date = date;
        m.message = text;
        m.dialog_id = dialogId;
        m.from_id = new TLRPC.TL_peerUser();
        m.from_id.user_id = fromId;
        m.peer_id = new TLRPC.TL_peerUser();
        m.peer_id.user_id = dialogId;
        m.media = new TLRPC.TL_messageMediaEmpty();
        m.flags = 256 | 512;
        return m;
    }

    private void seed() {
        final int account = 0;
        ApplicationLoader.postInitApplication();
        UserConfig userConfig = UserConfig.getInstance(account);
        MessagesStorage storage = MessagesStorage.getInstance(account);

        TLRPC.User self = user(SELF_ID, "Fold", "Tester", true);
        ArrayList<TLRPC.User> users = new ArrayList<>();
        users.add(self);
        for (int i = 0; i < CONTACTS.length; i++) {
            users.add(user(SELF_ID + 1 + i, CONTACTS[i][0], CONTACTS[i][1], false));
        }

        int now = (int) (System.currentTimeMillis() / 1000);
        TLRPC.TL_messages_dialogs dialogs = new TLRPC.TL_messages_dialogs();
        dialogs.users.addAll(users);
        ArrayList<TLRPC.TL_messages_messages> histories = new ArrayList<>();

        for (int i = 0; i < CONTACTS.length; i++) {
            long peerId = SELF_ID + 1 + i;
            int count = LINES.length - (i % 4);
            int baseId = (i + 1) * 1000;
            TLRPC.TL_messages_messages history = new TLRPC.TL_messages_messages();
            history.users.addAll(users);
            // newest first, as returned by messages.getHistory
            for (int k = count - 1; k >= 0; k--) {
                boolean out = (k % 2) == 1;
                int date = now - (i * 3600) - (count - k) * 180;
                history.messages.add(message(baseId + k + 1, peerId, out ? SELF_ID : peerId, out, date, LINES[(k + i) % LINES.length]));
            }
            histories.add(history);

            TLRPC.Message top = history.messages.get(0);
            TLRPC.TL_dialog dialog = new TLRPC.TL_dialog();
            dialog.peer = new TLRPC.TL_peerUser();
            dialog.peer.user_id = peerId;
            dialog.id = peerId;
            dialog.top_message = top.id;
            dialog.read_outbox_max_id = top.id;
            dialog.unread_count = 0;
            dialog.read_inbox_max_id = top.id - dialog.unread_count;
            dialog.notify_settings = new TLRPC.TL_peerNotifySettings();
            dialogs.dialogs.add(dialog);
            dialogs.messages.add(top);
        }

        Log.i(TAG, "set current user");
        userConfig.setCurrentUser(self);
        userConfig.syncContacts = false;
        userConfig.draftsLoaded = true;
        userConfig.setDialogsLoadOffset(0, Integer.MAX_VALUE, 0, 0, 0, 0, 0);
        userConfig.setDialogsLoadOffset(1, Integer.MAX_VALUE, 0, 0, 0, 0, 0);
        userConfig.saveConfig(true);

        Log.i(TAG, "config saved");
        storage.putUsersAndChats(users, new ArrayList<>(), true, true);
        storage.putDialogs(dialogs, 0);
        for (int i = 0; i < histories.size(); i++) {
            TLRPC.TL_messages_messages history = histories.get(i);
            storage.putMessages(history, SELF_ID + 1 + i, MessagesController.LOAD_BACKWARD, Integer.MAX_VALUE, false, 0, 0);
        }
        Log.i(TAG, "seeded " + dialogs.dialogs.size() + " dialogs");
    }
}
