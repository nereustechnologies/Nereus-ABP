package com.example.nereus_abp_app

import android.content.Context
import android.graphics.Bitmap
import android.renderscript.Allocation
import android.renderscript.Element
import android.renderscript.RenderScript
import android.renderscript.ScriptIntrinsicYuvToRGB
import android.renderscript.Type

class FastYuvToRgbConverter(context: Context) {

    private val rs: RenderScript = RenderScript.create(context)
    private val scriptYuvToRgb: ScriptIntrinsicYuvToRGB =
        ScriptIntrinsicYuvToRGB.create(rs, Element.U8_4(rs))

    private var yuvBuffer: ByteArray? = null
    private var inputAllocation: Allocation? = null
    private var outputAllocation: Allocation? = null

    fun yuv420ToBitmap(
        y: ByteArray,
        u: ByteArray,
        v: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uRowStride: Int,
        vRowStride: Int,
        uPixelStride: Int,
        vPixelStride: Int,
        bitmap: Bitmap
    ) {
        val nv21Size = width * height + (width * height / 2)

        if (yuvBuffer == null || yuvBuffer!!.size != nv21Size) {
            yuvBuffer = ByteArray(nv21Size)
        }

        val nv21 = yuvBuffer!!

        // Copy Y plane row by row
        var pos = 0
        for (row in 0 until height) {
            System.arraycopy(y, row * yRowStride, nv21, pos, width)
            pos += width
        }

        // Copy UV planes into NV21 format (VU interleaved)
        val uvHeight = height / 2
        val uvWidth = width / 2

        var uvPos = width * height

        for (row in 0 until uvHeight) {
            var uRowStart = row * uRowStride
            var vRowStart = row * vRowStride

            for (col in 0 until uvWidth) {
                val uIndex = uRowStart + col * uPixelStride
                val vIndex = vRowStart + col * vPixelStride

                nv21[uvPos++] = v[vIndex] // V
                nv21[uvPos++] = u[uIndex] // U
            }
        }

        if (inputAllocation == null) {
            val yuvType = Type.Builder(rs, Element.U8(rs))
                .setX(nv21.size)

            inputAllocation = Allocation.createTyped(
                rs,
                yuvType.create(),
                Allocation.USAGE_SCRIPT
            )

            val rgbaType = Type.Builder(rs, Element.RGBA_8888(rs))
                .setX(width)
                .setY(height)

            outputAllocation = Allocation.createTyped(
                rs,
                rgbaType.create(),
                Allocation.USAGE_SCRIPT
            )
        }

        inputAllocation!!.copyFrom(nv21)
        scriptYuvToRgb.setInput(inputAllocation)
        scriptYuvToRgb.forEach(outputAllocation)
        outputAllocation!!.copyTo(bitmap)
    }

    fun release() {
        inputAllocation?.destroy()
        outputAllocation?.destroy()
        scriptYuvToRgb.destroy()
        rs.destroy()
    }
}
