# Overview

**MultiPing for macOS** is a lightweight, user-friendly network monitoring tool built with SwiftUI. Inspired by utilities like PingInfoView on Windows, MultiPing enables you to ping multiple IP addresses concurrently and provides real-time visibility into host reachability via ICMP echo requests.

Whether you're a network engineer, IT administrator, or tech enthusiast, MultiPing makes it simple to observe the connectivity and performance of multiple hosts simultaneously on macOS.

---

# What's New in Version 1.1 (2025.05.06)

- Renamed the app to **“MultiPing for macOS”**.
- Introduced a cap on concurrent ping tasks with randomized interval jitter to reduce false negatives when pinging large numbers of IP addresses.
- Redesigned and refined the UI layout and components for improved usability and modern aesthetics.
- Supports auto-saving of user-inputted IP address lists for convenience.
- Intelligent interval suggestion feature recommends optimal timing based on the number of IPs being tested.
- Added a **Grid View** option for result display; the original **List View** remains available.
- Both views support:
  - Responsive layouts that adapt to window resizing
  - Zoom in/out functionality for better readability
  - Sorting by various result metrics
  - Real-time status bar showing total success/failure counts
  - Full control of operations: Start, Stop (Clear), Pause, Resume
- **List View** rows display:
  - Target IP address
  - Success/failure statistics
  - Current test status
  - Failure rate
- **Grid View** cards display:
  - Target IP address
  - Success/failure statistics
  - Current test status

---

# Features

### Input & Configuration
- Input multiple IP addresses via a simple text interface
- Configure:
  - Ping timeout (ms)
  - Ping interval (s)
  - Packet size (bytes)

### Visualization
- Real-time success/failure indicators (green/red)
- Live display of ping response times
- Success/failure counters and failure rate per IP
- Two display modes: **List View** and **Grid View**

### Controls
- Start, Pause, Stop, and Clear test results
- Intelligent interval suggestion engine
- Smooth handling of large IP sets with controlled concurrency

### Sorting & Responsiveness
- Sort results by failure rate, latency, and other criteria
- Responsive UI adapts to window size
- Zoom in/out to improve visibility with high-density displays

---

# How to Run

1. Open the project in **Xcode 14** or later  
2. Build and run the app on **macOS 13.5 or newer** (Apple Silicon or Intel)  
3. Enter IP addresses (comma- or newline-separated)  
4. Set timeout, interval, and packet size if needed  
5. Click **Okay** to begin  
6. Click **Start Ping** to monitor IP reachability  

Alternatively, download the DMG and launch the app directly.  
If macOS blocks the app, go to:  
**System Settings → Privacy & Security → Allow Apps from Identified Developers**,  
then click **“Open Anyway”**.

---

# Requirements

- macOS 13.5 or later

---

# Acknowledgements

Special thanks to **Gemini 2.5 Pro**, **GPT-o3**, and **GPT-o4-Mini-High** for their invaluable support and contributions to this project.

---

# Screenshots

![wechat_2025-05-01_004359_915](https://github.com/user-attachments/assets/ccc2ec5b-103a-47a0-992b-dbe4e9046a25)

![wechat_2025-05-01_004420_346](https://github.com/user-attachments/assets/fca7642a-eef3-4156-a003-758ab3d32090)

![wechat_2025-05-01_004547_684](https://github.com/user-attachments/assets/4c1a6093-5336-487e-b7b4-aaf87f9ec823)