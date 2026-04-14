import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef InitModelNative = Void Function(Pointer<Utf8>);
typedef InitModelDart = void Function(Pointer<Utf8>);

typedef FreeResultNative = Void Function(Pointer<Utf8>);
typedef FreeResultDart = void Function(Pointer<Utf8>);

typedef LoadPromptNative = Int32 Function(Pointer<Utf8>);
typedef LoadPromptDart = int Function(Pointer<Utf8>);

typedef CacheSystemPromptNative = Int32 Function(Pointer<Utf8>);
typedef CacheSystemPromptDart = int Function(Pointer<Utf8>);

typedef GenerateTokenNative = Pointer<Utf8> Function();
typedef GenerateTokenDart = Pointer<Utf8> Function();

class LlamaService {
  late DynamicLibrary dylib;
  late InitModelDart initModel;
  late LoadPromptDart loadPrompt;
  late CacheSystemPromptDart cacheSystemPrompt;
  late GenerateTokenDart generateToken;
  late FreeResultDart freeResult;

  LlamaService() {
    // Load dependencies (order matters for Android)
    // Load base components
    DynamicLibrary.open("libomp.so");
    DynamicLibrary.open("libggml-base.so");
    
    // Load optimized CPU backend
    DynamicLibrary.open("libggml-cpu.so");
    
    // Load core engine
    DynamicLibrary.open("libggml.so");
    DynamicLibrary.open("libllama.so");

    dylib = DynamicLibrary.open("libwrapper.so");

    initModel = dylib.lookupFunction<InitModelNative, InitModelDart>("init_model");
    loadPrompt = dylib.lookupFunction<LoadPromptNative, LoadPromptDart>("load_prompt");
    cacheSystemPrompt = dylib.lookupFunction<CacheSystemPromptNative, CacheSystemPromptDart>("cache_system_prompt");
    generateToken = dylib.lookupFunction<GenerateTokenNative, GenerateTokenDart>("generate_token");
    freeResult = dylib.lookupFunction<FreeResultNative, FreeResultDart>("free_result");
  }

  void loadModel(String modelPath) {
    final mPathPtr = modelPath.toNativeUtf8();
    initModel(mPathPtr);
    malloc.free(mPathPtr);
  }

  /// Pre-cache system prompt in KV cache. Call once after loadModel.
  bool warmupSystemPrompt(String systemPrompt) {
    final ptr = systemPrompt.toNativeUtf8();
    final result = cacheSystemPrompt(ptr);
    malloc.free(ptr);
    return result == 0;
  }



  // Prepares the prompt. Returns true if successful.
  bool setPrompt(String prompt) {
    final promptPtr = prompt.toNativeUtf8();
    final result = loadPrompt(promptPtr);
    malloc.free(promptPtr);
    return result == 0;
  }

  // Generates next token string. Returns null if EOG reached.
  // Generates next token string. Returns null if EOG reached.
  String? getNextToken() {
    try {
      final ptr = generateToken();
      if (ptr == nullptr) return null;
      
      final String token = ptr.toDartString();
      freeResult(ptr);
      return token;
    } catch (e) {
      // Return a safe placeholder if native encoding fails
      return " ";
    }
  }
}
