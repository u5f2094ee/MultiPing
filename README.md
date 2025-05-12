
# Screenshot

![Screenshot of MultiPing v1 2](https://github.com/user-attachments/assets/ee8b7712-e132-4cd5-8c63-15279e91ad0e)


---

# Overview

MultiPing for macOS is a lightweight, user-friendly network monitoring tool built with SwiftUI. Inspired by utilities like PingInfoView on Windows, MultiPing enables you to ping multiple hosts concurrently and observe their real-time reachability using ICMP echo requests.

Whether you’re a network engineer, IT administrator, or tech enthusiast, MultiPing makes it simple to monitor the connectivity and performance of multiple targets simultaneously on macOS.

---

# Features

### Input & Configuration
- Input multiple test targets (IPv4, IPv6, or domain names) via a simple text interface
- Supports mixed input: you can enter a combination of IP addresses and domain names
- Configure:
  - Ping timeout (ms)
  - Ping interval (s)
  - Packet size (bytes)

### Visualization
- Real-time indicators showing success (green) or failure (red)
- Live display of ping response times
- Failure counters and failure rate per target
- Two display modes: 
  - List View
  - Grid View

### Controls
- Start, Pause, Resume, Stop, and Clear test results
- Smooth handling of large target sets with controlled concurrency
- Intelligent interval suggestion

### Sorting & Responsiveness
- Sort results by latency, failure rate, or target
- Adaptive UI that resizes gracefully with the window
- Zoom in/out support for high-density displays

---

# How to Run

1. Open the project in **Xcode 14** or later  
2. Build and run the app on **macOS 13.5 or newer** (Apple Silicon or Intel)  
3. Enter IP addresses (comma- or newline-separated)  
4. Set timeout, interval, and packet size if needed  
5. Click **Start Ping** to monitor IP reachability  

Alternatively, download the DMG and launch the app directly. 
 
# Fix permission restrictions

If macOS blocks the app, go to:  
**System Settings → Privacy & Security → Allow Apps from Identified Developers**,  
then click **“Open Anyway”**.

---

# Requirements

- macOS 13.5 or later

---

# Acknowledgements

Special thanks to **Gemini 2.5 Pro**, **GPT-o3**, and **GPT-o4-mini-high** for their invaluable support and contributions to this project.

