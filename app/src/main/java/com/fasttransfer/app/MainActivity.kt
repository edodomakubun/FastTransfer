package com.fasttransfer.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Color
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.net.InetAddress
import java.net.NetworkInterface

class MainActivity : AppCompatActivity() {

    private var server: TransferServer? = null
    private val port = 8080

    private lateinit var tvStatus: TextView
    private lateinit var tvAddress: TextView
    private lateinit var tvLog: TextView
    private lateinit var btnToggle: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Programmatic UI - 100% bebas error XML/AAPT linking
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 64, 48, 48)
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(Color.parseColor("#F8F9FA"))
        }

        val tvTitle = TextView(this).apply {
            text = "⚡ FastTransfer (Offline)"
            textSize = 24f
            setTextColor(Color.parseColor("#1A73E8"))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }
        layout.addView(tvTitle)

        tvStatus = TextView(this).apply {
            text = "Status: Server Mati"
            textSize = 16f
            setTextColor(Color.GRAY)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }
        layout.addView(tvStatus)

        tvAddress = TextView(this).apply {
            text = "Tekan tombol di bawah untuk memulai"
            textSize = 18f
            setTextColor(Color.DKGRAY)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 40)
        }
        layout.addView(tvAddress)

        btnToggle = Button(this).apply {
            text = "Mulai Server"
            textSize = 16f
            setBackgroundColor(Color.parseColor("#1A73E8"))
            setTextColor(Color.WHITE)
            setPadding(40, 24, 40, 24)
            setOnClickListener { toggleServer() }
        }
        layout.addView(btnToggle)

        val tvLogTitle = TextView(this).apply {
            text = "Log Aktivitas:"
            textSize = 14f
            setTextColor(Color.GRAY)
            setPadding(0, 48, 0, 8)
        }
        layout.addView(tvLogTitle)

        tvLog = TextView(this).apply {
            text = "Menunggu server dinyalakan..."
            textSize = 13f
            setTextColor(Color.DKGRAY)
        }
        val scroll = ScrollView(this).apply {
            addView(tvLog)
        }
        layout.addView(scroll)

        setContentView(layout)
        checkPermissions()
    }

    private fun checkPermissions() {
        val permissions = mutableListOf(
            Manifest.permission.INTERNET,
            Manifest.permission.ACCESS_NETWORK_STATE,
            Manifest.permission.ACCESS_WIFI_STATE
        )
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.S_V2) {
            permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            permissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
        }

        val needed = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (needed.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), 100)
        }
    }

    private fun toggleServer() {
        if (server != null) {
            server?.stop()
            server = null
            tvStatus.text = "Status: Server Mati"
            tvStatus.setTextColor(Color.GRAY)
            tvAddress.text = "Server dinonaktifkan."
            btnToggle.text = "Mulai Server"
            btnToggle.setBackgroundColor(Color.parseColor("#1A73E8"))
        } else {
            val downloadDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "FastTransfer")
            server = TransferServer(port, downloadDir) { msg ->
                runOnUiThread {
                    tvLog.text = "$msg\n${tvLog.text}"
                }
            }
            try {
                server?.start()
                val ip = getIpAddress()
                tvStatus.text = "● Server Aktif (Mendengarkan)"
                tvStatus.setTextColor(Color.parseColor("#34A853"))
                tvAddress.text = "Buka di Browser PC:\nhttp://$ip:$port"
                btnToggle.text = "Hentikan Server"
                btnToggle.setBackgroundColor(Color.parseColor("#D93025"))
            } catch (e: Exception) {
                tvStatus.text = "Gagal menjalankan server: ${e.message}"
            }
        }
    }

    private fun getIpAddress(): String {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()
                val addresses = iface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val addr = addresses.nextElement()
                    if (!addr.isLoopbackAddress && addr.hostAddress.indexOf(':') < 0) {
                        return addr.hostAddress
                    }
                }
            }
        } catch (_: Exception) {}
        return "127.0.0.1"
    }

    override fun onDestroy() {
        server?.stop()
        super.onDestroy()
    }
}
