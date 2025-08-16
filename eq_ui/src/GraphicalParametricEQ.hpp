#pragma once

#include <imgui.h>
#include <vector>
#include <string>
#include <random>
#include <cmath>
#include <algorithm>

struct EqBand {
	float freq = 1000.0f;
	float gain = 0.0f;
	float q = 1.0f;
	ImVec2 pos = ImVec2(0.0f, 0.0f);
	float freqKHz = 1.0f;

	bool operator==(const EqBand& other) const {
		return freq == other.freq && gain == other.gain && q == other.q;
	}
};

struct Star { ImVec2 pos; float speed; float opacity; float twinklePhase; float size; };
struct Sword { ImVec2 pos; float angle; float size; float slashTimer; bool isSlashing; float slashSpeed; ImVec4 color; };
struct Moon { ImVec2 pos; float size; float speed; float phase; };
struct Fish { ImVec2 pos; float speed; float direction; float wigglePhase; float size; ImVec4 color; };
struct PopupText { ImVec2 pos; float alpha; float time; };

// Global-ish UI flags mirrored from original code (kept minimal and safe)
inline bool showEqWindow = true;
inline int selectedTheme = 5; // 5=Ocean, 6=Blasphemy Popup, 7=JJ Popup, else Demonic

class GraphicalParametricEQ {
private:
	std::vector<EqBand> bands;
	std::vector<EqBand> lastBands;
	const float minFreq = 20.0f;
	const float maxFreq = 20000.0f;
	float minGain = -24.0f;
	float maxGain = 24.0f;
	const ImVec2 graphSize = ImVec2(800.0f, 400.0f);
	int draggedBandIndex = -1;
	bool bypass = true;
	bool showGrid = true;
	bool showLabels = true;
	ImVec4 gridColor = ImVec4(0.6f, 0.2f, 0.2f, 0.5f);
	ImVec4 curveColor = ImVec4(0.8f, 0.2f, 0.2f, 0.8f);
	float dotSize = 8.0f;
	int curvePoints = 100;
	std::vector<Star> stars;
	std::vector<Sword> swords;
	std::vector<Moon> moons;
	std::vector<Fish> fish;
	std::vector<PopupText> popups;
	const int numStars = 100;
	const int numFish = 20;
	std::mt19937 rng;
	std::uniform_real_distribution<float> dist;
	int currentTheme = -1;
	float popupTimer = 0.0f;

	void initializeTheme() {
		std::random_device rd;
		rng = std::mt19937(rd());
		dist = std::uniform_real_distribution<float>(0.0f, 1.0f);
		stars.clear(); swords.clear(); moons.clear(); fish.clear(); popups.clear();
		if (selectedTheme == 5) {
			for (int i = 0; i < numFish; ++i) {
				fish.push_back({
					ImVec2(dist(rng) * graphSize.x, dist(rng) * graphSize.y),
					20.0f + dist(rng) * 50.0f,
					dist(rng) * 2.0f * 3.14159f,
					dist(rng) * 2.0f * 3.14159f,
					10.0f + dist(rng) * 20.0f,
					ImVec4(0.0f + dist(rng) * 0.2f, 0.5f + dist(rng) * 0.5f, 1.0f, 1.0f)
				});
			}
		} else if (selectedTheme == 6 || selectedTheme == 7) {
			// Popups added dynamically in update
		} else {
			for (int i = 0; i < numStars; ++i) {
				stars.push_back({
					ImVec2(dist(rng) * graphSize.x, dist(rng) * graphSize.y),
					0.5f + dist(rng) * 2.0f,
					0.5f + dist(rng) * 0.5f,
					dist(rng) * 2.0f * 3.14159f,
					2.0f + dist(rng) * 3.0f
				});
			}
			for (int i = 0; i < 3; ++i) {
				moons.push_back({
					ImVec2(dist(rng) * graphSize.x, -50.0f - dist(rng) * 100.0f),
					20.0f + dist(rng) * 30.0f,
					20.0f + dist(rng) * 30.0f,
					dist(rng) * 2.0f * 3.14159f
				});
			}
		}
	}

