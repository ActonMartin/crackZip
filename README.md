# crackZip — ZIP 密码破解工具

基于 [John the Ripper](https://www.openwall.net/john/) 的 Windows 批处理一键式 ZIP 密码破解脚本。自动识别传统 PKZIP / WinZip AES 加密，支持掩码、字典、增量等多种破解模式，可选 GPU（OpenCL）加速。

## 功能特性

- 自动识别加密类型：传统 PKZIP（`$pkzip$`）与 WinZip AES（`$zip2$`）
- OpenCL 自动探测：有 GPU 用 `ZIP-opencl`，无 GPU 自动回退 CPU `ZIP`
- 12 种内置破解模式：纯数字、字母、字母+数字、手机号、生日、字典、自定义掩码等
- 路径全部相对于脚本目录，整个文件夹拷到任意位置均可运行
- 密码含 `!` `:` `&` 等特殊字符也能正确显示（PowerShell 提取）
- 运行前自动校验 John 环境，缺失则友好报错

## 依赖

| 依赖 | 说明 |
|---|---|
| John the Ripper (jumbo) | 放置于 `john\JtR\run\`，需含 `john.exe`、`zip2john.exe` |
| Windows PowerShell | Win7+ 系统自带，用于密码提取 |

John the Ripper Windows 版下载：<https://github.com/openwall/john-packages/releases>

## 目录结构

```
crackZip/
├── crack_zip.bat        主脚本
├── john/JtR/run/        John the Ripper（需自行放入）
├── Dictionary/          自定义字典（可选）
├── tmp/                 运行时临时文件（自动创建）
└── README.md
```

## 快速开始

1. 确认 `john\JtR\run\john.exe` 存在（首次使用需下载 John the Ripper 并解压到该目录）。
2. 双击 `crack_zip.bat`，或在命令行运行：

   ```bat
   crack_zip.bat no1.zip
   ```

3. 选择破解模式（默认 1：1-8 位纯数字），等待结果。

## 破解模式

| 编号 | 模式 | 范围 | 速度 |
|---|---|---|---|
| 1 | 纯数字 | 1-8 位 | 快 |
| 2 | 纯数字 | 1-12 位 | 中 |
| 3 | 小写字母 | 1-6 位 | 快 |
| 4 | 小写+数字 | 1-6 位 | 中 |
| 5 | 大小写+数字 | 1-6 位 | 慢 |
| 6 | 全可打印字符 | 1-6 位 | 慢 |
| 7 | 自定义掩码 | 用户输入 | — |
| 8 | 字典（password.lst） | — | 快 |
| 9 | 自定义字典 | 用户输入 | — |
| 10 | 增量模式 | 全字符 | 很慢 |
| 11 | 手机号 | 11 位数字 | 快 |
| 12 | 生日 | 8 位 YYYYMMDD | 快 |

掩码占位符：`?d` 数字、`?l` 小写、`?u` 大写、`?a` 全可打印、`?s` 特殊字符、`?h` 十六进制。

## 注意事项

- **传统 PKZIP 仅支持 CPU**，无 OpenCL 内核；WinZip AES（`$zip2$`）有 GPU 时自动启用 `ZIP-opencl`。
- 临时文件（hash、result）写入 `tmp\` 子目录，可随时删除。
- 破解结果同时存入 John 的 pot 文件，可用 `john.exe --show "<hash文件>"` 重新查看。
- 路径含中文/空格时请用双引号包裹。

## 致谢

- [John the Ripper](https://www.openwall.net/john/) — 开源密码破解工具。