#include <jni.h>
#include <android/log.h>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#include "node.h"

namespace {
constexpr char kLogTag[] = "UitRouterNode";

std::vector<std::string> readArguments(JNIEnv* env, jobjectArray arguments) {
  const jsize count = env->GetArrayLength(arguments);
  std::vector<std::string> values;
  values.reserve(count);

  for (jsize index = 0; index < count; index++) {
    auto value = static_cast<jstring>(env->GetObjectArrayElement(arguments, index));
    const char* utf8 = env->GetStringUTFChars(value, nullptr);
    values.emplace_back(utf8);
    env->ReleaseStringUTFChars(value, utf8);
    env->DeleteLocalRef(value);
  }

  return values;
}
}  // namespace

extern "C" JNIEXPORT jint JNICALL
Java_com_personal_uit_1portal_1app_router_RouterRuntime_startNodeWithArguments(
    JNIEnv* env,
    jobject /* receiver */,
    jobjectArray arguments) {
  const auto values = readArguments(env, arguments);
  std::vector<std::unique_ptr<char[]>> storage;
  std::vector<char*> argv;
  storage.reserve(values.size());
  argv.reserve(values.size());

  for (const auto& value : values) {
    auto copy = std::make_unique<char[]>(value.size() + 1);
    std::memcpy(copy.get(), value.c_str(), value.size() + 1);
    argv.push_back(copy.get());
    storage.push_back(std::move(copy));
  }

  __android_log_print(ANDROID_LOG_INFO, kLogTag, "Starting embedded Node runtime");
  return node::Start(static_cast<int>(argv.size()), argv.data());
}
