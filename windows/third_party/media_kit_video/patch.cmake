# Build the two reviewed Windows fixes without modifying the global pub cache.
get_target_property(MEDIA_KIT_DIR media_kit_video_plugin SOURCE_DIR)
set(PATCH_DIR "${CMAKE_CURRENT_LIST_DIR}")
foreach(PAIR IN ITEMS
  "video_output.cc|198cb59a97070b61df5ee8ae35ac3e0bc344f3174f6e4aaf7b77e7357d606548"
  "angle_surface_manager.cc|04eadbea88ce1d825a732c8ea96f9557bb19c275330f4abf7836950e7efd2e2a")
  string(REPLACE "|" ";" PARTS "${PAIR}")
  list(GET PARTS 0 NAME)
  list(GET PARTS 1 EXPECTED)
  file(SHA256 "${MEDIA_KIT_DIR}/${NAME}" ACTUAL)
  if(NOT ACTUAL STREQUAL EXPECTED)
    message(FATAL_ERROR "Review the PaperPlay native texture patch after upgrading media_kit_video: ${NAME}")
  endif()
endforeach()
get_target_property(VIDEO_SOURCES media_kit_video_plugin SOURCES)
list(FILTER VIDEO_SOURCES EXCLUDE REGEX "(^|/)(video_output|angle_surface_manager)\\.cc$")
set_property(TARGET media_kit_video_plugin PROPERTY SOURCES "${VIDEO_SOURCES}")
target_sources(media_kit_video_plugin PRIVATE
  "${PATCH_DIR}/video_output.cc" "${PATCH_DIR}/angle_surface_manager.cc")
target_include_directories(media_kit_video_plugin PRIVATE "${MEDIA_KIT_DIR}")
