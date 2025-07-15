// debug_log.h
#pragma once

#include <iostream>
#include <fstream>

namespace debug_log {

inline std::streambuf* original_cout_buf = nullptr;
inline bool debug_enabled = true;

// Just std::cout — no stdout/freopen
inline void disable_debug_output() {
	if (!debug_enabled) return;

#ifdef _WIN32
	static std::ofstream null_stream("nul");
#else
	static std::ofstream null_stream("/dev/null");
#endif
	original_cout_buf = std::cout.rdbuf();
	std::cout.rdbuf(null_stream.rdbuf());

	debug_enabled = false;
}

inline void enable_debug_output() {
	if (debug_enabled) return;

	if (original_cout_buf)
		std::cout.rdbuf(original_cout_buf);

	debug_enabled = true;
}

inline void toggle_debug_output() {
	debug_enabled ? disable_debug_output() : enable_debug_output();
}

// Optional: Global auto-disabler (safe now)
struct AutoDisable {
  AutoDisable() {
	  disable_debug_output();
  }
};

// Comment this out if you don't want auto-disable
inline AutoDisable __auto_disable_global_debug_log;
}
