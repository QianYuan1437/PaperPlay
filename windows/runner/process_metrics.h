#ifndef RUNNER_PROCESS_METRICS_H_
#define RUNNER_PROCESS_METRICS_H_

#include <windows.h>
#include <flutter/encodable_value.h>
#include <flutter/method_result.h>
#include <memory>

// PDH can block inside a driver. Keep collection off the platform thread and
// deliver the reply on the window thread, without delaying window destruction.
class ProcessMetrics {
 public:
  static constexpr UINT kReady = WM_APP + 112;
  ProcessMetrics();
  ~ProcessMetrics();
  void Sample(HWND window, bool reset,
              std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void Complete();
  void Shutdown();

 private:
  struct State;
  std::shared_ptr<State> state_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> pending_;
};

#endif
