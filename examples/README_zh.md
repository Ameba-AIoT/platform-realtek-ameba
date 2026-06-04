# 示例

一组开箱即用的 `realtek-ameba` PlatformIO 工程。打开目录，填上你的凭据，`pio run` 即可。

| 示例 | 演示内容 | 关键 API / 组件 |
|------|----------|-----------------|
| [ameba-blink](ameba-blink) | GPIO 输出 + FreeRTOS 任务，多文件用户代码 | `GPIO_Init`、`xTaskCreate` |
| [ameba-wifi-connect](ameba-wifi-connect) | STA 连接 + DHCP + 自动重连 —— 所有联网功能的**基础** | `wifi_connect`、`lwip_request_ip`、`event_external_hdl[]` |
| [ameba-mqtt](ameba-mqtt) | 经典 IoT 发布/订阅，连接公共 broker | `MQTTClient`（`component/network/mqtt/MQTTClient`） |
| [ameba-http-client](ameba-http-client) | 纯 HTTP GET / REST 起步示例 | socket + `http_client.h`（`component/network/httplite`） |

联网示例都内置了 `ameba-wifi-connect` 的连接逻辑，因此可独立运行 —— 先把 Wi-Fi 连上，再在其上叠加协议。

## 工程结构

每个示例都遵循 `pio project init --board <board> --project-option "framework=ameba-rtos"` 生成的同一套布局：

```
ameba-foo/
├── platformio.ini              # 环境：platform + framework + board
├── CMakeLists.txt              # ameba_add_subdirectory(app_example)
├── app_example/
│   ├── CMakeLists.txt          # 注册源文件；额外 include 目录加在这里
│   └── app_main.c              # SDK 入口：在独立任务里运行 user_main()
└── src/                        # 你的代码 —— 自动桥接进构建
    ├── main.c                  # 定义 user_main()
    └── ...
```

首次 `pio run` 时，platform 会自动补全缺失的脚手架文件，并把每个 `src/*.c` 桥接进 `app_example` 库 —— 所以日常你只需要改 `src/`。

---

## 移植任意 SDK 示例

上游 [ameba-rtos](https://github.com/Ameba-AIoT/ameba-rtos) SDK 在 `component/example/` 下提供了约 200 个示例（peripheral、wifi、network_protocol、storage、ota……）。把其中一个移植成 PlatformIO 工程是很机械的过程：

一个标准 SDK 示例由三部分组成：

```
example/<group>/<name>/
├── app_example.c               # 定义 app_example() -> example_<name>()
├── example_<name>.c / .h       # 真正的逻辑
└── CMakeLists.txt              # target_sources + 可能的 target_include_directories
```

### 步骤

1. **从工程骨架开始** —— 复制一个现有示例目录（如 `ameba-wifi-connect`），或运行 `pio project init --board <board> --project-option "framework=ameba-rtos"`。

2. **把逻辑拷进 `src/`。** 取示例的 `example_<name>.c` 和 `.h` 放进 `src/`。**不要**拷 SDK 的 `app_example.c` —— 工程自己已有 `app_example/app_main.c`，再来一个 `app_example()` 定义会冲突。

3. **在 `user_main()` 里调用入口。** 在 `src/main.c`：

   ```c
   #include "example_<name>.h"
   void user_main(void) {
       example_<name>();   // SDK 示例暴露的那个函数
   }
   ```

4. **补上额外 include 目录。** 如果 SDK 的 `CMakeLists.txt` 里有 `target_include_directories(... ${BASEDIR}/...)`，在你的 `app_example/CMakeLists.txt` 里照搬：

   ```cmake
   target_include_directories(${c_CURRENT_TARGET_NAME} PRIVATE
       ${BASEDIR}/component/network/mqtt/MQTTClient   # 例如 MQTT
   )
   ```

   `${BASEDIR}` 指向已安装的 `framework-ameba-rtos` 包。常见的有：MQTT → `component/network/mqtt/MQTTClient`；HTTP → `component/network/httplite`。很多示例（wifi 事件、TCP、keepalive）不需要额外目录。

5. **`pio run`** 编译验证。

### 注意：联网示例自己不会连 Wi-Fi

SDK 的 `network_protocol/*` 示例默认 Wi-Fi 已经连上（在原生 SDK 构建里是运行时通过 AT 命令连的）。要让移植后的联网示例能独立运行，把 `ameba-wifi-connect` 的 `src/wifi_connect.c` + `.h` 一起带上，并在 `user_main()` 里先调用 `wifi_connect_start()` 再启动协议任务 —— 这正是本仓库里 `ameba-mqtt` 和 `ameba-http-client` 的做法。协议任务都会等待 `lwip_check_connectivity(NETIF_WLAN_STA_INDEX)`，所以调用顺序无所谓。

> `wifi_connect.c` 里的 `event_external_hdl[]` / `array_len_of_event_external_hdl` 全局符号是 SDK 链接期解析、用来安装你的 Wi-Fi 事件处理函数的钩子 —— 拷这个文件时记得保留。
