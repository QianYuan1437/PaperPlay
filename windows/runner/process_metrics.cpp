#include "process_metrics.h"

#include <pdh.h>
#include <pdhmsg.h>
#include <psapi.h>
#include <algorithm>
#include <cmath>
#include <mutex>
#include <optional>
#include <string>
#include <thread>
#include <vector>

using V = flutter::EncodableValue;

struct ProcessMetrics::State {
  std::mutex mutex;
  HWND window = nullptr;
  bool stopped = false;
  std::optional<V> reply;
  // Accessed only by the single outstanding worker.
  PDH_HQUERY query = nullptr;
  PDH_HCOUNTER gpu = nullptr;
  bool primed = false;

  ~State() { if (query) PdhCloseQuery(query); }

  std::optional<double> ReadGpu(bool reset) {
    if (reset && query) {
      PdhCloseQuery(query);
      query = nullptr;
      gpu = nullptr;
      primed = false;
    }
    if (!query) {
      if (PdhOpenQueryW(nullptr, 0, &query) != ERROR_SUCCESS) return std::nullopt;
      // English counter names work on localized Windows installations. A wildcard
      // retains engines created later when playback or a graphics adapter changes.
      if (PdhAddEnglishCounterW(query, L"\\GPU Engine(*)\\Utilization Percentage",
                               0, &gpu) != ERROR_SUCCESS) {
        PdhCloseQuery(query);
        query = nullptr;
        return std::nullopt;
      }
    }
    if (PdhCollectQueryData(query) != ERROR_SUCCESS) {
      primed = false;
      return std::nullopt;
    }
    if (!primed) { primed = true; return std::nullopt; }
    DWORD bytes = 0, count = 0;
    if (PdhGetFormattedCounterArrayW(gpu, PDH_FMT_DOUBLE, &bytes, &count, nullptr)
        != PDH_MORE_DATA) return std::nullopt;
    std::vector<BYTE> buffer(bytes);
    auto* items = reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buffer.data());
    if (PdhGetFormattedCounterArrayW(gpu, PDH_FMT_DOUBLE, &bytes, &count, items)
        != ERROR_SUCCESS) return std::nullopt;
    const auto prefix = L"pid_" + std::to_wstring(GetCurrentProcessId()) + L"_";
    std::optional<double> busiest;
    for (DWORD i = 0; i < count; ++i) {
      const auto& value = items[i].FmtValue;
      if (std::wstring(items[i].szName).compare(0, prefix.size(), prefix) != 0 ||
          (value.CStatus != PDH_CSTATUS_VALID_DATA && value.CStatus != PDH_CSTATUS_NEW_DATA) ||
          !std::isfinite(value.doubleValue)) continue;
      busiest = std::max(busiest.value_or(0), std::clamp(value.doubleValue, 0.0, 100.0));
    }
    return busiest;
  }

  std::optional<V> Read(bool reset) {
    const auto usage = ReadGpu(reset);
    FILETIME created{}, exited{}, kernel{}, user{};
    PROCESS_MEMORY_COUNTERS_EX memory{};
    memory.cb = sizeof(memory);
    IO_COUNTERS io{};
    const auto process = GetCurrentProcess();
    if (!GetProcessTimes(process, &created, &exited, &kernel, &user) ||
        !GetProcessMemoryInfo(process, reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory), sizeof(memory)) ||
        !GetProcessIoCounters(process, &io)) return std::nullopt;
    const auto ticks = [](FILETIME time) -> int64_t {
      return (static_cast<int64_t>(time.dwHighDateTime) << 32) | time.dwLowDateTime;
    };
    LARGE_INTEGER clock{}, frequency{};
    QueryPerformanceCounter(&clock);
    QueryPerformanceFrequency(&frequency);
    return V(flutter::EncodableMap{
      {V("cpuTicks"), V(ticks(kernel) + ticks(user))},
      {V("seconds"), V(static_cast<double>(clock.QuadPart) / frequency.QuadPart)},
      {V("processors"), V(static_cast<int32_t>(GetActiveProcessorCount(ALL_PROCESSOR_GROUPS)))},
      {V("workingSet"), V(static_cast<int64_t>(memory.WorkingSetSize))},
      {V("privateBytes"), V(static_cast<int64_t>(memory.PrivateUsage))},
      {V("ioBytes"), V(static_cast<int64_t>(io.ReadTransferCount + io.WriteTransferCount))},
      {V("gpu"), usage ? V(*usage) : V()},
    });
  }
};

ProcessMetrics::ProcessMetrics() : state_(std::make_shared<State>()) {}
ProcessMetrics::~ProcessMetrics() { Shutdown(); }

void ProcessMetrics::Sample(HWND window, bool reset,
    std::unique_ptr<flutter::MethodResult<V>> result) {
  if (pending_) {
    result->Error("metrics_busy", "A sample is already pending");
    return;
  }
  {
    std::lock_guard<std::mutex> lock(state_->mutex);
    if (state_->stopped) {
      result->Error("metrics_stopped", "Metrics have stopped");
      return;
    }
    state_->window = window;
  }
  pending_ = std::move(result);
  std::thread([state = state_, reset] {
    auto reply = state->Read(reset);
    std::lock_guard<std::mutex> lock(state->mutex);
    if (state->stopped) return;
    state->reply = std::move(reply);
    PostMessageW(state->window, kReady, 0, 0);
  }).detach();
}

void ProcessMetrics::Complete() {
  if (!pending_) return;
  std::optional<V> reply;
  {
    std::lock_guard<std::mutex> lock(state_->mutex);
    reply = std::move(state_->reply);
  }
  auto result = std::move(pending_);
  if (reply) result->Success(*reply);
  else result->Error("metrics_unavailable", "Windows process counters are unavailable");
}

void ProcessMetrics::Shutdown() {
  if (!state_) return;
  auto state = std::move(state_);
  {
    std::lock_guard<std::mutex> lock(state->mutex);
    state->stopped = true;
    state->window = nullptr;
  }
  // No worker owns the Flutter reply or touches the engine during shutdown.
  pending_.reset();
  // Closing a driver-backed query also belongs off the platform thread. An
  // outstanding reader retains its own reference until collection completes.
  std::thread([state = std::move(state)] {}).detach();
}
