# Overview

MultiPing is a lightweight and user-friendly macOS application built using SwiftUI that allows users to ping multiple IP addresses concurrently. Inspired by tools like PingInfoView on Windows, MultiPing was designed to provide real-time visibility into host reachability using ICMP echo requests with extended customization options.

This project is ideal for network engineers, IT admins, or curious users who want to monitor connectivity and latency of multiple hosts simultaneously on macOS.

# Features

Input multiple IP addresses in a text box
Customize:
	•	Ping timeout (ms)
	•	Ping interval (s)
	•	Packet size (bytes)

Visualize:
	•	Live ping status with green/red dot indicators
	•	Ping response time in ms or timeout
	•	Success/failure count per IP
	•	Failure rate (%) per IP, rounded to two decimals

Control:
	•	Start, Pause, and Stop pinging
	•	Ping runs concurrently per host
	•	UI stays responsive even under high load

Clean two-window layout:
	•	Input window for configuration
	•	Result window for real-time feedback

# How to Run

	1.	Open the project in Xcode (v14 or newer recommended)
	2.	Build and run the app on macOS (ARM or Intel)
	3.	Enter IP addresses (separated by comma or newline)
	4.	Set timeout, interval, and size as needed
	5.	Press Okay → App opens results window
	6.	Press Start Ping to begin monitoring



By the way it's still under developing now.
