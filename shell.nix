{ pkgs ? import <nixpkgs> {} }:
let
  # the magic: use a yarn hook to patch rescript just before the build step
  # https://github.com/yarnpkg/yarn/blob/master/src/util/hooks.js
  yarnWrapper = pkgs.writeScriptBin "yarn" ''
    #!${pkgs.nodejs}/bin/node
    const { promisify } = require('util')
    const child_process = require('child_process');
    const exec = promisify(child_process.exec)
    const { existsSync } = require('fs')
    async function getYarn() {
        const yarn = "${pkgs.yarn}/bin/yarn"
        if (existsSync(`''${yarn}.js`)) return `''${yarn}.js`
        return yarn
    }
    global.experimentalYarnHooks = {
        async buildStep(cb) {
            console.log("\npatching rescript")
            await exec(`patchelf \
              --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              --set-rpath "${pkgs.stdenv.cc.cc.lib}/lib" \
              ./linux/*.exe`, {
                cwd: `${toString ./.}/node_modules/rescript`
            })
            const res = await cb()
            return res
        }
    }
    getYarn().then(require)
'';

in

pkgs.mkShell {
  name = "frontend";

  packages = with pkgs; [
    yarnWrapper
  ];
}
