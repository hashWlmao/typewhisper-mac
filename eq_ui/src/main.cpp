#include <imgui.h>
#include <backends/imgui_impl_glfw.h>
#include <backends/imgui_impl_opengl3.h>
#include <GL/gl3w.h> // from ImGui libs/gl3w included via CMake
#include <GLFW/glfw3.h>
#include <cstdio>

#include "GraphicalParametricEQ.hpp"

static void glfw_error_callback(int error, const char* description) {
	std::fprintf(stderr, "GLFW Error %d: %s\n", error, description);
}

int main() {
	glfwSetErrorCallback(glfw_error_callback);
	if (!glfwInit()) return 1;

	// GL 3.0+ context
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
	GLFWwindow* window = glfwCreateWindow(960, 640, "EQ UI (Safe)", nullptr, nullptr);
	if (!window) {
		glfwTerminate();
		return 1;
	}
	glfwMakeContextCurrent(window);
	glfwSwapInterval(1);

	if (gl3wInit() != 0) {
		std::fprintf(stderr, "Failed to initialize OpenGL loader.\n");
		return 1;
	}

	IMGUI_CHECKVERSION();
	ImGui::CreateContext();
	ImGuiIO& io = ImGui::GetIO(); (void)io;
	io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

	ImGui::StyleColorsDark();

	ImGui_ImplGlfw_InitForOpenGL(window, true);
	ImGui_ImplOpenGL3_Init("#version 130");

	GraphicalParametricEQ eq;

	while (!glfwWindowShouldClose(window)) {
		glfwPollEvents();

		ImGui_ImplOpenGL3_NewFrame();
		ImGui_ImplGlfw_NewFrame();
		ImGui::NewFrame();

		// Control panel
		ImGui::Begin("Settings");
		ImGui::Checkbox("Show EQ Window", &showEqWindow);
		static const char* themes[] = { "Demonic", "Ocean", "Blasphemy Popup", "JJ Popup" };
		int uiThemeIndex = (selectedTheme == 5) ? 1 : (selectedTheme == 6) ? 2 : (selectedTheme == 7) ? 3 : 0;
		if (ImGui::Combo("Theme", &uiThemeIndex, themes, IM_ARRAYSIZE(themes))) {
			selectedTheme = (uiThemeIndex == 1) ? 5 : (uiThemeIndex == 2) ? 6 : (uiThemeIndex == 3) ? 7 : 0;
		}
		ImGui::End();

		eq.Draw();

		ImGui::Render();
		int display_w, display_h; glfwGetFramebufferSize(window, &display_w, &display_h);
		glViewport(0, 0, display_w, display_h);
		glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);
		ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
		glfwSwapBuffers(window);
	}

	ImGui_ImplOpenGL3_Shutdown();
	ImGui_ImplGlfw_Shutdown();
	ImGui::DestroyContext();

	glfwDestroyWindow(window);
	glfwTerminate();
	return 0;
}