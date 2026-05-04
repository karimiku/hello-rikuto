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

---

## 学習メモ: シェル/PATH/nix develop

`nix develop` を理解する過程で「そもそもシェルって何だっけ?」になったので
寄り道で整理した内容。

### シェル(bash, zsh)って何?

ユーザーからの入力コマンドを実行する役割を担うプログラム。

- ターミナルアプリ(Ghostty, iTerm, etc.) = **入れ物**
- シェル(zsh / bash / fish) = **入れ物の中で動く本体**

シェルがやってる仕事:
1. プロンプトを出す
2. 入力を受け取る
3. パースする(コマンド名と引数に分解)
4. PATH を辿って実体を探す
5. 子プロセスとして起動
6. 終わったら結果を表示、また 1 へ

Macのデフォルトは zsh(Catalina 以降)。

### プロンプトとは

「入力していいよ」とシェルが表示する目印。`$ ` とか `% ` とか、p10k入れてる
人ならカレントディレクトリやgitブランチや時刻が並んでるアレ。

### PATH の仕組み

PATH は単なる文字列。`:` 区切りで「どのディレクトリを探すか」のリスト。

```
PATH=/opt/homebrew/bin:/usr/bin:/bin
```

`npm` と打つと、シェルは前から順に:
- `/opt/homebrew/bin/npm` あった? → あり、これを実行(終わり)
- 残りのディレクトリは見にすら行かない

最初に見つかった時点で残りは無視。

確認コマンド:
```bash
which npm           # PATH で最初に見つかる npm を表示
which -a npm        # 全部の候補を表示
type npm            # ファイル/関数/エイリアス/builtin の判定
hash                # シェルのキャッシュ確認
hash -r             # キャッシュクリア(編集後反映されない時)
```

`cd` や `echo` などは PATH を辿らない。シェル組み込み(builtin)で
別途実装されてる。

### PATH の順番は誰が決める?

固定じゃなくて、ユーザー or インストーラ次第。

- macOSデフォルトは `/usr/bin:/bin:...` 程度
- brew のインストーラが `~/.zprofile` に `eval "$(brew shellenv)"` を
  仕込んで `/opt/homebrew/bin` を**先頭にprepend**
- nvm/volta/cargo/etc も同様にそれぞれ先頭に足す
- 結果: 自分のPATHは設定の積み重ねで散らかる

確認するなら `cat ~/.zshrc ~/.zprofile ~/.zshenv`。

### 親シェル / 子シェル

シェルは親子のプロセス階層を持つ。子シェルの環境変数(PATH含む)は
親から継承されるが、子で書き換えても**親には影響しない**。

```bash
echo $PATH       # 元のPATH

bash             # 子シェルを起動
PATH=/usr/bin    # 子の中だけPATH上書き
which ls         # /bin/ls 見えなくなる
exit

echo $PATH       # 元通り
```

`export` を付けないと、変数は子に継承されない:
```bash
FOO=hi
bash -c 'echo $FOO'      # 何も出ない

export FOO=hi
bash -c 'echo $FOO'      # hi
```

### nix develop が PATH に何をしてるか

`nix develop` は新しい bash 子シェルを起動して、その子シェルの PATH の
**先頭に flake で宣言したパッケージの bin** を差し込む:

```
[親シェル zsh]
PATH=/opt/homebrew/bin:/usr/bin:/bin

   ↓ nix develop 叩く

[子シェル bash]
PATH=/nix/store/aaa-nodejs-20/bin:/opt/homebrew/bin:/usr/bin:/bin
        ↑↑↑ ここが先頭にprepend ↑↑↑
```

シェルは PATH を前から探すので、`npm` を打つと Nix版が**最初に**見つかって、
brew版は見られない。`exit` すると bash 死亡 → zsh に戻る → PATH 元通り。

つまり「brewを消す」んじゃなくて「**もっと先に見るやつを差し込む**」が
正しい理解。npm/node そのものの中身は何も変わってない。
変わってるのは「どこの npm/node が起動されるか」だけ。

### プロジェクトA, Bでバージョンが違う場合

```
/nix/store/ にはこんな感じで両方並んで存在してる:

  /nix/store/
    ├── aaa-nodejs-18.20/         ← Node 18 の実体
    │     └── bin/node
    └── ccc-nodejs-20.10/         ← Node 20 の実体
          └── bin/node


[ターミナル1] cd ~/proj-A && nix develop
  PATH=/nix/store/aaa-nodejs-18.20/bin:/usr/bin:/bin
  $ node --version → v18.20.x


[ターミナル2] cd ~/proj-B && nix develop
  PATH=/nix/store/ccc-nodejs-20.10/bin:/usr/bin:/bin
  $ node --version → v20.10.x
```

両方の Node が同時に store に存在してる。各シェルが「どこを見るか」が
違うだけ。互いに干渉しない。

### つまり nix develop のキモ

- `nix develop` を叩くと、新しい bash 子シェルが起動
- そのシェルだけ PATH の先頭に flake 由来の bin が差し込まれる
- だから `npm install` するとNix版のnpmが自動的に呼ばれる
- 抜けたら全部元通り

「nix develop でシェルそのものが変わる」というより
「**親 zsh から派生した子 bash に切り替わる**(その子だけ PATH が違う)」
が正確なイメージ。

