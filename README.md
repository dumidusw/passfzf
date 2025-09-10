# passfzf 🔐

> Fuzzy-find, copy, edit, delete, and create passwords 
> in [pass](https://www.passwordstore.org/) using [fzf](https://github.com/junegunn/fzf) — all from your Zsh terminal.

![passfzf demo](https://via.placeholder.com/800x400?text=Add+a+screenshot+later+%F0%9F%98%89)

## ✨ Features

- 🔍 Fuzzy search through your password store
- 📋 Copy password to clipboard with `Enter` or `Ctrl+Y`
- ✏️ Edit entry in Neovim with `Ctrl+E`
- 🗑️ Delete with confirmation via `Ctrl+D`
- ➕ Create new password entries with folder picker + metadata support
- 🧩 Universal Zsh plugin — works with `zinit`, `oh-my-zsh`, `zplug`, `antigen`, and manual sourcing

## ⚙️ Requirements

- [`pass`](https://www.passwordstore.org/) (Password Store)
- [`fzf`](https://github.com/junegunn/fzf)
- `zsh`
- `gpg` (for `pass` backend)
- Optional: `notify-send` for desktop notifications

## 📦 Installation

### zinit (recommended)

Add to your `~/.zshrc`:

```zsh
zinit load dumidusw/passfzf
```

Then restart shell:

```bash
exec zsh
```
oh-my-zsh

```bash
git clone https://github.com/dumidusw/passfzf.git ~/.oh-my-zsh/custom/plugins/passfzf
```

Then in ~/.zshrc, add passfzf to your plugin list:

```bash
plugins=(git passfzf ...)
```

Restart shell:

```bash
source ~/.zshrc
```

zplug

```bash
zplug "dumidusw/passfzf"
```

antigen

```bash
antigen bundle dumidusw/passfzf
```

Manual

```bash
git clone https://github.com/dumidusw/passfzf.git ~/passfzf
```

Then in ~/.zshrc:

```zsh
source ~/passfzf/passfzf.plugin.zsh
```

🧪 Usage
Just run:

```bash
passfzf
```
Use arrow keys, Enter, Ctrl+E, Ctrl+D, Ctrl+N as shown in UI.

📜 License
MIT — see LICENSE