	void updateTheme(float deltaTime) {
		if (selectedTheme == 5) {
			for (auto& f : fish) {
				f.wigglePhase += deltaTime * 5.0f;
				float wiggle = sinf(f.wigglePhase) * 0.1f;
				f.direction += wiggle * deltaTime;
				f.pos.x += f.speed * cosf(f.direction) * deltaTime;
				f.pos.y += f.speed * sinf(f.direction) * deltaTime;
				if (f.pos.x < -f.size || f.pos.x > graphSize.x + f.size) { f.direction = 3.14159f - f.direction; f.pos.x = std::clamp(f.pos.x, 0.0f, graphSize.x); }
				if (f.pos.y < -f.size || f.pos.y > graphSize.y + f.size) { f.direction = -f.direction; f.pos.y = std::clamp(f.pos.y, 0.0f, graphSize.y); }
			}
		} else if (selectedTheme == 6 || selectedTheme == 7) {
			popupTimer += deltaTime;
			if (popupTimer >= 1.0f) { popups.push_back({ ImVec2(dist(rng) * graphSize.x, dist(rng) * graphSize.y), 1.0f, 0.0f }); popupTimer -= 1.0f; }
			for (auto it = popups.begin(); it != popups.end();) {
				it->time += deltaTime; it->alpha = 1.0f - (it->time / 1.0f);
				if (it->time > 1.0f) it = popups.erase(it); else ++it;
			}
		} else {
			for (auto& star : stars) {
				star.pos.y += star.speed * deltaTime * 50.0f;
				if (star.pos.y > graphSize.y) {
					star.pos.y -= graphSize.y; star.pos.x = dist(rng) * graphSize.x; star.opacity = 0.5f + dist(rng) * 0.5f; star.twinklePhase = dist(rng) * 2.0f * 3.14159f; star.size = 2.0f + dist(rng) * 3.0f;
				}
				star.twinklePhase += deltaTime * 2.0f; star.opacity = 0.5f + 0.5f * sinf(star.twinklePhase);
			}
			for (auto& moon : moons) {
				moon.pos.y += moon.speed * deltaTime * 20.0f;
				moon.phase += deltaTime * 0.5f;
				if (moon.pos.y > graphSize.y + moon.size * 2) {
					moon.pos.y = -moon.size; moon.pos.x = dist(rng) * graphSize.x; moon.speed = 20.0f + dist(rng) * 30.0f;
				}
			}
		}
	}

	void drawMoons(ImDrawList* drawList, ImVec2 canvasPos) {
		for (auto& moon : moons) {
			drawList->AddCircleFilled(ImVec2(canvasPos.x + moon.pos.x, canvasPos.y + moon.pos.y), moon.size, IM_COL32(200, 200, 255, 150), 32);
			drawList->AddCircle(ImVec2(canvasPos.x + moon.pos.x + moon.size * 0.3f * cosf(moon.phase), canvasPos.y + moon.pos.y + moon.size * 0.3f * sinf(moon.phase)), moon.size * 0.2f, IM_COL32(150, 150, 180, 150), 2.0f);
			drawList->AddCircle(ImVec2(canvasPos.x + moon.pos.x + moon.size * 0.5f * cosf(moon.phase + 1.0f), canvasPos.y + moon.pos.y + moon.size * 0.5f * sinf(moon.phase + 1.0f)), moon.size * 0.15f, IM_COL32(150, 150, 180, 150), 2.0f);
			drawList->AddCircle(ImVec2(canvasPos.x + moon.pos.x + moon.size * 0.4f * cosf(moon.phase + 2.0f), canvasPos.y + moon.pos.y + moon.size * 0.4f * sinf(moon.phase + 2.0f)), moon.size * 0.1f, IM_COL32(150, 150, 180, 150), 2.0f);
		}
	}

	void drawPopups(ImDrawList* drawList, ImVec2 canvasPos) {
		for (const auto& p : popups) {
			ImU32 color = IM_COL32(255, 0, 0, (int)(p.alpha * 255));
			const char* text = (selectedTheme == 6) ? "Blasphemy" : "JJ";
			drawList->AddText(ImVec2(canvasPos.x + p.pos.x, canvasPos.y + p.pos.y), color, text);
		}
	}

