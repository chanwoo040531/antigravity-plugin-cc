# antigravity-plugin-cc

[English](./README.md) | [한국어](./README.ko.md) | **简体中文** | [日本語](./README.ja.md)

在 Claude Code 中使用 [Antigravity](https://antigravity.google)（`agy`）进行**大上下文代码库分析**。

Antigravity 的 Gemini 模型擅长读取并推理大范围上下文，因此非常适合扫描大型代码库、梳理某项改动的影响范围、审计安全问题，以及从海量日志中定位基础设施故障的根因。本插件将这些工作委托给 `agy` CLI，并把繁重的分析过程隔离在 Claude Code 自身的上下文之外——只把综合后的结果带回来，便于直接交给 Claude 或 Codex 进行后续修改。

## 命令

- `/agy:repo-scan <规则或区域>` —— 全仓库架构扫描。将代码库与架构规则进行对照，报告分层违规、非法的跨层 import 以及循环依赖，并附带 `file:line` 引用。
- `/agy:impact-map <组件或改动>` —— 影响范围（blast-radius）分析。把对核心组件的计划改动向外追踪到每一个受影响的模块、配置和测试，让你在动手之前就能规避副作用。
- `/agy:sec-audit <准则或区域>` —— 全代码库安全审计。扫描端点和安全关键层，查找薄弱的认证、令牌处理和配置问题，并为每条发现标注严重程度和 `file:line`。默认使用 `Claude Sonnet 4.6 (Thinking)` 而非共享的 Gemini 默认模型，因为 Antigravity 的 Gemini 模型会拒绝安全审计请求（可用 `--model` 覆盖）。
- `/agy:infra-debug <症状或信号>` —— 基础设施根因分析。关联 Kubernetes 清单、OpenTelemetry 配置以及海量日志/追踪转储，定位失败路径在何处中断，并给出修复方向。

所有命令都接受可选的路由参数：

- `--model "<名称>"` —— 覆盖默认模型（`Gemini 3.5 Flash (High)`；`/agy:sec-audit` 默认为 `Claude Sonnet 4.6 (Thinking)`）。运行 `agy models` 查看有效名称。
- `--add-dir <路径>` —— 向 agy 的工作区添加另一个目录（可重复使用）。当前目录始终包含在内。

### 示例

```
/agy:repo-scan enforce hexagonal architecture — domain must not import infrastructure
/agy:impact-map I'm changing the Redis stream manager's serialization format
/agy:sec-audit check every endpoint for missing asymmetric JWT verification
/agy:infra-debug --add-dir ./logs distributed traces drop between gateway and order service
```

## 工作原理

```
/agy:repo-scan | impact-map | sec-audit | infra-debug   （命令，构建请求）
        ↓  Agent 工具
agy:antigravity-explorer      （子代理，轻量转发器——隔离繁重的上下文）
        ↓  antigravity-runtime 技能
agy -p "<以只读方式包裹的提示词>" --add-dir "$PWD" \
       --model "Gemini 3.5 Flash (High)" \
       --dangerously-skip-permissions --print-timeout 9m
```

## 安全与信任

本插件以 `--dangerously-skip-permissions` 运行 `agy`，因此 **`agy` 会获得对你所指向目录的完整读取、写入和命令执行权限。** 请像在代码上运行任何自主代理一样对待它：**只在你信任的代码上使用它。**

这些命令会*请求* `agy` 保持只读——一段提示词指令禁止写入、状态变更命令和网络访问，并要求它*描述*改动而非执行改动。这能可靠地防止协作型模型的意外编辑，但它**不是安全边界**：它无法阻止被提示注入或存在恶意的工作区写入文件、运行命令或外泄数据。`agy` 没有只读标志，而且 `--dangerously-skip-permissions` 和 `--sandbox` 都无法阻止写入（两者均已验证）。

若想在今天就获得硬性的只读保证，请自行用操作系统级沙箱包裹 `agy`（只读文件系统、环境中不含密钥、限制网络出站）。

## 路线图

- **可选的操作系统级沙箱**，让只读能够被真正强制执行（例如 macOS 的 `sandbox-exec`），把只读从一个提示词无法保证的请求变成真正的边界。

## 前置要求

- 已安装并完成认证的 [Antigravity CLI](https://antigravity.google)（`agy`）。用 `agy --version` 和 `agy models` 验证。

## 安装

```
/plugin marketplace add chanwoo040531/antigravity-plugin-cc
/plugin install agy@antigravity-plugin-cc
/reload-plugins
/agy:setup
```

`/reload-plugins` 会在当前会话中激活刚安装的插件——会话中途安装的插件不会自动加载（你也可以改为重启 Claude Code）。

`/agy:setup` 只需执行一次。它会检查 `agy` 是否已安装并完成认证，然后把 `Bash(agy -p:*)` 权限规则添加到你的 Claude Code 设置中——或者，如果 Claude Code 的自动模式分类器阻止了这次自动编辑，它会打印需要你手动添加的那一行（你也可以运行 `/permissions` 并允许 `Bash(agy -p:*)`）。没有该规则，分类器会阻止这些分析命令：explorer 子代理会运行 `agy -p … --dangerously-skip-permissions`，分类器将其视为“不安全的代理”，并在其运行前拒绝。

请留意该规则授予了什么：`Bash(agy -p:*)` 会在任何读取这些设置的 Claude Code 会话中自动批准**每一次** `agy -p` 打印模式调用——而不仅是本插件的命令（`disable-model-invocation` 只阻止插件的*命令*自动触发，并不会限定权限的范围）。由于 `agy -p` 始终携带 `--dangerously-skip-permissions`，这是一个有意为之的“我信任 `agy` 在这台机器上无需逐次提示即可运行”的选择——与[安全与信任](#安全与信任)一节已经要求的信任相同。传入 `--project` 可将该规则限定到当前仓库，而非整台机器。

## 许可证

[MIT](./LICENSE)
