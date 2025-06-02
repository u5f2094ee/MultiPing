
## 2025.06.02 Version 1.3(20250602)
1. Added support for the note feature — users can now add labels for each probe target, which will be displayed in the results window.
2. Fixed a critical bug: When a test target included an IPv6 address, the overall ping process could become stuck with the status remaining “pinging” and no further ping actions being executed.
3. Improved ping test performance and efficiency.

Known Unfixed Bug: Quitting the program using the red close button causes an exception. This issue has not been resolved in the current version.
- Temporary Solution: Use Command+Q or the “Quit” option in the menu to exit the program, which will not  trigger the bug.



-----

## 2025.05.13 Version 1.2(20250513)
1. Added support for IPv6 testing functionality.
2. Added support for domain name testing functionality.
3. The test target input interface now supports mixed input of IPv4, IPv6, and domain names as test targets.
4. Bug fix: Resolved an issue where quickly clicking the "Pause" and "Resume" buttons caused the ping test to incorrectly enter the "Complete" state and become unresponsive.
5. Optimized testing logic and process.


-----

## 2025.05.06 Version 1.1(20250506)
1. Renamed the application to “MultiPing for macOS”.
2. Implemented a cap on concurrent ping tasks and introduced randomized interval jitter to mitigate false failure results when testing a large number of IP addresses.
3. Refined UI layout and improved element design for better usability and aesthetics.
4. Added support for remembering the user’s previously entered IP address list.
5. Introduced an intelligent suggestion feature that recommends an appropriate interval time based on the number of IP addresses being tested.
6. Introduced a new Grid View for displaying results. The original List View remains available.
7. Both Grid and List Views are fully responsive and adapt dynamically to window resizing.
8. Both views support zoom in/out functionality.
9. Both views feature a status bar showing overall success/failure statistics.
10. Both views support sorting by various criteria.
11. Both views support full control of test operations including Start/Stop (Clean) and Pause/Resume.
12. In Grid View, each card displays:
	- The target IP address
	- Success/failure statistics
	- Current test status


-----


## 2025.05.01 Version 1.0(20250501)
1. The initial version of Multping was launched.

