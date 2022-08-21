package com.mrousavy.camera.frameprocessor;

import android.annotation.SuppressLint;
import android.media.Image;

import androidx.camera.core.ImageProxy;

public class VisionImageProxy {
    public ImageProxy imageProxy;
    public long recordStartTs;

    public VisionImageProxy(ImageProxy imageProxy, long recordStartTs) {
        this.imageProxy = imageProxy;
        this.recordStartTs = recordStartTs;
    }

    public int getWidth() {
        return imageProxy.getWidth();
    }

    public int getHeight() {
        return imageProxy.getWidth();
    }

    public int getPlanesCount() {
        return imageProxy.getPlanes().length;
    }

    public int getBytesPerRow() {
        return imageProxy.getPlanes()[0].getRowStride();
    }

    public long getRecordingStartTs() {
        return recordStartTs;
    }

    public void close() {
        imageProxy.close();
    }

    @SuppressLint("UnsafeOptInUsageError")
    public boolean isImageProxyValid() {
        try {
            Image image = imageProxy.getImage();
            if (image == null) return false;
            // will throw an exception if the image is already closed
            imageProxy.getImage().getCropRect();
            // no exception thrown, image must still be valid.
            return true;
        } catch (Exception e) {
            // exception thrown, image has already been closed.
            return false;
        }
    }
}
