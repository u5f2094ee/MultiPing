## 2025.05.06 Version 1.1(20250506)
Renamed the application to “MultiPing for macOS”.
Implemented a cap on concurrent ping tasks and introduced randomized interval jitter to mitigate false failure results when testing a large number of IP addresses.
Refined UI layout and improved element design for better usability and aesthetics.
Added support for remembering the user’s previously entered IP address list.
Introduced an intelligent suggestion feature that recommends an appropriate interval time based on the number of IP addresses being tested.
Introduced a new Grid View for displaying results. The original List View remains available.
Both Grid and List Views are fully responsive and adapt dynamically to window resizing.
Both views support zoom in/out functionality.
Both views feature a status bar showing overall success/failure statistics.
Both views support sorting by various criteria.
Both views support full control of test operations including Start/Stop (Clean) and Pause/Resume.
In List View, each row displays:
	•	The target IP address
	•	Success/failure statistics
	•	Current test status
	•	Failure rate
In Grid View, each card displays:
	•	The target IP address
	•	Success/failure statistics
	•	Current test status

应用程序更名为 “MultiPing for macOS”。
限制并发Ping任务数量，并引入随机间隔扰动，解决在批量Ping测试中部分IP返回假失败结果的问题。
优化用户界面布局与元素设计，提升整体可用性与视觉体验。
新增自动记忆用户已输入IP地址清单的功能。
引入智能建议机制，根据目标IP数量动态推荐合适的Ping间隔时间。
新增Grid模式结果展示窗口，原有的List模式继续保留。
Grid与List模式均支持自适应窗口大小，界面信息动态调整。
Grid与List模式均支持界面内容缩放（放大/缩小）。
Grid与List模式均状态栏实时显示整体成功/失败统计信息。
Grid与List模式均支持按多种条件进行排序。
Grid与List模式均支持测试操作的完整控制，包括: 启动/停止（清空）、 暂停/恢复。
List 模式下，每行显示：
	•	目标IP地址
	•	成功/失败统计
	•	当前测试状态
	•	失败率
Grid 模式中，每张卡片显示：
	•	目标IP地址
	•	成功/失败统计
	•	当前测试状态




## 2025.05.01 Version 1.0(20250501)
The initial version of Multping was launched.

MultiPing 初始版本正式发布。
