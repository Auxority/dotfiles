export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh

[[ -f /home/pengu/.dart-cli-completion/zsh-config.zsh ]] && . /home/pengu/.dart-cli-completion/zsh-config.zsh || true

# TODO: add world of tanks script
# TODO: Add install script to set permissions for world of tanks script
