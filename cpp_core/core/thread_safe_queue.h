// cpp_core/core/thread_safe_queue.h

#pragma once

#include <queue>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <functional>

// A thread-safe queue for our command functions.
template<typename T>
class ThreadSafeQueue {
 public:
  // Pushes a new item onto the queue.
  void push(T item) {
	  std::unique_lock<std::mutex> lock(m_mutex);
	  m_queue.push(std::move(item));
	  lock.unlock();
	  m_cond.notify_one(); // Wake up one waiting thread.
  }

  // Waits for an item to be available and pops it into the 'item' reference.
  // Returns false if the queue was stopped, true otherwise.
  bool wait_and_pop(T& item) {
	  std::unique_lock<std::mutex> lock(m_mutex);
	  // Wait until the queue is not empty OR it has been stopped.
	  m_cond.wait(lock, [this] { return !m_queue.empty() || m_stopped; });

	  // If we woke up because the queue was stopped and it's empty, we should exit.
	  if (m_stopped && m_queue.empty()) {
		  return false;
	  }

	  item = std::move(m_queue.front());
	  m_queue.pop();
	  return true;
  }

  // Stops the queue, causing any waiting threads to wake up and exit.
  void stop() {
	  std::unique_lock<std::mutex> lock(m_mutex);
	  m_stopped = true;
	  lock.unlock();
	  m_cond.notify_all(); // Wake up all waiting threads.
  }

 private:
  std::mutex m_mutex;
  std::condition_variable m_cond;
  std::queue<T> m_queue;
  bool m_stopped = false;
};