	bool bandsChanged() const {
		if (bands.size() != lastBands.size()) return true;
		for (size_t i = 0; i < bands.size(); ++i) if (!(bands[i] == lastBands[i])) return true;
		return false;
	}

	void drawBellCurve(ImDrawList* drawList, ImVec2 canvasPos, const EqBand& band) {
		if (curvePoints <= 0 || drawList == nullptr) return;
		std::vector<ImVec2> points(curvePoints);
		float q = std::clamp(band.q, 0.1f, 10.0f);
		for (int i = 0; i < curvePoints; ++i) {
			float xNorm = i / (float)(curvePoints - 1);
			float freqOffset = powf(10.0f, xNorm * log10f(maxFreq / minFreq)) * minFreq;
			float gainOffset = band.gain * expf(-0.5f * powf(logf(freqOffset / band.freq) / (q * 0.1f), 2.0f));
			float yNorm = (gainOffset - minGain) / (maxGain - minGain);
			points[i] = ImVec2(
				canvasPos.x + xNorm * (graphSize.x - 20.0f) + 10.0f,
				canvasPos.y + (graphSize.y - 20.0f) * (1.0f - std::clamp(yNorm, 0.0f, 1.0f)) + 10.0f
			);
		}
		ImU32 col = IM_COL32(curveColor.x * 255, curveColor.y * 255, curveColor.z * 255, curveColor.w * 255);
		drawList->AddPolyline(points.data(), curvePoints, col, false, 2.0f);
	}

	void drawGrid(ImDrawList* drawList, ImVec2 canvasPos) {
		if (!showGrid || drawList == nullptr) return;
		float freqs[] = { 20.0f, 100.0f, 1000.0f, 10000.0f, 20000.0f };
		for (float freq : freqs) {
			float xNorm = log10f(freq / minFreq) / log10f(maxFreq / minFreq);
			float x = canvasPos.x + xNorm * (graphSize.x - 20.0f) + 10.0f;
			drawList->AddLine(ImVec2(x, canvasPos.y + 10.0f), ImVec2(x, canvasPos.y + graphSize.y - 10.0f), IM_COL32(gridColor.x * 255, gridColor.y * 255, gridColor.z * 255, gridColor.w * 255));
		}
		float gainStep = 6.0f;
		for (float gain = minGain; gain <= maxGain; gain += gainStep) {
			float yNorm = (gain - minGain) / (maxGain - minGain);
			float y = canvasPos.y + (graphSize.y - 20.0f) * (1.0f - yNorm) + 10.0f;
			drawList->AddLine(ImVec2(canvasPos.x + 10.0f, y), ImVec2(canvasPos.x + graphSize.x - 10.0f, y), IM_COL32(gridColor.x * 255, gridColor.y * 255, gridColor.z * 255, gridColor.w * 255));
		}
	}

	void updatePositions() {
		for (size_t i = 0; i < bands.size(); ++i) {
			float x = log10f(bands[i].freq / minFreq) / log10f(maxFreq / minFreq) * (graphSize.x - 20.0f) + 10.0f;
			float y = (bands[i].gain - minGain) / (maxGain - minGain) * (graphSize.y - 20.0f) + 10.0f;
			bands[i].pos = ImVec2(x, graphSize.y - y);
			bands[i].freqKHz = bands[i].freq / 1000.0f;
		}
	}

public:
	GraphicalParametricEQ() { resetBands(); lastBands = bands; }

	void resetBands() {
		bands = {
			{100.0f, 0.0f, 1.0f}, {250.0f, 0.0f, 1.0f}, {500.0f, 0.0f, 1.0f},
			{1000.0f, 0.0f, 1.0f}, {2000.0f, 0.0f, 1.0f}, {4000.0f, 0.0f, 1.0f},
			{8000.0f, 0.0f, 1.0f}
		};
		updatePositions();
	}

