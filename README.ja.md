# antigravity-plugin-cc

[English](./README.md) | [한국어](./README.ko.md) | [简体中文](./README.zh-CN.md) | **日本語**

Claude Code の中から [Antigravity](https://antigravity.google)（`agy`）を使って、**広いコンテキストでのコードベース分析**を行います。

Antigravity の Gemini モデルは広いコンテキストを読み込んで推論することに長けており、大規模なコードベースのスキャン、ある変更の影響範囲の把握、セキュリティ監査、そして大量のログからインフラ障害の根本原因を突き止める作業に適しています。このプラグインはそうした作業を `agy` CLI に委譲し、重い分析処理を Claude Code 自身のコンテキストの外に隔離します——返ってくるのは統合された結果だけで、そのまま Claude や Codex に渡して後続の修正に使えます。

## コマンド

- `/agy:repo-scan <ルールまたは領域>` —— リポジトリ全体のアーキテクチャスキャン。コードベースをアーキテクチャルールと照合し、レイヤー違反、不正なレイヤー間 import、循環依存を `file:line` の引用付きで報告します。
- `/agy:impact-map <コンポーネントまたは変更>` —— 影響範囲（blast-radius）分析。コアコンポーネントへの予定された変更を、影響を受けるすべてのモジュール・設定・テストまで外側にたどり、着手前に副作用を回避できるようにします。
- `/agy:sec-audit <ガイドラインまたは領域>` —— コードベース全体のセキュリティ監査。エンドポイントやセキュリティ上重要なレイヤーをスキャンし、脆弱な認証・トークン処理・設定の問題を見つけ、各指摘を深刻度と `file:line` 付きで報告します。共有の Gemini デフォルトではなく `Claude Sonnet 4.6 (Thinking)` をデフォルトにします。Antigravity の Gemini モデルはセキュリティ監査の依頼を拒否するためです（`--model` で上書き可能）。
- `/agy:infra-debug <症状またはシグナル>` —— インフラの根本原因分析。Kubernetes マニフェスト、OpenTelemetry の設定、大量のログ/トレースのダンプを相関させ、失敗するパスがどこで壊れているかを特定し、修正の方向性を示します。

すべてのコマンドはオプションのルーティングフラグを受け付けます：

- `--model "<名前>"` —— デフォルトモデルを上書きします（`Gemini 3.5 Flash (High)`；`/agy:sec-audit` は `Claude Sonnet 4.6 (Thinking)` がデフォルト）。有効な名前は `agy models` で確認できます。
- `--add-dir <パス>` —— agy のワークスペースに別のディレクトリを追加します（繰り返し指定可能）。カレントディレクトリは常に含まれます。

### 例

```
/agy:repo-scan enforce hexagonal architecture — domain must not import infrastructure
/agy:impact-map I'm changing the Redis stream manager's serialization format
/agy:sec-audit check every endpoint for missing asymmetric JWT verification
/agy:infra-debug --add-dir ./logs distributed traces drop between gateway and order service
```

## 仕組み

```
/agy:repo-scan | impact-map | sec-audit | infra-debug   （コマンド、リクエストを組み立てる）
        ↓  Agent ツール
agy:antigravity-explorer      （サブエージェント、薄いフォワーダー——重いコンテキストを隔離）
        ↓  antigravity-runtime スキル
agy -p "<read-only でラップしたプロンプト>" --add-dir "$PWD" \
       --model "Gemini 3.5 Flash (High)" \
       --dangerously-skip-permissions --print-timeout 9m
```

## セキュリティと信頼

このプラグインは `agy` を `--dangerously-skip-permissions` 付きで実行するため、**`agy` は指定したディレクトリに対して読み取り・書き込み・コマンド実行のフルアクセスを得ます。** コードベース上で任意の自律エージェントを動かすのと同じように扱ってください：**信頼できるコードにのみ使用してください。**

これらのコマンドは `agy` に読み取り専用でいるよう*依頼*します——プロンプトの指示が書き込み・状態を変えるコマンド・ネットワークアクセスを禁止し、変更を行う代わりに*説明*するよう伝えます。これは協力的なモデルによるうっかり編集を確実に防ぎますが、**セキュリティ境界ではありません**：プロンプトインジェクションを受けた、あるいは敵対的なワークスペースがファイルを書き込んだり、コマンドを実行したり、データを持ち出したりするのは止められません。`agy` に読み取り専用フラグはなく、`--dangerously-skip-permissions` も `--sandbox` も書き込みを防げません（いずれも検証済み）。

今日の時点で厳密な読み取り専用を保証したい場合は、`agy` を自分で OS レベルのサンドボックス（読み取り専用ファイルシステム、環境に秘密情報を含めない、ネットワーク送出を制限）で包んでください。

## ロードマップ

- **オプトインの OS レベルサンドボックス** により、読み取り専用を本当に強制できるようにします（例：macOS の `sandbox-exec`）。プロンプトでは保証できない依頼だった読み取り専用を、本物の境界に変えます。

## 必要要件

- インストール・認証済みの [Antigravity CLI](https://antigravity.google)（`agy`）。`agy --version` と `agy models` で確認してください。

## インストール

```
/plugin marketplace add chanwoo040531/antigravity-plugin-cc
/plugin install agy@antigravity-plugin-cc
/reload-plugins
/agy:setup
```

`/reload-plugins` は、インストールしたばかりのプラグインを現在のセッションで有効化します——セッション途中でインストールしたプラグインは自動では読み込まれません（代わりに Claude Code を再起動してもかまいません）。

`/agy:setup` は一度だけ実行すればよいステップです。`agy` がインストール・認証済みかを確認したうえで、`Bash(agy -p:*)` の権限ルールをあなたの Claude Code 設定に追加します——あるいは、Claude Code の自動モード分類器が自動編集をブロックした場合は、手動で追加するための 1 行を表示します（`/permissions` を実行して `Bash(agy -p:*)` を許可することもできます）。このルールがないと、分類器は分析コマンドをブロックします：explorer サブエージェントが `agy -p … --dangerously-skip-permissions` を実行しますが、分類器はこれを「安全でないエージェント」とみなし、実行前に拒否するためです。

このルールが何を許可するかに注意してください：`Bash(agy -p:*)` は、これらの設定を読み込むあらゆる Claude Code セッションで**すべての** `agy -p` プリントモード呼び出しを自動承認します——本プラグインのコマンドだけではありません（`disable-model-invocation` はプラグインの*コマンド*が自動発火するのを防ぎますが、権限の範囲を限定するわけではありません）。`agy -p` は常に `--dangerously-skip-permissions` を伴うため、これは「このマシン上で `agy` が呼び出しごとの確認なしに実行されることを信頼する」という意図的な選択です——[セキュリティと信頼](#セキュリティと信頼)の節がすでに求めているのと同じ信頼です。ルールをマシン全体ではなく現在のリポジトリに限定するには `--project` を渡してください。

## 謝辞

構造は [`openai/codex-plugin-cc`](https://github.com/openai/codex-plugin-cc) に着想を得ています
(command → forwarder subagent → runtime skill)。`agy -p` は同期的な一回限りの呼び出しのため、
Codex の永続的な broker インフラを必要とせず、よりシンプルにしています。

## ライセンス

[MIT](./LICENSE)
