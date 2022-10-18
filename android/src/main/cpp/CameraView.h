//
// Created by Marc Rousavy on 14.06.21.
//

#pragma once

#include <jni.h>
#include <fbjni/fbjni.h>

#include <memory>

#include "java-bindings/JImageProxy.h"

namespace vision {

using namespace facebook;
using TFrameProcessor = std::function<void(jni::alias_ref<JImageProxy::javaobject>)>;

class CameraView : public jni::HybridClass<CameraView> {
 public:
  static auto constexpr kJavaDescriptor = "Lcom/mrousavy/camera/CameraView;";
  static auto constexpr TAG = "VisionCamera";
  static jni::local_ref<jhybriddata> initHybrid(jni::alias_ref<jhybridobject> jThis);
  static void registerNatives();

  // TODO: Use template<> to avoid heap allocation for std::function<>
  void setAudioFrameProcessor(const TFrameProcessor&& frameProcessor);
  void setVideoFrameProcessor(const TFrameProcessor&& frameProcessor);
  void unsetAudioFrameProcessor();
  void unsetVideoFrameProcessor();

 private:
  friend HybridBase;
  jni::global_ref<CameraView::javaobject> javaPart_;
  TFrameProcessor audioFrameProcessor_;
  TFrameProcessor videoFrameProcessor_;

  void audioFrameProcessorCallback(const jni::alias_ref<JImageProxy::javaobject>& frame);
  void videoFrameProcessorCallback(const jni::alias_ref<JImageProxy::javaobject>& frame);

  explicit CameraView(jni::alias_ref<CameraView::jhybridobject> jThis) :
    javaPart_(jni::make_global(jThis)),
    audioFrameProcessor_(nullptr),
    videoFrameProcessor_(nullptr)
  {}
};

} // namespace vision
