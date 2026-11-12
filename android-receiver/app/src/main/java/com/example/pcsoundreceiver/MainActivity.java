package com.example.pcsoundreceiver;

import android.app.Activity;
import android.graphics.Color;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Bundle;
import android.os.PowerManager;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;

/**
 * PCSound Receiver (Android).
 * Слушает UDP-пакеты со звуком (s16le, стерео, 48000 Гц) и играет их через AudioTrack.
 * Интерфейс создаётся полностью программно (без XML), чтобы корректно отображаться
 * на любой версии Android, включая Android 13+.
 */
public class MainActivity extends Activity {

    private static final int PORT = 9999;
    private static final int SAMPLE_RATE = 48000;

    private TextView statusView;
    private Button toggleButton;

    private boolean running = false;
    private Thread receiverThread;
    private DatagramSocket socket;
    private AudioTrack audioTrack;
    private PowerManager.WakeLock wakeLock;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // --- создаём интерфейс полностью в коде ---
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(android.view.Gravity.CENTER);
        root.setBackgroundColor(Color.WHITE);
        root.setPadding(48, 48, 48, 48);
        root.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT));

        statusView = new TextView(this);
        statusView.setText(getString(R.string.status_stopped));
        statusView.setTextSize(18);
        statusView.setTextColor(Color.BLACK);
        LinearLayout.LayoutParams tvParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
        root.addView(statusView, tvParams);

        toggleButton = new Button(this);
        toggleButton.setText(getString(R.string.start));
        toggleButton.setTextColor(Color.BLACK);
        toggleButton.setBackgroundColor(Color.LTGRAY);
        toggleButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                toggle();
            }
        });
        LinearLayout.LayoutParams btnParams = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT);
        btnParams.topMargin = 48;
        root.addView(toggleButton, btnParams);

        setContentView(root);
    }

    private void toggle() {
        if (running) {
            stop();
        } else {
            start();
        }
    }

    private void start() {
        try {
            PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "PCSound:Wake");
            wakeLock.acquire();

            int minBuf = AudioTrack.getMinBufferSize(
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_OUT_STEREO,
                    AudioFormat.ENCODING_PCM_16BIT);
            if (minBuf == AudioTrack.ERROR_BAD_VALUE) {
                minBuf = 2048;
            }

            // Маленький буфер AudioTrack — меньше задержка воспроизведения
            audioTrack = new AudioTrack(
                    AudioManager.STREAM_MUSIC,
                    SAMPLE_RATE,
                    AudioFormat.CHANNEL_OUT_STEREO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    Math.max(minBuf, 2048),
                    AudioTrack.MODE_STREAM);
            audioTrack.play();

            socket = new DatagramSocket(PORT);

            running = true;
            toggleButton.setText(getString(R.string.stop));
            statusView.setText(getString(R.string.status_receiving));

            receiverThread = new Thread(new Runnable() {
                @Override
                public void run() {
                    receiveLoop();
                }
            }, "PCSoundReceiver");
            receiverThread.start();
        } catch (Exception e) {
            statusView.setText(getString(R.string.error, e.toString()));
            stop();
        }
    }

    private void stop() {
        running = false;

        if (receiverThread != null) {
            receiverThread.interrupt();
            receiverThread = null;
        }

        try {
            if (socket != null) {
                socket.close();
            }
        } catch (Exception ignored) {
        }
        socket = null;

        try {
            if (audioTrack != null) {
                audioTrack.stop();
                audioTrack.release();
            }
        } catch (Exception ignored) {
        }
        audioTrack = null;

        try {
            if (wakeLock != null && wakeLock.isHeld()) {
                wakeLock.release();
            }
        } catch (Exception ignored) {
        }
        wakeLock = null;

        toggleButton.setText(getString(R.string.start));
        statusView.setText(getString(R.string.status_stopped));
    }

    private void receiveLoop() {
        // Маленький буфер приёма UDP — обрабатываем пакеты чаще, меньше задержка
        byte[] buf = new byte[2048];
        DatagramPacket packet = new DatagramPacket(buf, buf.length);

        while (running && !Thread.currentThread().isInterrupted()) {
            try {
                socket.receive(packet);
                if (audioTrack != null) {
                    audioTrack.write(packet.getData(), 0, packet.getLength());
                }
            } catch (IOException e) {
                if (running) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            statusView.setText(getString(R.string.error, e.toString()));
                        }
                    });
                }
                break;
            }
        }
    }

    @Override
    protected void onDestroy() {
        stop();
        super.onDestroy();
    }
}
