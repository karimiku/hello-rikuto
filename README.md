# hello-rikuto

Nix の最初のflake。学習メモ。

## 何をするflake?

`nix run` すると `Hello, rikuto!` と返すだけのコマンド。

```bash
nix run github:karimiku/hello-rikuto
# → Hello, rikuto!
```

Mac (Apple Silicon / Intel) と Linux (ARM / x86_64) に対応してる。

## 作る側の流れ

```
1. flake.nix を書く
     ├─ inputs : 依存(nixpkgs)を宣言
     └─ outputs: 提供する成果物を関数で定義
        └─ writeShellScriptBin でシェルスクリプトを derivation 化

2. git add flake.nix
     ↑ flake は git tracked じゃないと黙って無視される

3. (任意) git push
     ↑ GitHubに置けば他のマシンから直接 nix run できる
```

## 実行側の流れ(`nix run .` を叩いた時)

```
[1] flake fetch
    inputs を取得して /nix/store/ に置く(初回のみ)
       │
       ▼
[2] 評価
    outputs 関数を呼ぶ
    → derivation(レシピ)が返る
    → /nix/store/<hash>.drv に書き出される
       │
       ▼
[3] realise
    .drv を見て build or cache から DL
    → /nix/store/<hash>-hello-rikuto/bin/hello-rikuto ができる
       │
       ▼
[4] 実行
    bin/hello-rikuto を exec
    → "Hello, rikuto!" が出力される
```

## ポイント

- ハッシュは内容由来。同じレシピなら誰がbuildしても同じpath
- 2回目以降は[1][3]スキップ → 一瞬で終わる
- `/nix/store/` はシステム共有プール。どのflake由来でもここに集まる
- `flake.lock` が依存のバージョンをハッシュで固定 → 再現可能

## 試し方

別のマシンから:

```bash
# Nixが入ってれば clone 不要
nix run github:karimiku/hello-rikuto
```

clone してから:

```bash
git clone https://github.com/karimiku/hello-rikuto
cd hello-rikuto
nix run .
```
