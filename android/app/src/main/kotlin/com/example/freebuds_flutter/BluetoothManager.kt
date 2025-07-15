package com.example.freebuds_flutter

import android.Manifest
import android.os.Build
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.*
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

class BluetoothManager(private val context: Context) {
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private var btSocket: BluetoothSocket? = null
    private var outStream: OutputStream? = null
    private var inStream: InputStream? = null
    private var receiverThread: Thread? = null
    private var isRunning = false

    private val incomingDataQueue = LinkedBlockingQueue<ByteArray>()

    private fun hasPermission(permission: String): Boolean =
        ActivityCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

    fun ensurePermissions(): Boolean {
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        val needed = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!hasPermission(Manifest.permission.BLUETOOTH_CONNECT))
                needed += Manifest.permission.BLUETOOTH_CONNECT
            if (!hasPermission(Manifest.permission.BLUETOOTH_SCAN))
                needed += Manifest.permission.BLUETOOTH_SCAN
        } else {
            if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION))
                needed += Manifest.permission.ACCESS_FINE_LOCATION
        }

        if (needed.isEmpty()) return true

        if (context is Activity) {
            ActivityCompat.requestPermissions(context, needed.toTypedArray(), REQUEST_BT_PERMS)
        } else {
            Log.e(TAG, "Cannot request permissions: context isn't Activity")
        }
        return false
    }

    fun findDeviceByName(name: String): BluetoothDevice? {
        if (!ensurePermissions()) return null
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return null

        try {
            adapter.bondedDevices?.forEach { device ->
                Log.d(TAG, "Paired device: ${device.name} (${device.address})")
                if (device.name != null && device.name.contains(name, ignoreCase = true)) {
                    Log.d(TAG, "Found matching device: ${device.name}")
                    return device
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception while searching for devices", e)
        }

        Log.e(TAG, "Device '$name' not found in paired devices")
        return null
    }

    fun connect(address: String): Boolean {
        // First try to find by address, then by name
        val device = findDeviceByAddress(address) ?: findDeviceByName(address)
        return device?.let { connect(it) } ?: false
    }

    private fun findDeviceByAddress(address: String): BluetoothDevice? {
        if (!ensurePermissions()) return null
        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return null

        return try {
            adapter.getRemoteDevice(address)
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Invalid Bluetooth address: $address", e)
            null
        }
    }

    fun connect(device: BluetoothDevice): Boolean {
        if (!hasPermission(Manifest.permission.BLUETOOTH_CONNECT)) {
            Log.e(TAG, "BLUETOOTH_CONNECT permission not granted")
            return false
        }

        try {
            Log.d(TAG, "Attempting to connect to ${device.name} (${device.address})")

            // Close any existing connection
            disconnect()

            btSocket = device.createRfcommSocketToServiceRecord(sppUuid)
            BluetoothAdapter.getDefaultAdapter()?.cancelDiscovery()

            btSocket?.connect()
            outStream = btSocket?.outputStream
            inStream = btSocket?.inputStream

            startReceiver()
            Log.d(TAG, "Connection successful!")
            return true

        } catch (e: IOException) {
            Log.e(TAG, "Connection failed", e)
            try {
                btSocket?.close()
            } catch (closeException: IOException) {
                Log.e(TAG, "Error closing socket", closeException)
            }
            btSocket = null
            outStream = null
            inStream = null
            return false
        }
    }

    private fun startReceiver() {
        if (receiverThread?.isAlive == true) {
            return
        }
        isRunning = true
        receiverThread = Thread {
            Log.d(TAG, "Receiver thread started")
            val stream = inStream ?: return@Thread
            val headerBuffer = ByteArray(4) // To read the fixed-size header: 5A len len 00

            while (isRunning && btSocket?.isConnected == true) {
                try {
                    // --- STEP 1: Read the 4-byte header to get the packet length ---
                    var bytesRead = 0
                    while (bytesRead < headerBuffer.size && isRunning) {
                        val read = stream.read(headerBuffer, bytesRead, headerBuffer.size - bytesRead)
                        if (read == -1) throw IOException("Socket closed")
                        bytesRead += read
                    }

                    // --- STEP 2: Validate the header and calculate body length ---
                    if (headerBuffer[0] != 0x5A.toByte() || headerBuffer[3] != 0x00.toByte()) {
                        Log.e(TAG, "Invalid packet header received. Flushing input and retrying.")
                        while (stream.available() > 0) stream.read() // Clear buffer
                        continue
                    }

                    // The length in the header includes one of the length bytes itself.
                    val bodyLengthWithHeader = (headerBuffer[1].toInt() and 0xFF shl 8) or (headerBuffer[2].toInt() and 0xFF)
                    val remainingLength = (bodyLengthWithHeader - 1) + 2 // -1 for header part, +2 for CRC

                    // --- STEP 3: Read the rest of the packet ---
                    val fullPacket = ByteArray(headerBuffer.size + remainingLength)
                    headerBuffer.copyInto(fullPacket, 0, 0, headerBuffer.size)

                    bytesRead = 0
                    while (bytesRead < remainingLength && isRunning) {
                        val read = stream.read(fullPacket, headerBuffer.size + bytesRead, remainingLength - bytesRead)
                        if (read == -1) throw IOException("Socket closed while reading body")
                        bytesRead += read
                    }

                    // --- STEP 4: Queue the complete, reassembled packet ---
                    incomingDataQueue.offer(fullPacket)
                    Log.d(TAG, "Successfully received and queued a full packet of size ${fullPacket.size}")

                } catch (e: IOException) {
                    if (isRunning) {
                        Log.e(TAG, "Receiver thread error, disconnecting.", e)
                        // In case of an error, it's safer to assume the connection is lost.
                        disconnect()
                    }
                    break
                }
            }
            Log.d(TAG, "Receiver thread stopped")
        }
        receiverThread?.start()
    }

    fun receive(timeoutMs: Long): ByteArray? {
        return try {
            incomingDataQueue.poll(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (e: InterruptedException) {
            Log.e(TAG, "Receive interrupted", e)
            null
        }
    }

    fun send(data: ByteArray): Boolean {
        return try {
            outStream?.write(data)
            outStream?.flush()
            Log.d(TAG, "Sent ${data.size} bytes")
            true
        } catch (e: IOException) {
            Log.e(TAG, "Send failed", e)
            false
        }
    }

    fun isConnected(): Boolean {
        return btSocket?.isConnected == true
    }

    fun disconnect() {
        isRunning = false
        try {
            receiverThread?.interrupt()
            receiverThread?.join(1000)
            btSocket?.close()
            Log.d(TAG, "Disconnected")
        } catch (e: Exception) {
            Log.e(TAG, "Error during disconnect", e)
        } finally {
            btSocket = null
            outStream = null
            inStream = null
            receiverThread = null
            incomingDataQueue.clear()
        }
    }

    companion object {
        private const val TAG = "BluetoothManager"
        const val REQUEST_BT_PERMS = 99
    }
}