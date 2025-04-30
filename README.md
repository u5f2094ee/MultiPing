# Overview

MultiPing is a lightweight, user-friendly macOS application built with SwiftUI, designed to ping multiple IP addresses concurrently. Inspired by tools like PingInfoView on Windows, MultiPing provides real-time insights into host reachability using ICMP echo requests, while offering extensive customization options.

Whether you’re a network engineer, IT administrator, or a curious user, MultiPing makes it easy to monitor the connectivity and latency of multiple hosts simultaneously on macOS.



# Features

##### Input & Configuration
	•	Enter multiple IP addresses via a simple text input
	•	Customize:
	•	Ping timeout (ms)
	•	Ping interval (s)
	•	Packet size (bytes)

##### Visualization
	•	Real-time status indicators (green/red dots)
	•	Live display of response times or timeouts
	•	Success/failure counters per IP
	•	Failure rate (%) per IP, rounded to two decimal places

##### Controls
	•	Start, Pause, Stop, and Clear ping results
	•	Concurrent pings for each host
	•	UI remains responsive, even under heavy load

##### Sorting & Zoom
	•	Sort by failure counts and other result columns
	•	Zoom in/out for better visibility with large IP lists

##### Two-Window Interface
	•	Input window for configuration
	•	Results window for live feedback and monitoring



# How to Run

	1.	Open the project in Xcode 14 or later
	2.	Build and run the app on macOS (Apple Silicon or Intel)
	3.	Enter IP addresses (comma- or newline-separated)
	4.	Configure timeout, interval, and packet size as desired
	5.	Click Okay to open the results window
	6.	Click Start Ping to begin monitoring

Alternatively, download the DMG file and launch the app directly.



# Requirements

	•	macOS 13.5 or later


# Special thanks to Gemini 2.5 Pro, GPT-3.5, and GPT-4 Mini High for their valuable support.


# Screenshots:


![wechat_2025-05-01_004359_915](https://github.com/user-attachments/assets/ccc2ec5b-103a-47a0-992b-dbe4e9046a25)

![wechat_2025-05-01_004420_346](https://github.com/user-attachments/assets/fca7642a-eef3-4156-a003-758ab3d32090)

![wechat_2025-05-01_004547_684](https://github.com/user-attachments/assets/4c1a6093-5336-487e-b7b4-aaf87f9ec823)

