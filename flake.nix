{
  description = "Upload a page to Cloudflare Pages";

  inputs = {
    corepkgs.url = "github:ekala-project/corepkgs";
  };

  outputs = { corepkgs, ... }:
    corepkgs.lib.mkFlake {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      packages = pkgs:
        let
          # wrangler's `pnpm tsup` build dies on aarch64-darwin under node 24:
          #
          #   > DTS ⚡️ Build success in 3949ms
          #   > (node:61813) Warning: File descriptor 21 closed but not opened in unmanaged mode
          #   > AggregateError: EBADF: bad file descriptor, read
          #   >     at FSReqCallback.readFileAfterClose [as oncomplete] (node:internal/fs/read/context:77:21)
          #
          # Not the file-descriptor limit (it fails the same way with
          # `ulimit -n 8192` in the build) and not the revision; the same recipe
          # builds under node 24 on Linux. Node 22 builds it on Darwin.
          wrangler =
            if pkgs.stdenv.hostPlatform.isDarwin then
              pkgs.wrangler.override { nodejs = pkgs.nodejs_22; }
            else
              pkgs.wrangler;

          # writeShellApplication would run shellcheck over the script, and
          # shellcheck is a Haskell program: it drags GHC into the closure of
          # every `nix run`, for a lint this one-file script does not need.
          webput = pkgs.writeTextFile {
            name = "webput";
            executable = true;
            destination = "/bin/webput";
            meta = {
              description = "Upload a page to Cloudflare Pages";
              license = pkgs.lib.licenses.mit;
              mainProgram = "webput";
            };
            text = ''
              #!${pkgs.runtimeShell}
              set -o errexit
              set -o nounset
              set -o pipefail

              export PATH="${pkgs.lib.makeBinPath [ wrangler pkgs.coreutils ]}:$PATH"
              # Do not set CI=1: wrangler then refuses OAuth from `wrangler login`
              # and demands CLOUDFLARE_API_TOKEN. webput.sh sets XDG_CONFIG_HOME
              # so OAuth is not the user's global wrangler login.
              export WRANGLER_SEND_METRICS="false"

            '' + builtins.readFile ./webput.sh;
          };
        in
        {
          inherit webput;
          default = webput;
        };

      formatter = pkgs: pkgs.nixfmt-rs;
    }
    // {
      # ekapkgs' binary cache; without it wrangler would build from source.
      nixConfig = {
        extra-substituters = [ "https://ekala-corepkgs.cachix.org" ];
        extra-trusted-public-keys = [
          "ekala-corepkgs.cachix.org-1:DcZV+vegWoEzacbSdXFXU4S7728C0eS9RfGpKeyHd6w="
        ];
      };
    };
}
