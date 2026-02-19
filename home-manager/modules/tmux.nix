{ config, pkgs, lib, inputs, ... }:

{
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    mouse = true;
    escapeTime = 0;
    historyLimit = 20000;
    terminal = "tmux-256color";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
    ];

    extraConfig = ''
      unbind C-b
      set -g prefix C-a
      bind C-a send-prefix

      set -g default-terminal "tmux-256color"
      set -ag terminal-overrides ',xterm-256color:RGB'
      set -g allow-passthrough on

      setw -g mode-keys vi
      set -g status-keys vi
      set -s escape-time 0
      set -g mouse on
      set -g history-limit 20000
      set -g base-index 1
      setw -g pane-base-index 1

      set -g status-bg colour236
      set -g status-fg colour223
      set -g message-style fg=colour223,bg=colour239
      set -g pane-border-style fg=colour239
      set -g pane-active-border-style fg=colour111
      set -g status-left " ⎈ #S "
      set -g status-right " %Y-%m-%d %H:%M "

      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      set -g set-clipboard on

      bind - split-window -h -c "#{pane_current_path}"
      bind _ split-window -v -c "#{pane_current_path}"
      bind x kill-pane

      bind C-h select-pane -L
      bind C-j select-pane -D
      bind C-k select-pane -U
      bind C-l select-pane -R

      bind r source-file ~/.config/tmux/tmux.conf \; display "tmux.conf reloaded ✅"
      bind e split-window -v -c "#{pane_current_path}" "hx"
    '';
  };
}
