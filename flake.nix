{
  # flake = inputs(依存)と outputs(成果物)を宣言するファイル

  description = "hello-rikuto: my first flake";

  # ---- inputs ----
  # nixpkgs(github.com/NixOS/nixpkgs)に依存。
  # 世界中のパッケージ定義 + 便利関数が入ってる「材料屋さん」。
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  # ---- outputs ----
  # outputs は関数。inputs(取得・評価済み)を引数で受け取る。
  outputs = { nixpkgs, ... }:

    let
      # 対応するアーキテクチャの一覧。MacもLinuxも両方カバー。
      # 自分以外のマシンでも動かせるようにするためのリスト。
      systems = [
        "aarch64-darwin"   # Apple Silicon Mac
        "x86_64-darwin"    # Intel Mac
        "aarch64-linux"    # ARM Linux (WSL含む、ラズパイ等)
        "x86_64-linux"     # 普通のLinux (WSL含む)
      ];

      # systems の各要素に対して関数を適用して attrset を作るヘルパー。
      # 例: forAllSystems (sys: f sys)
      #   → { aarch64-darwin = f "aarch64-darwin"; x86_64-darwin = f "x86_64-darwin"; ... }
      forAllSystems = nixpkgs.lib.genAttrs systems;

    in {
      # 各システムごとに packages.<system>.default を作る。
      # forAllSystems が裏で4つのシステム全部に対して同じ derivation を作ってくれる。
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = pkgs.writeShellScriptBin "hello-rikuto" ''
            echo "Hello, rikuto!"
          '';
        });

      # devShells: nix develop で入れる開発用シェル環境。
      # ここに書いたパッケージが PATH に差し込まれた bash 子シェルが起動する。
      # mkShell は「dev環境を作るための専用ヘルパー」。
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              shellcheck      # シェルスクリプトのlinter
              nixpkgs-fmt     # .nixファイルのformatter
            ];
            shellHook = ''
              echo "🚀 hello-rikuto dev shell"
              echo "  shellcheck: $(shellcheck --version | grep version: | head -1)"
              echo "  nixpkgs-fmt: $(nixpkgs-fmt --version)"
            '';
          };
        });
    };
}
