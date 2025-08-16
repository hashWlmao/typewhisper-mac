# EQ UI (Safe)

This is a safe, standalone ImGui application that implements the Graphical Parametric EQ UI. It removes process hiding, spoofing, injection, and any potentially harmful functionality. Cross-platform (Linux/Windows) using GLFW + OpenGL3.

## Build (Linux)

- Ensure you have CMake (>=3.20) and a C++17 compiler installed.
- The project uses FetchContent to download GLFW and Dear ImGui automatically.

```bash
cd eq_ui
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/eq_ui
```

If you see OpenGL loader errors, ensure your system supports OpenGL 3.0+ and you have graphics drivers installed.

## Build (Windows)

- Install CMake and Visual Studio 2019/2022 with C++ workload
- From a Developer Command Prompt:

```bat
cd eq_ui
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
build\Release\eq_ui.exe
```

## Notes

- Themes: Demonic, Ocean, Blasphemy Popup, JJ Popup (visual only).
- Right-click on the EQ canvas to add a band; drag bands; right-click a selected band to delete.
- This app contains no code related to process hiding, spoofing, or injection.