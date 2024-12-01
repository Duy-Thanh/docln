package com.cyberdaystudios.apps.docln.performance

import android.graphics.Bitmap
import android.util.LruCache

class ImageCache private constructor() {
    private var memoryCache: LruCache<String, Bitmap>? = null

    fun configure(cacheSizeMB: Int) {
        val cacheSize = 1024 * 1024 * cacheSizeMB
        memoryCache = object : LruCache<String, Bitmap>(cacheSize) {
            override fun sizeOf(key: String, bitmap: Bitmap): Int {
                return bitmap.byteCount / 1024
            }
        }
    }

    fun addBitmapToCache(key: String, bitmap: Bitmap) {
        memoryCache?.put(key, bitmap)
    }

    fun getBitmapFromCache(key: String): Bitmap? {
        return memoryCache?.get(key)
    }

    fun trimMemory() {
        memoryCache?.evictAll()
    }

    companion object {
        val instance = ImageCache()
    }
}