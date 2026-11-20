{ inputs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      opencode = prev.symlinkJoin {
        name = "opencode-${inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.opencode2.version}";
        paths = [ inputs.llm-agents.packages.${final.stdenv.hostPlatform.system}.opencode2 ];
        postBuild = "mv $out/bin/opencode2 $out/bin/opencode";
      };
      x-ui = final.callPackage ../pkgs/x-ui.nix { };
    })
  ];
}
