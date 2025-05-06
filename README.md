# Overview

**MultiPing for macOS** is a lightweight, user-friendly network monitoring tool built with SwiftUI. Inspired by utilities like PingInfoView on Windows, MultiPing enables you to ping multiple IP addresses concurrently and provides real-time visibility into host reachability via ICMP echo requests.

Whether you're a network engineer, IT administrator, or tech enthusiast, MultiPing makes it simple to observe the connectivity and performance of multiple hosts simultaneously on macOS.

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
5. Click **Start Ping** to monitor IP reachability  

Alternatively, download the DMG and launch the app directly.  
If macOS blocks the app, go to:  
**System Settings → Privacy & Security → Allow Apps from Identified Developers**,  
then click **“Open Anyway”**.

---

# Requirements

- macOS 13.5 or later

---

# Acknowledgements

Special thanks to **Gemini 2.5 Pro**, **GPT-o3**, and **GPT-o4-mini-high** for their invaluable support and contributions to this project.

---

# Screenshots

