package com.cyberdaystudios.apps.docln.performance

import android.view.View
import android.widget.AbsListView
import androidx.recyclerview.widget.RecyclerView

class ScrollOptimizer {
    fun optimizeRecyclerView(recyclerView: RecyclerView) {
        recyclerView.apply {
            setItemViewCacheSize(20)
            setHasFixedSize(true)
            setItemAnimator(null)
            recycledViewPool.setMaxRecycledViews(0, 30)
        }
    }

    fun optimizeListView(listView: AbsListView) {
        listView.apply {
            isScrollingCacheEnabled = false
            isSmoothScrollbarEnabled = true
        }
    }
}