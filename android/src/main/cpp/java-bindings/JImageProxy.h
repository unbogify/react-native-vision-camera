//
// Created by Marc on 19/06/2021.
//

#pragma once

#include <jni.h>
#include <fbjni/fbjni.h>

namespace vision {

using namespace facebook;
using namespace jni;

struct JImageProxy : public JavaClass<JImageProxy> {
  // androidx/camera/core/ImageProxy
  static constexpr auto kJavaDescriptor = "Lcom/mrousavy/camera/frameprocessor/VisionImageProxy;";

 public:
  int getWidth() const;
  int getHeight() const;
  bool getIsValid() const;
  int getPlanesCount() const;
  int getBytesPerRow() const;
  long getRecordingStartTs() const;
  void close();
};

} // namespace vision
