# Engineering Superpowers

[English](README.md) | **简体中文**

一个 Claude Code 插件，把"写代码的请求"变成真正的工程流程——需求分析、设计、实现、
测试、审查、提交、PR、合并——而不是直接开始写代码。适用于 JavaScript/TypeScript、
Python、Go、Java、Rust，遇到识别不了的技术栈也会优雅降级，不会罢工。

这不是一个"代码生成 Prompt"。它是一个工作流引擎：一组 skill 塑造 Claude 处理任务的
方式，slash command 负责编排各阶段顺序，还有一个 git hook 在 commit 时真正把关那些
最重要的事(受保护分支、测试、lint、密钥)——不管对话过程里发生了什么，这一层都会执行。

## 它约束了什么，怎么约束的

| 规则 | 机制 | 约束强度 |
|---|---|---|
| 先理解需求再写代码 | `engineering-workflow` skill, Phase 0 | 软约束（prompt 层） |
| 实现前设计文档必须获批 | `/develop`, Phase 2 | 软约束（prompt 层） |
| 禁止直接在 `main`/`master` 上提交 | `hooks/pre-commit-check.sh` | **硬约束**（直接拦截 commit） |
| 提交前测试必须通过 | `hooks/pre-commit-check.sh` | 探测到测试命令时是**硬约束**；探测不到时降级为软约束（给出警告） |
| 暂存内容不含明显密钥 | `hooks/pre-commit-check.sh` | **硬约束**（直接拦截 commit） |
| 代码审查必须给出 APPROVED 才能提交 | `agents/code-reviewer.md`（独立上下文）+ `code-review` skill 兜底 | 中等——reviewer 跑在独立上下文里，且工具权限层面禁用了 `Write`/`Edit`，结构上无法"顺手改代码"而不是真的报告问题；但最终能不能给出 APPROVED 依然是软约束 |
| 删分支前必须显式确认 | `git-workflow` skill, Phase 8 | 软约束（prompt 层，但有 Claude Code 自身的工具权限确认兜底） |

坦白说清楚这一点：skill 和 command 都是注入到 Claude 上下文里的指令，不是硬性状态机——
Claude 理论上可以偏离它们。只有 hook 这一层才有真正确定性的保证。这也是为什么"跳过后
果最严重"的几件事(在 main 上提交、提交没测过的代码、提交密钥)都放在 hook 里，而不是
只写在 skill 的文字说明里。

## 安装

```
/plugin marketplace add cqw309/engineering-superpowers
/plugin install engineering-superpowers@engineering-superpowers
```

确认装好了：`/plugin list`。之后更新：`/plugin marketplace update
engineering-superpowers`。卸载：`claude plugin uninstall
engineering-superpowers@engineering-superpowers`。

## 怎么用

**直接提需求**即可，在任何项目里——只要是非琐碎的编码请求("加个功能"、"修个
bug"、"重构一下 X")，`engineering-workflow` skill 会自动触发，先产出一份需求分析报告，
再做别的事。琐碎的改动(改个 typo、重命名、格式化)不会被拦，skill 的触发范围本来就
排除了这些。

也可以用 slash command 显式驱动：

- **`/develop <功能描述>`** —— 完整 Phase 1-8 流程：建分支、写设计文档(等你批准才
  开始写代码)、实现、测试、代码审查、提交、PR、合并。可续跑——如果你换了新 session
  回来，它会检查已有的设计文档/分支/审查结论，从中断的地方继续，而不是从头再来。
- **`/review [功能或路径]`** —— 只跑代码审查这一步，针对当前的 diff。适合那些不是
  通过 `/develop` 写出来的代码。
- **`/prepare-pr [功能描述]`** —— 提交 + 开 PR，前提是实现和审查都已经完成。

## 示例

```
> 给 /api/login 端点加个限流
```

Claude 会先回一份需求分析报告(目标、范围、影响、风险、待澄清问题)，问清楚真正模糊的
地方(比如"按 IP 限流还是按账号限流？")，然后告诉你运行：

```
> /develop /api/login 限流
```

这会创建 `feature/rate-limit-login` 分支，写好 `docs/design/rate-limit-login.md` 并
等你批准，按照方案实现，跑项目的测试(自动探测，常见技术栈不需要额外配置)，产出一份
代码审查报告，只有审查结论是 APPROVED 才会提交。合并后要不要删除 feature 分支，还是
会明确跟你确认——这一步永远不会自动执行。

## 独立代码审查

Phase 5 不是让同一个对话"自己给自己打分"。`/develop` 和 `/review` 会派发给
`agents/code-reviewer.md`——一个完全不知道实现过程讨论内容的 subagent，只能看到
diff 和设计文档，而且在工具权限层面就不允许它编辑文件(`Write`/`Edit` 在它的
`disallowedTools` 里)。它只能报告发现和结论，没法悄悄把问题自己改掉。如果当前环境
不支持 subagent 派发，两个命令都会降级为用同一份 `code-review` skill 检查清单在主
线程里直接审查。

## 项目类型探测

`scripts/detect-project.sh` 按下面的优先级探测 test/build/lint 命令：

1. 仓库根目录的 `Makefile`（如果有 `test`/`build`/`lint` target）
2. 目标仓库里的 `.claude/project-commands.json`——显式覆盖配置，例如：
   ```json
   { "test": "make ci-test", "build": "make ci-build", "lint": "make ci-lint" }
   ```
   同一个文件还支持 `protectedBranches`——除了 git 自动检测到的默认分支之外，
   额外指定 `hooks/pre-commit-check.sh` 也要拒绝直接提交的分支，比如团队把
   `develop` 也当作保护分支：
   ```json
   { "protectedBranches": ["develop"] }
   ```
3. 语言标志文件：`package.json`（npm/pnpm/yarn；同时会检测 `tsconfig.json` 识别
   TypeScript，如果项目自己没声明 lint script，默认用 `tsc --noEmit` 做类型检查）、
   `pyproject.toml`/`requirements.txt`（pytest）、`go.mod`、`pom.xml`/`build.gradle`、
   `Cargo.toml`
4. 以上都没命中：不会卡住你——只是提示探测不到测试命令，请手动确认，而不是让插件在
   它不认识的项目上直接罢工。

## 目录结构

```
engineering-superpowers/
├── .claude-plugin/
│   ├── plugin.json          # 插件清单
│   └── marketplace.json     # 让这个仓库能被直接当作 marketplace 添加
├── skills/
│   ├── engineering-workflow/SKILL.md   # 主控 SOP + Golden Rules
│   ├── git-workflow/SKILL.md           # Phase 1、6、7、8
│   ├── testing-strategy/SKILL.md       # Phase 4
│   └── code-review/SKILL.md            # Phase 5 检查清单（agent 和兜底路径共用）
├── agents/
│   └── code-reviewer.md                # 独立的 Phase 5 reviewer，不能编辑文件
├── commands/
│   ├── develop.md
│   ├── review.md
│   └── prepare-pr.md
├── templates/
│   ├── design-document.md
│   ├── code-review-report.md
│   └── pull-request-template.md
├── scripts/
│   └── detect-project.sh
└── hooks/
    ├── hooks.json
    └── pre-commit-check.sh
```

## 协议

MIT —— 见 `LICENSE`。
