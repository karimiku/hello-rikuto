{
  # flake = inputs(依存)と outputs(成果物)を宣言するファイル
  # 中身は全部で1個の attrset(連想配列みたいなやつ)

  # ただの説明文。書かなくても動く
  description = "hello-rikuto: my first flake";

  # ---- inputs ----
  # このflakeが何に依存するか。
  # nixpkgs は github.com/NixOS/nixpkgs っていう実在のリポで、
  # 世界中のパッケージ定義 + 便利関数がまとめて入ってる「材料屋さん」。
  # 自分はそこに push したりはしなくて、import して使うだけ。
  #
  # echo するだけのスクリプトでも、結局 bash とか coreutils とか要るから
  # ほぼ全部のflakeはここに依存することになる(Nix単体だと bash すら無い)。
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  # ---- outputs ----
  # outputs は関数。inputs で書いた依存が取得・評価済みで渡ってくる。
  # { nixpkgs, ... } で nixpkgs を引数として受け取る。
  # ... は他に来るかもしれない引数(self とか)を無視するやつ。
  outputs = { nixpkgs, ... }:

    # let ... in ... は局所変数を定義する構文。
    # let で変数を作って、in の後ろの式の中でその変数が使える。
    let
      # アーキテクチャを書く。M系Macは aarch64-darwin。
      system = "aarch64-darwin";

      # nixpkgs の中から自分の system 用のパッケージ集合を取り出して、
      # pkgs って名前で扱えるようにする。
      # ${system} は文字列展開。
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # ---- outputs 本体 ----
      # packages.<system>.<name> は flake のお作法的な書き方。
      # default は `nix run .` で省略した時に選ばれる名前。
      #
      # writeShellScriptBin は pkgs の中の便利関数。
      # (名前, スクリプト本体) を渡すと derivation を返してくれる。
      # その derivation を realise すると:
      #   /nix/store/<hash>-hello-rikuto/bin/hello-rikuto
      # っていう実行ファイル付きのディレクトリができる。
      #
      # nix run . の流れまとめ:
      #   1. flake.nix を評価して outputs を呼ぶ
      #   2. packages.aarch64-darwin.default にある derivation を取り出す
      #   3. realise する(自前 build か cache から DL)
      #   4. 出来上がった bin/hello-rikuto を実行
      packages.${system}.default = pkgs.writeShellScriptBin "hello-rikuto" ''
        echo "Hello, rikuto!"
      '';
    };
}
