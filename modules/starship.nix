# modules/starship.nix  (NixOS-Modul)
{ config, lib, pkgs, ... }:

{
  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;

      command_timeout = 1000;
      continuation_prompt = "[╰─ ](bold green)";

      format = ''
        [╭─](bold green)[](fg:#86BBD8)$username$hostname[](fg:#86BBD8 bg:#D8BB86)$directory[](fg:#D8BB86 bg:#FCA17D)$git_branch$git_status$git_state[](fg:#FCA17D bg:#FCF392)$nix_shell$env_var$golang$nodejs$bun$deno$ruby$rust$python$lua[](fg:#FCF392)
        [╰─$character ](bold green)
      '';

      right_format = "$status$cmd_duration$time";
      line_break = { disabled = true; };

      character = {
        success_symbol = "[](bold green)";
        error_symbol = "[](bold red)";
      };

      os = {
        disabled = false;
        style = "fg:#ffffff bg:#33658A";
        format = "[ $symbol ]($style)";
      };

      username = {
        show_always = true;
        style_user = "bg:#86BBD8 fg:#000000";
        style_root = "bold bg:#86BBD8 fg:#000000";
        format = "[  ($user) ]($style)";
      };

      hostname = {
        ssh_only = true;
        style = "bg:#86BBD8 fg:#000000";
        format = "[ $hostname ]($style)";
      };

      directory = {
        truncate_to_repo = true;
        truncation_length = 4;
        truncation_symbol = "…/";
        style = "bg:#D8BB86 fg:#000000";
        format = "[ $path ]($style)";
      };

      git_branch = {
        symbol = " ";
        style = "bg:#FCA17D";
        truncation_length = 20;
        format = "[[ $symbol$branch ](fg:#000000 bg:#FCA17D)]($style)";
      };

      git_status = {
        style = "bg:#FCA17D";
        format = "[[($all_status$ahead_behind )](fg:#000000 bg:#FCA17D)]($style)";

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
        format = "[($state( $progress_current/$progress_total ))](fg:#000000 bg:#FCA17D)";
      };

      nix_shell = {
        style = "fg:#000000 bg:#FCF392";
        format = "[  ]($style)";
      };

      env_var = {
        VIRTUAL_ENV = {
          style = "fg:#000000 bg:#FCF392";
          format = "[ 󰌠 $env_value ]($style)";
        };
      };

      status = {
        disabled = false;
        symbol = "✘";
        success_symbol = "";
        style = "bold red";
        format = " [$symbol $status]($style)";
        map_symbol = true;
      };

      cmd_duration = {
        min_time = 1500;
        style = "bold yellow";
        format = " [ $duration]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "fg:#ffffff";
        format = " [󰥔 $time]($style)";
      };

      python = { style = "fg:#000000 bg:#FCF392"; format = "[ $symbol$version ]($style)"; };
      rust   = { style = "fg:#000000 bg:#FCF392"; format = "[ $symbol$version ]($style)"; };
      golang = { style = "fg:#000000 bg:#FCF392"; format = "[ $symbol$version ]($style)"; };
      nodejs = {
        style = "fg:#000000 bg:#FCF392";
        format = "[ $symbol$version ]($style)";
        detect_files = [ "package.json" ".node-version" "!bunfig.toml" "!bun.lockb" ];
      };
      bun  = { style = "fg:#000000 bg:#FCF392"; format = "[ $symbol$version ]($style)"; };
      deno = { style = "fg:#000000 bg:#FCF392"; format = "[ $symbol$version ]($style)"; };
      ruby = { style = "fg:#000000 bg:#FCF392"; format = "[ $symbol$version ]($style)"; };
      lua  = { style = "fg:#000000 bg:#FCF392"; format = "[ $symbol$version ]($style)"; };

      package = {
        style = "fg:#000000 bg:#7DF9AA";
        format = "[ $symbol$version ]($style)";
      };

      aws = {
        style = "bg:#9A86D8";
        format = "[[ $symbol$profile ](fg:#000000 bg:#9A86D8)]($style)";
      };
      azure = {
        disabled = false;
        style = "bg:#9A86D8";
        format = "[[ $symbol$subscription ](fg:#000000 bg:#9A86D8)]($style)";
      };
      gcloud = {
        style = "bg:#9A86D8";
        format = "[[ $symbol$account ](fg:#000000 bg:#9A86D8)]($style)";
      };
      kubernetes = {
        disabled = false;
        style = "bg:#9A86D8";
        format = "[[ $symbol$context ](fg:#000000 bg:#9A86D8)]($style)";
      };

      docker_context = {
        style = "bg:#06969A";
        format = "[[ $symbol$context ](fg:#000000 bg:#06969A)]($style)";
      };
    };
  };
}
