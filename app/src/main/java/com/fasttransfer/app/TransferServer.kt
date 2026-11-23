package com.fasttransfer.app

import fi.iki.elonen.NanoHTTPD
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.URLEncoder

class TransferServer(
    port: Int,
    private val storageDir: File,
    private val onLog: (String) -> Unit
) : NanoHTTPD(port) {

    init {
        if (!storageDir.exists()) {
            storageDir.mkdirs()
        }
    }

    override fun serve(session: IHTTPSession): Response {
        val uri = session.uri
        val method = session.method

        if (method == Method.GET && uri == "/") {
            return newFixedLengthResponse(Response.Status.OK, "text/html; charset=UTF-8", getHtmlPage())
        }

        if (method == Method.GET && uri.startsWith("/download/")) {
            val fileName = uri.removePrefix("/download/")
            val file = File(storageDir, fileName)
            if (file.exists() && file.isFile) {
                val fis = FileInputStream(file)
                val res = newFixedLengthResponse(Response.Status.OK, "application/octet-stream", fis, file.length())
                res.addHeader("Content-Disposition", "attachment; filename=\"${URLEncoder.encode(file.name, "UTF-8")}\"")
                return res
            }
            return newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "File not found")
        }

        if (method == Method.POST && uri == "/upload") {
            try {
                val files = HashMap<String, String>()
                session.parseBody(files)
                val params = session.parameters

                for ((key, tmpFilePath) in files) {
                    val originalName = params[key]?.firstOrNull() ?: "file_${System.currentTimeMillis()}"
                    val tmpFile = File(tmpFilePath)
                    val destFile = File(storageDir, originalName)

                    tmpFile.copyTo(destFile, overwrite = true)
                    tmpFile.delete()
                    onLog("File diterima: $originalName (${destFile.length() / (1024 * 1024)} MB)")
                }

                return newFixedLengthResponse(Response.Status.OK, "text/plain", "SUCCESS")
            } catch (e: Exception) {
                return newFixedLengthResponse(Response.Status.INTERNAL_ERROR, "text/plain", "Error: ${e.message}")
            }
        }

        return newFixedLengthResponse(Response.Status.NOT_FOUND, "text/plain", "Not Found")
    }

    private fun getHtmlPage(): String {
        val files = storageDir.listFiles()?.filter { it.isFile } ?: emptyList()
        val fileListHtml = StringBuilder()

        for (f in files) {
            val sizeMb = String.format("%.2f MB", f.length().toDouble() / (1024 * 1024))
            fileListHtml.append("""
                <li style="display:flex; justify-content:space-between; padding:10px 0; border-bottom:1px solid #eee;">
                    <span><b>${f.name}</b> ($sizeMb)</span>
                    <a href="/download/${f.name}" style="background:#4CAF50; color:white; padding:6px 14px; text-decoration:none; border-radius:6px; font-weight:bold;">Download</a>
                </li>
            """.trimIndent())
        }

        if (files.isEmpty()) {
            fileListHtml.append("<p style='color:#888;'>Belum ada file di penyimpanan FastTransfer.</p>")
        }

        return """
            <!DOCTYPE html>
            <html lang="id">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>FastTransfer ⚡ Jaringan Lokal</title>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f4f6f9; color: #333; margin: 0; padding: 20px; }
                    .container { max-width: 650px; margin: 0 auto; background: white; border-radius: 14px; padding: 24px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
                    h1 { color: #1a73e8; margin-top: 0; display:flex; align-items:center; gap:8px; }
                    .drop-zone { border: 2px dashed #1a73e8; background: #e8f0fe; border-radius: 12px; padding: 36px 20px; text-align: center; cursor: pointer; transition: 0.2s; }
                    .drop-zone:hover { background: #d2e3fc; }
                    .progress-box { display: none; margin-top: 18px; padding: 14px; background: #f8f9fa; border-radius: 8px; border: 1px solid #ddd; }
                    .progress-bar { width: 0%; height: 12px; background: #34a853; border-radius: 6px; transition: width 0.1s; }
                    .speed-tag { font-size: 14px; font-weight: bold; color: #d93025; margin-top: 6px; display: block; }
                    ul { list-style: none; padding: 0; margin-top: 10px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>⚡ FastTransfer Offline</h1>
                    <p style="color:#666;">Transfer file berkecepatan tinggi langsung via Wi-Fi/Hotspot lokal tanpa kuota.</p>
                    
                    <div class="drop-zone" id="dropZone" onclick="document.getElementById('fileInput').click()">
                        <h3 style="margin:0;">📁 Tarik (Drag & Drop) File ke Sini</h3>
                        <p style="color:#555; margin:8px 0 0 0;">atau klik untuk memilih foto, video, atau dokumen</p>
                        <input type="file" id="fileInput" multiple style="display:none;" onchange="handleFiles(this.files)">
                    </div>

                    <div class="progress-box" id="progressBox">
                        <div style="background:#e0e0e0; border-radius:6px; overflow:hidden;">
                            <div class="progress-bar" id="progressBar"></div>
                        </div>
                        <span class="speed-tag" id="speedTag">Mengirim...</span>
                    </div>

                    <h3 style="margin-top:30px;">📂 File di HP Anda:</h3>
                    <ul>$fileListHtml</ul>
                </div>

                <script>
                    const dropZone = document.getElementById('dropZone');
                    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eName => {
                        dropZone.addEventListener(eName, e => e.preventDefault(), false);
                    });

                    dropZone.addEventListener('drop', e => {
                        const dt = e.dataTransfer;
                        handleFiles(dt.files);
                    });

                    function handleFiles(files) {
                        if (!files || files.length === 0) return;
                        const box = document.getElementById('progressBox');
                        const bar = document.getElementById('progressBar');
                        const speedTag = document.getElementById('speedTag');
                        box.style.display = 'block';

                        for (let i = 0; i < files.length; i++) {
                            const file = files[i];
                            const formData = new FormData();
                            formData.append(file.name, file);

                            const xhr = new XMLHttpRequest();
                            let lastTime = Date.now();
                            let lastLoaded = 0;

                            xhr.upload.onprogress = function(e) {
                                if (e.lengthComputable) {
                                    const percent = (e.loaded / e.total) * 100;
                                    bar.style.width = percent + '%';

                                    const now = Date.now();
                                    const timeDiff = (now - lastTime) / 1000;
                                    if (timeDiff >= 0.3) {
                                        const bytesDiff = e.loaded - lastLoaded;
                                        const speedMB = (bytesDiff / (1024 * 1024)) / timeDiff;
                                        speedTag.innerText = '⚡ Kecepatan: ' + speedMB.toFixed(1) + ' MB/s (' + Math.round(percent) + '%)';
                                        lastTime = now;
                                        lastLoaded = e.loaded;
                                    }
                                }
                            };

                            xhr.onload = function() {
                                if (xhr.status === 200) {
                                    speedTag.innerText = '✅ Selesai dikirim!';
                                    setTimeout(() => location.reload(), 1000);
                                } else {
                                    speedTag.innerText = '❌ Gagal mengirim: ' + xhr.statusText;
                                }
                            };

                            xhr.open('POST', '/upload', true);
                            xhr.send(formData);
                        }
                    }
                </script>
            </body>
            </html>
        """.trimIndent()
    }
}
