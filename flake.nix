{
  description = "Upload a page to Cloudflare Pages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];

      perSystem = { pkgs, ... }:
        let
          webput = pkgs.writeShellApplication {
            name = "webput";
            runtimeInputs = [ pkgs.wrangler pkgs.coreutils ];
            runtimeEnv = {
              # Do not set CI=1: wrangler then refuses OAuth from `wrangler login`
              # and demands CLOUDFLARE_API_TOKEN. webput.sh sets XDG_CONFIG_HOME
              # so OAuth is not the user's global wrangler login.
              WRANGLER_SEND_METRICS = "false";
            };
            meta = {
              description = "Upload a page to Cloudflare Pages";
              license = pkgs.lib.licenses.mit;
            };
            text = builtins.readFile ./webput.sh;
          };
        in
        {
          formatter = pkgs.nixpkgs-fmt;

          packages = {
            inherit webput;
            default = webput;
          };
        };
    };
}
