# Windows texture synchronization patch

The two C++ files are from media_kit_video 2.0.1, under the accompanying MIT license.
Only the texture race fixes from [upstream PR #1468](https://github.com/media-kit/media-kit/pull/1468)
are backported; the unrelated device-loss recovery change is not included.

- Publish the new texture ID under the descriptor-map lock, after insertion.
- Clear the retiring ID under that lock before unregistering its descriptor.
- Serialize D3D surface recreation with Flutter's raster-thread copy.

The original source hashes are checked at CMake configure time so a dependency
upgrade requires reviewing/removing this backport. The global pub cache is untouched.
`integration_test/video_stress_test.dart` exercises live, unblurred texture resizing
and repeated seeking; `STRESS_MEDIA` can select a 4K or large local test fixture.
Debug builds also invoke the real texture callback in the registration/publication
gap, asserting that it returns no descriptor until publication. This deterministically
detects the early-ID map lookup race; it is compiled out of release builds.
