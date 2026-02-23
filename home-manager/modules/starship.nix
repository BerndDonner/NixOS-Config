# modules/starship-bernd.nix
{ config, lib, pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;

    settings = {
      add_newline = true;

      # 1) Kontext (SSH/Nix/Venv/Pfad/Git)
      # 2) Status/Dauer (optional)
      # 3) Prompt-Symbol
      format = ''
        $hostname$nix_shell$env_var$directory$git_branch$git_status$git_state
        $status$cmd_duration
        $character
      '';

      character = {
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
      };

      hostname = {
        ssh_only = true;
        format = "[󰣀 $hostname](bold red) ";
      };

      nix_shell = {
        format = "[ nix:$state](bold yellow) [❯](bold yellow) ";
      };

      env_var = {
        VIRTUAL_ENV = {
          format = "[󰌠 venv](cyan) ";
          default = "";
        };
      };

      directory = {
        truncation_length = 4;
        truncate_to_repo = true;
        format = "[$path]($style) ";
      };

      git_branch = {
        symbol = " ";
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        format = "[$all_status$ahead_behind]($style) ";
        conflicted = "!";
        stashed = "$";
        modified = "*";
        staged = "+";
        renamed = "»";
        deleted = "✘";
        untracked = "?";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
      };

      git_state = {
        format = "[$state( $progress_current/$progress_total)]($style) ";
      };

      status = {
        disabled = false;
        symbol = "✘ ";
        format = "[$symbol$status]($style) ";
      };

      cmd_duration = {
        min_time = 1500;
        format = "[ $${duration}]($style) ";
      };
    };
  };
}
