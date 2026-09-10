# modules/nixos/bash.nix  (NixOS-Modul)
{ config, lib, pkgs, ... }:

{
  programs.bash = {
    enable = true;

    # Entspricht HM: programs.bash.initExtra
    interactiveShellInit = ''
      [[ $- == *i* ]] || return
      [[ -t 1 ]] || return   # nur wenn stdout ein TTY ist (schützt scp/ssh cmd)

      source ${pkgs.blesh}/share/blesh/ble.sh

      export EDITOR=hx
      export VISUAL=hx

      ble-bind -m vi_imap -f 'C-x C-e' edit-and-execute-command
      ble-bind -m vi_nmap -f 'C-x C-e' edit-and-execute-command

      # vi keymap aktivieren
      bleopt default_keymap=vi

      # Ctrl-C: aktuelle Commandline verwerfen und neuen Prompt anzeigen
      ble-bind -m vi_imap -f 'C-c' discard-line
      ble-bind -m vi_nmap -f 'C-c' discard-line

      # Highlighting / Completion (dark-friendly)
      bleopt highlight_syntax=1
      bleopt highlight_filename=1
      bleopt complete_auto_menu=1
      bleopt complete_menu_style=desc

      # History
      bleopt history_erasedups_limit=2000
      bleopt history_limit_length=10000
      bleopt history_share=1

      # Substring-History auf Up/Down (Insert + Normal)
      ble-bind -m vi_imap -f up   history-substring-search-backward
      ble-bind -m vi_imap -f down history-substring-search-forward
      ble-bind -m vi_nmap -f up   history-substring-search-backward
      ble-bind -m vi_nmap -f down history-substring-search-forward

      # / startet “nsearch” (fühlt sich wie Editor-Suche an)
      ble-bind -m vi_nmap -f '/'  history-nsearch-backward

      __ble_starship_prompt() {
        # Linux Kernel TTY (fbcon): keine Nerd-Fonts -> Plain Prompt
        if [[ $TERM == linux ]]; then
          PS1='\u@\h:\w\$ '
        else
          PS1="$(${pkgs.starship}/bin/starship prompt)"
        fi
      }
      blehook PRECMD+='__ble_starship_prompt'
    '';

    # Entspricht HM: programs.bash.profileExtra (Login-Shell)
    loginShellInit = ''
      if [[ -f ~/.bashrc ]]; then
        . ~/.bashrc
      fi
    '';
  };
}
