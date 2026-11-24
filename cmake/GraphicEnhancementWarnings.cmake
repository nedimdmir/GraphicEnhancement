# Strict warning policy for GraphicEnhancement-owned targets only (Playbook section 5.3).
# Third-party headers are never compiled through this function.

function(graphicenhancement_apply_warnings target)
  if(MSVC)
    target_compile_options(${target} PRIVATE
      /W4 /permissive- /Zc:__cplusplus /Zc:preprocessor /WX)
  else()
    message(FATAL_ERROR "GraphicEnhancement V1 only supports MSVC on Windows x64")
  endif()
endfunction()
