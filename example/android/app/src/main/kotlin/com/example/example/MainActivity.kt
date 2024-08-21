package com.example.example

import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity(){
    private val CHANNEL = "com.example.mic_volume/mic"
    private var mediaRecorder: MediaRecorder? = null

    override fun onStart() {
        super.onStart()

        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "startChecking" -> startChecking(result)
                    "stopChecking" -> stopChecking(result)
                    "getMicLevel" -> result.success(getMicLevel())
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun startChecking(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), 1)
            result.error("PERMISSION_DENIED", "Microphone permission denied", null)
            return
        }

        mediaRecorder = MediaRecorder().apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.DEFAULT) // No need to set output file or encoder
            setAudioEncoder(MediaRecorder.AudioEncoder.DEFAULT)
            setOutputFile("/dev/null") // No recording, just checking levels
            prepare()
            start()
        }
        result.success(null)
    }

    private fun stopChecking(result: MethodChannel.Result) {
        mediaRecorder?.apply {
            stop()
            release()
        }
        mediaRecorder = null
        result.success(null)
    }

    private fun getMicLevel(): Double {
        return mediaRecorder?.maxAmplitude?.toDouble()?.div(32767) ?: 0.0
    }
}
