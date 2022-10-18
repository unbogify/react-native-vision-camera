//
// Created by Marc Rousavy on 22.06.21.
//

#include "JImageProxy.h"

#include <jni.h>
#include <fbjni/fbjni.h>

namespace vision {

using namespace facebook;
using namespace jni;

int JImageProxy::getWidth() const {
  static const auto getWidthMethod = getClass()->getMethod<jint()>("getWidth");
  return getWidthMethod(self());
}

int JImageProxy::getHeight() const {
  static const auto getWidthMethod = getClass()->getMethod<jint()>("getHeight");
  return getWidthMethod(self());
}

alias_ref<JClass> getUtilsClass() {
  static const auto ImageProxyUtilsClass = findClassStatic("com/mrousavy/camera/frameprocessor/ImageProxyUtils");
  return ImageProxyUtilsClass;
}

bool JImageProxy::getIsValid() const {
    static const auto getIsValidMethod = getClass()->getMethod<jint()>("isImageProxyValid");
    return getIsValidMethod(self());
}

int JImageProxy::getPlanesCount() const {
    static const auto getWidthMethod = getClass()->getMethod<jint()>("getPlanesCount");
    return getWidthMethod(self());
}

int JImageProxy::getBytesPerRow() const {
    static const auto getWidthMethod = getClass()->getMethod<jint()>("getBytesPerRow");
    return getWidthMethod(self());
}

void JImageProxy::close() {
  static const auto closeMethod = getClass()->getMethod<void()>("close");
  closeMethod(self());
}

} // namespace vision
