export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh

[[ -f /home/pengu/.dart-cli-completion/zsh-config.zsh ]] && . /home/pengu/.dart-cli-completion/zsh-config.zsh || true

update_wot_mods() {
    if [ -f "$HOME/.world-of-tanks/update-mods.sh" ]; then
        bash "$HOME/.world-of-tanks/update-mods.sh"
    else
        echo "⚠️  WoT mods update script not found at $HOME/.world-of-tanks/update-mods.sh"
    fi
}
