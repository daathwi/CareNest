import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef InitModelNative = Void Function(Pointer<Utf8>, Int32);
typedef InitModelDart = void Function(Pointer<Utf8>, int);

typedef FreeResultNative = Void Function(Pointer<Utf8>);
typedef FreeResultDart = void Function(Pointer<Utf8>);

typedef LoadPromptNative = Int32 Function(Pointer<Utf8>, Bool);
typedef LoadPromptDart = int Function(Pointer<Utf8>, bool);

typedef CacheSystemPromptNative = Int32 Function(Pointer<Utf8>);
typedef CacheSystemPromptDart = int Function(Pointer<Utf8>);

typedef GenerateTokenNative = Pointer<Utf8> Function();
typedef GenerateTokenDart = Pointer<Utf8> Function();

typedef ResetStateNative = Void Function();
typedef ResetStateDart = void Function();

class LlamaService {
  late DynamicLibrary dylib;
  late InitModelDart initModel;
  late ResetStateDart resetState;
  late LoadPromptDart loadPrompt;
  late CacheSystemPromptDart cacheSystemPrompt;
  late GenerateTokenDart generateToken;
  late FreeResultDart freeResult;

  LlamaService() {
    DynamicLibrary.open("libomp.so");
    DynamicLibrary.open("libggml-base.so");
    DynamicLibrary.open("libggml-cpu.so");
    DynamicLibrary.open("libggml.so");
    DynamicLibrary.open("libllama.so");
    dylib = DynamicLibrary.open("libwrapper.so");

    initModel = dylib.lookupFunction<InitModelNative, InitModelDart>("init_model");
    resetState = dylib.lookupFunction<ResetStateNative, ResetStateDart>("reset_state");
    loadPrompt = dylib.lookupFunction<LoadPromptNative, LoadPromptDart>("load_prompt");
    cacheSystemPrompt = dylib.lookupFunction<CacheSystemPromptNative, CacheSystemPromptDart>("cache_system_prompt");
    generateToken = dylib.lookupFunction<GenerateTokenNative, GenerateTokenDart>("generate_token");
    freeResult = dylib.lookupFunction<FreeResultNative, FreeResultDart>("free_result");
  }

  void loadModel(String modelPath) {
    final mPathPtr = modelPath.toNativeUtf8();
    initModel(mPathPtr, 0); // Absolute CPU Force
    malloc.free(mPathPtr);
  }

  int warmupSystemPrompt(String systemPrompt) {
    final ptr = systemPrompt.toNativeUtf8();
    final result = cacheSystemPrompt(ptr);
    malloc.free(ptr);
    return result;
  }

  int setPrompt(String prompt, {bool keepContext = false}) {
    final promptPtr = prompt.toNativeUtf8();
    final result = loadPrompt(promptPtr, keepContext);
    malloc.free(promptPtr);
    return result;
  }

  String? getNextToken() {
    final ptr = generateToken();
    if (ptr == nullptr) return null;
    final String token = ptr.toDartString();
    if (token == "[EOG]") return null;
    freeResult(ptr);
    return token;
  }

  void resetSession() => resetState();
}