	void Draw() {
		if (!showEqWindow) return;
		static float lastTime = (float)ImGui::GetTime();
		float currentTime = (float)ImGui::GetTime();
		float deltaTime = currentTime - lastTime; lastTime = currentTime;

		if (currentTheme != selectedTheme) { currentTheme = selectedTheme; initializeTheme(); }
		updateTheme(deltaTime);

		ImGui::SetNextWindowSize(ImVec2(900, 600), ImGuiCond_FirstUseEver);
		if (ImGui::Begin("Sword Equalizer", &showEqWindow, ImGuiWindowFlags_NoScrollbar)) {
			static float textPulse = 0.0f; textPulse += deltaTime * 2.0f; float pulseValue = 0.7f + 0.3f * sinf(textPulse);
			ImGui::TextColored(ImVec4(1.0f, pulseValue * 0.3f, pulseValue * 0.3f, 1.0f), "Sword Equalizer");

			if (ImGui::Button("Reset Bands")) resetBands();
			ImGui::SameLine(); ImGui::Checkbox("Bypass", &bypass);
			ImGui::SameLine(); ImGui::Checkbox("Show Grid", &showGrid);
			ImGui::SameLine(); ImGui::Checkbox("Show Labels", &showLabels);

			ImDrawList* drawList = ImGui::GetWindowDrawList();
			ImVec2 canvasPos = ImGui::GetCursorScreenPos();
			ImVec2 canvasSize = graphSize;

			ImU32 bgColor = (selectedTheme == 5) ? IM_COL32(0, 50, 100, 255) : (selectedTheme == 6 || selectedTheme == 7) ? IM_COL32(20, 0, 0, 255) : IM_COL32(10, 0, 0, 255);
			drawList->AddRectFilled(canvasPos, ImVec2(canvasPos.x + canvasSize.x, canvasPos.y + canvasSize.y), bgColor);

			if (selectedTheme == 6 || selectedTheme == 7) drawPopups(drawList, canvasPos);
			else if (selectedTheme != 5) drawMoons(drawList, canvasPos);

			drawList->AddRect(canvasPos, ImVec2(canvasPos.x + canvasSize.x, canvasPos.y + canvasSize.y), IM_COL32(150, 0, 0, 255));
			if (showGrid) drawGrid(drawList, canvasPos);

			ImGui::Text("20Hz"); ImGui::SameLine(graphSize.x * 0.25f - 20.0f); ImGui::Text("100Hz");
			ImGui::SameLine(graphSize.x * 0.5f - 20.0f); ImGui::Text("1kHz");
			ImGui::SameLine(graphSize.x * 0.75f - 20.0f); ImGui::Text("10kHz");
			ImGui::SameLine(graphSize.x - 40.0f); ImGui::Text("20kHz");
			ImGui::Text("%.0fdB", maxGain); ImGui::SameLine(0.0f, graphSize.x - 40.0f); ImGui::Text("%.0fdB", minGain);
			ImGui::InvisibleButton("##EQCanvas", canvasSize);

			if (ImGui::IsItemHovered()) {
				for (size_t i = 0; i < bands.size(); ++i) {
					ImVec2 dotPos = ImVec2(canvasPos.x + bands[i].pos.x, canvasPos.y + bands[i].pos.y);
					ImVec2 rectMin(dotPos.x - dotSize, dotPos.y - dotSize);
					ImVec2 rectMax(dotPos.x + dotSize, dotPos.y + dotSize);
					if (ImGui::IsMouseHoveringRect(rectMin, rectMax) && ImGui::IsMouseClicked(0)) draggedBandIndex = (int)i;
				}
				if (ImGui::IsMouseClicked(1) && draggedBandIndex == -1) {
					float x = std::clamp(ImGui::GetMousePos().x - canvasPos.x, 10.0f, canvasSize.x - 10.0f);
					float y = std::clamp(ImGui::GetMousePos().y - canvasPos.y, 10.0f, canvasSize.y - 10.0f);
					float freq = powf(10.0f, (x - 10.0f) / (canvasSize.x - 20.0f) * log10f(maxFreq / minFreq)) * minFreq;
					float gain = (canvasSize.y - y - 10.0f) / (canvasSize.y - 20.0f) * (maxGain - minGain) + minGain;
					bands.push_back({ freq, gain, 1.0f, ImVec2(x, y), freq / 1000.0f });
					updatePositions();
				}
			}

			if (draggedBandIndex >= 0 && draggedBandIndex < (int)bands.size() && ImGui::IsMouseDragging(0)) {
				ImVec2 mousePos = ImGui::GetMousePos();
				float x = std::clamp(mousePos.x - canvasPos.x, 10.0f, canvasSize.x - 10.0f);
				float y = std::clamp(mousePos.y - canvasPos.y, 10.0f, canvasSize.y - 10.0f);
				bands[draggedBandIndex].pos = ImVec2(x, y);
				bands[draggedBandIndex].freq = powf(10.0f, (x - 10.0f) / (canvasSize.x - 20.0f) * log10f(maxFreq / minFreq)) * minFreq;
				bands[draggedBandIndex].gain = (canvasSize.y - y - 10.0f) / (canvasSize.y - 20.0f) * (maxGain - minGain) + minGain;
				bands[draggedBandIndex].freqKHz = bands[draggedBandIndex].freq / 1000.0f;
			}
			if (ImGui::IsMouseReleased(0)) draggedBandIndex = -1;
			if (draggedBandIndex >= 0 && draggedBandIndex < (int)bands.size() && ImGui::IsMouseClicked(1)) { bands.erase(bands.begin() + draggedBandIndex); draggedBandIndex = -1; updatePositions(); }

			if (!bypass) for (const auto& band : bands) drawBellCurve(drawList, canvasPos, band);
			if (bandsChanged()) lastBands = bands;

			static float twinkleTime = 0.0f; twinkleTime += deltaTime * 2.0f;
			for (size_t i = 0; i < bands.size(); ++i) {
				ImVec2 dotPos = ImVec2(canvasPos.x + bands[i].pos.x, canvasPos.y + bands[i].pos.y);
				float t = (bands[i].gain - minGain) / (maxGain - minGain);
				float twinkle = 0.8f + 0.2f * sinf(twinkleTime + (float)i);
				ImU32 dotColor = IM_COL32(255 * t * twinkle, 100 * t * twinkle, 100 * t * twinkle, 255);
				if (bands[i].gain == 0.0f) dotColor = IM_COL32(150, 0, 0, 255);
				drawList->AddLine(ImVec2(dotPos.x - dotSize, dotPos.y - dotSize), ImVec2(dotPos.x + dotSize, dotPos.y + dotSize), dotColor, 2.0f);
				drawList->AddLine(ImVec2(dotPos.x + dotSize, dotPos.y - dotSize), ImVec2(dotPos.x - dotSize, dotPos.y + dotSize), dotColor, 2.0f);
				if (showLabels) {
					char label[32];
					snprintf(label, sizeof(label), "%.1fkHz\n%.1fdB", bands[i].freqKHz, bands[i].gain);
					drawList->AddText(ImVec2(dotPos.x + 15.0f, dotPos.y - 10.0f), IM_COL32(255, 100, 100, 200), label);
				}
			}

			ImGui::Text("Band Settings");
			if (bands.empty()) ImGui::Text("No bands available");
			else {
				for (size_t i = 0; i < bands.size(); ++i) {
					ImGui::PushID((int)i);
					ImGui::BeginGroup();
					ImGui::Text("Band %d", (int)i + 1);
					ImGui::SliderFloat("Freq", &bands[i].freq, minFreq, maxFreq, "%.1f Hz", 2.0f);
					ImGui::SliderFloat("Gain", &bands[i].gain, minGain, maxGain, "%.1f dB");
					ImGui::SliderFloat("Q", &bands[i].q, 0.1f, 10.0f, "%.2f");
					if (ImGui::Button("Delete")) { bands.erase(bands.begin() + i); updatePositions(); ImGui::PopID(); break; }
					ImGui::EndGroup();
					ImGui::PopID();
				}
			}
			if (ImGui::Button("Add Band")) { bands.push_back({ 1000.0f, 0.0f, 1.0f }); updatePositions(); }
		}
		ImGui::End();
	}
};