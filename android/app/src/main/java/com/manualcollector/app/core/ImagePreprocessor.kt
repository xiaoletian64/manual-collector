package com.manualcollector.app.core

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.opencv.android.Utils
import org.opencv.core.Core
import org.opencv.core.CvType
import org.opencv.core.Mat
import org.opencv.core.Point
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.imgproc.CLAHE
import org.opencv.imgproc.Imgproc
import java.io.File

data class PreprocessedImage(
    val bitmap: Bitmap,
    val width: Int,
    val height: Int,
)

class ImagePreprocessor {

    suspend fun preprocess(
        imagePath: String,
        enhanceContrast: Boolean = true,
        denoise: Boolean = true,
        doBinarize: Boolean = true,
    ): PreprocessedImage = withContext(Dispatchers.Default) {
        val srcMat = loadImage(imagePath)
        var processed = srcMat.clone()

        if (denoise) {
            processed = applyDenoise(processed)
        }

        if (enhanceContrast) {
            processed = applyCLAHE(processed)
        }

        processed = applyAdaptiveThreshold(processed)

        processed = sharpenEdges(processed)

        val bitmap = Bitmap.createBitmap(processed.cols(), processed.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(processed, bitmap)

        processed.release()
        srcMat.release()

        PreprocessedImage(
            bitmap = bitmap,
            width = bitmap.width,
            height = bitmap.height,
        )
    }

    private fun loadImage(path: String): Mat {
        val bitmap = BitmapFactory.decodeFile(path) ?: error("Cannot decode $path")
        val corrected = correctOrientation(bitmap, path)
        val mat = Mat()
        Utils.bitmapToMat(corrected, mat)
        Imgproc.cvtColor(mat, mat, Imgproc.COLOR_RGBA2GRAY)
        return mat
    }

    private fun correctOrientation(bitmap: Bitmap, path: String): Bitmap {
        try {
            val exif = ExifInterface(path)
            val orientation = exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
            val matrix = Matrix()
            when (orientation) {
                ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
                ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
                ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
                else -> return bitmap
            }
            return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        } catch (_: Exception) {
            return bitmap
        }
    }

    private fun applyDenoise(src: Mat): Mat {
        val dst = Mat()
        Imgproc.fastNlMeansDenoising(src, dst, 30.0, 7, 21)
        return dst
    }

    private fun applyCLAHE(src: Mat): Mat {
        val dst = Mat()
        val clahe: CLAHE = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
        clahe.apply(src, dst)
        return dst
    }

    private fun applyAdaptiveThreshold(src: Mat): Mat {
        val dst = Mat()
        Imgproc.adaptiveThreshold(
            src, dst,
            255.0,
            Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C,
            Imgproc.THRESH_BINARY,
            11,
            2.0,
        )
        return dst
    }

    private fun sharpenEdges(src: Mat): Mat {
        val dst = Mat()
        val kernel = Mat(3, 3, CvType.CV_32F)
        kernel.put(0, 0, 0.0, -1.0, 0.0, -1.0, 5.0, -1.0, 0.0, -1.0, 0.0)
        Imgproc.filter2D(src, dst, -1, kernel)
        return dst
    }

    fun detectEdges(src: Mat): Mat {
        val edges = Mat()
        Imgproc.Canny(src, edges, 50.0, 150.0)
        return edges
    }

    private fun findLargestContour(edges: Mat): List<Point> {
        val contours = mutableListOf<android.graphics.Point>()
        val hierarchy = Mat()
        val contourMat = mutableListOf<Mat>()
        Imgproc.findContours(
            edges, contourMat, hierarchy,
            Imgproc.RETR_EXTERNAL,
            Imgproc.CHAIN_APPROX_SIMPLE,
        )
        if (contourMat.isEmpty()) return emptyList()

        val largest = contourMat.maxByOrNull { Imgproc.contourArea(it) } ?: return emptyList()
        val approx = Mat()
        val epsilon = 0.02 * Imgproc.arcLength(largest, true)
        Imgproc.approxPolyDP(largest, approx, epsilon, true)

        val points = mutableListOf<Point>()
        for (i in 0 until approx.rows()) {
            points.add(Point(approx[i, 0]))
        }
        return points
    }

    fun perspectiveCorrect(srcBitmap: Bitmap, points: List<Point>): Bitmap? {
        if (points.size != 4) return null
        val src = Mat()
        Utils.bitmapToMat(srcBitmap, src)
        val dstMat = Mat()
        val dstSize = Size(src.cols().toDouble(), src.rows().toDouble())
        val srcPoints = org.opencv.core.MatOfPoint2f(*points.toTypedArray())
        val dstPoints = org.opencv.core.MatOfPoint2f(
            Point(0.0, 0.0),
            Point(dstSize.width, 0.0),
            Point(dstSize.width, dstSize.height),
            Point(0.0, dstSize.height),
        )
        val transform = Imgproc.getPerspectiveTransform(srcPoints, dstPoints)
        Imgproc.warpPerspective(src, dstMat, transform, Size(dstSize.width, dstSize.height))
        val dstBitmap = Bitmap.createBitmap(dstMat.cols(), dstMat.rows(), Bitmap.Config.ARGB_8888)
        Utils.matToBitmap(dstMat, dstBitmap)
        src.release()
        dstMat.release()
        return dstBitmap
    }
}
