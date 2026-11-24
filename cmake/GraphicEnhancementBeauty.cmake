# Beauty node (face restore + skin smoothing): face detector, GPU passes, tests.
# Included from the FFmpeg-gated block of CMakeLists.txt, after graphicenhancement_pipeline /
# graphicenhancement_sinks / graphicenhancement_engine exist.
#
# Sources: YuNet (OpenCV Zoo 47534e27, MIT) and the MediaPipe face landmark model
# (v0.8.9, Apache-2.0) - both load from files at run time and never enter the tree -,
# SkinSoft (yasunari01/obs-filters fd5690f,
# GPL-2.0-or-later) and GPUPixel (pixpark/gpupixel ef552bf, Apache-2.0). Details
# per file: THIRD_PARTY_NOTICES.md.
target_sources(graphicenhancement_pipeline PRIVATE
  src/beauty/OnnxLite.cpp
  src/beauty/TfliteLite.cpp
  src/beauty/YuNetGpu.cpp
  src/beauty/FaceMeshGpu.cpp
  src/beauty/FaceTracker.cpp
  src/pipeline/BeautyPass.cpp)
foreach(kernel Prep Stem Pointwise Depthwise Pool UpAdd Decode)
  string(TOLOWER "${kernel}" lower)
  graphicenhancement_add_compute_shader(graphicenhancement_shader_beauty_yunet_${lower} BeautyYuNet${kernel})
  add_dependencies(graphicenhancement_pipeline graphicenhancement_shader_beauty_yunet_${lower})
endforeach()
# Face mesh: crop, network layers, outlines.
foreach(kernel Crop Conv Depthwise Pointwise Decode)
  string(TOLOWER "${kernel}" lower)
  graphicenhancement_add_compute_shader(graphicenhancement_shader_beauty_mesh_${lower} BeautyMesh${kernel})
  add_dependencies(graphicenhancement_pipeline graphicenhancement_shader_beauty_mesh_${lower})
endforeach()
# Face tracking and the node passes (region, statistics, blur, apply).
foreach(stage Track Roi Stats Blur Apply)
  string(TOLOWER "${stage}" lower)
  graphicenhancement_add_compute_shader(graphicenhancement_shader_beauty_${lower} Beauty${stage})
  add_dependencies(graphicenhancement_pipeline graphicenhancement_shader_beauty_${lower})
endforeach()

# Detector against OpenCV's reference outputs (scripts/beauty/yunet-reference.py).
add_executable(graphicenhancement_beauty_detector_tests tests/integration/BeautyDetectorTests.cpp)
target_compile_features(graphicenhancement_beauty_detector_tests PRIVATE cxx_std_20)
target_compile_options(graphicenhancement_beauty_detector_tests PRIVATE /utf-8)
target_compile_definitions(graphicenhancement_beauty_detector_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(graphicenhancement_beauty_detector_tests PRIVATE graphicenhancement_pipeline graphicenhancement_sinks)

# The beauty node in the real graph: restore / smoothing / HDR / tracking / timing.
add_executable(graphicenhancement_beauty_gpu_tests tests/integration/BeautyGpuTests.cpp)
target_compile_features(graphicenhancement_beauty_gpu_tests PRIVATE cxx_std_20)
target_compile_options(graphicenhancement_beauty_gpu_tests PRIVATE /utf-8)
target_compile_definitions(graphicenhancement_beauty_gpu_tests PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
target_link_libraries(graphicenhancement_beauty_gpu_tests PRIVATE graphicenhancement_engine)
