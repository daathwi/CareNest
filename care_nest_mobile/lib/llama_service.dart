import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef InitModelNative = Void Function(Pointer<Utf8>, Pointer<Utf8>);
typedef InitModelDart = void Function(Pointer<Utf8>, Pointer<Utf8>);

typedef FreeResultNative = Void Function(Pointer<Utf8>);
typedef FreeResultDart = void Function(Pointer<Utf8>);

typedef ClearImagesNative = Void Function();
typedef ClearImagesDart = void Function();

typedef AddImageNative = Int32 Function(Pointer<Uint8>, Int32, Int32);
typedef AddImageDart = int Function(Pointer<Uint8>, int, int);

typedef LoadPromptNative = Int32 Function(Pointer<Utf8>);
typedef LoadPromptDart = int Function(Pointer<Utf8>);

typedef CacheSystemPromptNative = Int32 Function(Pointer<Utf8>);
typedef CacheSystemPromptDart = int Function(Pointer<Utf8>);

typedef GenerateTokenNative = Pointer<Utf8> Function();
typedef GenerateTokenDart = Pointer<Utf8> Function();

class LlamaService {
  late DynamicLibrary dylib;
  late InitModelDart initModel;
  late ClearImagesDart clearImages;
  late AddImageDart addImage;
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
    clearImages = dylib.lookupFunction<ClearImagesNative, ClearImagesDart>("clear_images");
    addImage = dylib.lookupFunction<AddImageNative, AddImageDart>("add_image");
    loadPrompt = dylib.lookupFunction<LoadPromptNative, LoadPromptDart>("load_prompt");
    cacheSystemPrompt = dylib.lookupFunction<CacheSystemPromptNative, CacheSystemPromptDart>("cache_system_prompt");
    generateToken = dylib.lookupFunction<GenerateTokenNative, GenerateTokenDart>("generate_token");
    freeResult = dylib.lookupFunction<FreeResultNative, FreeResultDart>("free_result");
  }

  void loadModel(String modelPath, String projectorPath) {
    final mPathPtr = modelPath.toNativeUtf8();
    final pPathPtr = projectorPath.toNativeUtf8();
    initModel(mPathPtr, pPathPtr);
    malloc.free(mPathPtr);
    malloc.free(pPathPtr);
  }

  /// Pre-cache system prompt in KV cache. Call once after loadModel.
  bool warmupSystemPrompt(String systemPrompt) {
    final ptr = systemPrompt.toNativeUtf8();
    final result = cacheSystemPrompt(ptr);
    malloc.free(ptr);
    return result == 0;
  }

  // Clears and sequentially sends multiple RGB pixel sets to the C++ vector
  bool setImages(List<Uint8List> imagesData, List<int> widths, List<int> heights) {
    if (imagesData.isEmpty) return true;
    
    clearImages();
    bool allSuccess = true;
    
    for (int i = 0; i < imagesData.length; i++) {
        final rgbData = imagesData[i];
        final ptr = malloc<Uint8>(rgbData.length);
        ptr.asTypedList(rgbData.length).setAll(0, rgbData);
        final result = addImage(ptr, widths[i], heights[i]);
        malloc.free(ptr);
        if (result == 0) allSuccess = false;
    }
    
    return allSuccess;
  }

  // Prepares the prompt. Returns true if successful.
  bool setPrompt(String prompt) {
    final promptPtr = prompt.toNativeUtf8();
    final result = loadPrompt(promptPtr);
    malloc.free(promptPtr);
    return result == 0;
  }

  // Generates next token string. Returns null if EOG reached.
  String? getNextToken() {
    final ptr = generateToken();
    if (ptr == nullptr) return null;
    
    final token = ptr.toDartString();
    return token;
  }
}
