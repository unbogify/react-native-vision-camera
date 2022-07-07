//
// Created by Marc Rousavy on 14.06.21.
//

#include "CameraView.h"

#include <jni.h>
#include <fbjni/fbjni.h>
#include <jsi/jsi.h>

#include <memory>
#include <string>
#include <regex>

namespace vision {

using namespace facebook;
using namespace jni;

using TSelf = local_ref<CameraView::jhybriddata>;

TSelf CameraView::initHybrid(alias_ref<HybridClass::jhybridobject> jThis) {
    return makeCxxInstance(jThis);
}

void CameraView::registerNatives() {
    registerHybrid({
        makeNativeMethod("initHybrid", CameraView::initHybrid),
        makeNativeMethod("audioFrameProcessorCallback", CameraView::audioFrameProcessorCallback),
        makeNativeMethod("videoFrameProcessorCallback", CameraView::videoFrameProcessorCallback),
    });
}

void CameraView::audioFrameProcessorCallback(const alias_ref<JImageProxy::javaobject>& frame) {
  if (audioFrameProcessor_ == nullptr) {
    __android_log_write(ANDROID_LOG_WARN, TAG, "Called Audio Frame Processor callback, but `audioFrameProcessor_` is null!");
    return;
  }

  try {
    audioFrameProcessor_(frame);
  } catch (const jsi::JSError& error) {
    // TODO: jsi::JSErrors cannot be caught on Hermes. They crash the entire app.
    auto stack = std::regex_replace(error.getStack(), std::regex("\n"), "\n    ");
    __android_log_print(ANDROID_LOG_ERROR, TAG, "Audio Frame Processor threw an error! %s\nIn: %s", error.getMessage().c_str(), stack.c_str());
  } catch (const std::exception& exception) {
    __android_log_print(ANDROID_LOG_ERROR, TAG, "Audio Frame Processor threw a C++ error! %s", exception.what());
  }
}

void CameraView::videoFrameProcessorCallback(const alias_ref<JImageProxy::javaobject>& frame) {
  if (videoFrameProcessor_ == nullptr) {
    __android_log_write(ANDROID_LOG_WARN, TAG, "Called Frame Processor callback, but `videoFrameProcessor_` is null!");
    return;
  }

  try {
    videoFrameProcessor_(frame);
  } catch (const jsi::JSError& error) {
    // TODO: jsi::JSErrors cannot be caught on Hermes. They crash the entire app.
    auto stack = std::regex_replace(error.getStack(), std::regex("\n"), "\n    ");
    __android_log_print(ANDROID_LOG_ERROR, TAG, "Vieo Frame Processor threw an error! %s\nIn: %s", error.getMessage().c_str(), stack.c_str());
  } catch (const std::exception& exception) {
    __android_log_print(ANDROID_LOG_ERROR, TAG, "Video Frame Processor threw a C++ error! %s", exception.what());
  }
}

void CameraView::setAudioFrameProcessor(const TFrameProcessor&& frameProcessor) {
  audioFrameProcessor_ = frameProcessor;
}

void CameraView::setVideoFrameProcessor(const TFrameProcessor&& frameProcessor) {
  videoFrameProcessor_ = frameProcessor;
}

void vision::CameraView::unsetAudioFrameProcessor() {
  audioFrameProcessor_ = nullptr;
}

void vision::CameraView::unsetVideoFrameProcessor() {
  videoFrameProcessor_ = nullptr;
}

} // namespace vision
