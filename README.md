# PassFZF - Fuzzy Finder Interface for Pass

A modern, interactive fuzzy finder interface for the Unix standard password manager ([pass](https://www.passwordstore.org/)) with full subfolder support.

## Features

- 🔍 **Fuzzy search** through all password entries
- 📁 **Full subfolder navigation** with unlimited depth
- 🔐 **Quick copy** passwords to clipboard
- ✨ **Add new passwords** with folder selection
- ✏️ **Edit existing entries** inline
- 🗑️ **Delete entries** with confirmation
- 🔄 **Smart refresh** after operations
- 🎨 **Beautiful UI** with icons and previews
- ⚡ **Fast performance** with optimized caching

## Installation

### Oh My Zsh

1. Clone this repository into your custom plugins directory:
```bash
git clone https://github.com/username/passfzf.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/passfzf
```

2. Add `passfzf` to your plugins list in `~/.zshrc`:
```bash
plugins=(... passfzf)
```

3. Reload your shell:
```bash
source ~/.zshrc
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/username/passfzf.git ~/.config/passfzf
```

2. Add to your `~/.zshrc`:
```bash
source ~/.config/passfzf/passfzf.plugin.zsh
```

3. Reload your shell:
```bash
source ~/.zshrc
```

## Dependencies

- [pass](https://www.passwordstore.org/) - The standard Unix password manager
- [fzf](https://github.com/junegunn/fzf) - Command-line fuzzy finder
- `find` with `-printf` support (GNU findutils)
- Optional: `notify-send` for desktop notifications

### Installation of Dependencies

**Ubuntu/Debian:**
```bash
sudo apt install pass fzf findutils libnotify-bin
```

**Arch Linux:**
```bash
sudo pacman -S pass fzf findutils libnotify
```

**macOS:**
```bash
brew install pass fzf findutils
```

## Usage

Simply run:
```bash
passfzf
# or use the aliases
pf
pass-fzf
```

### Key Bindings

- **Enter**: Copy password to clipboard
- **Ctrl+Y**: Copy password and stay in interface
- **Ctrl+E**: Edit selected entry
- **Ctrl+D**: Delete selected entry (with confirmation)
- **Ctrl+N**: Add new password
- **ESC**: Exit

### Navigation

1. **Main View**: Shows categories and top-level entries
2. **Folder View**: Browse inside folders, see subfolders and entries
3. **Subfolder Support**: Navigate unlimited levels deep
4. **Search**: Start typing to search across all entries
5. **Back Navigation**: Use "← Back" option or ESC to go up

## File Structure

```
.
├── completions/
│   └── _passfzf              # Zsh completion
├── functions/
│   ├── passfzf               # Main function
│   ├── _passfzf_add_password # Add new password (global)
│   ├── _passfzf_add_folder_password # Add password in folder
│   └── _passfzf_browse_folder # Browse folder contents
├── LICENSE
├── passfzf.plugin.zsh        # Plugin entry point
└── README.md
```

## Configuration

### Environment Variables

- `PASSWORD_STORE_DIR`: Override default password store location (default: `~/.password-store`)
- `EDITOR`: Text editor for creating/editing passwords (default: `nvim`)

### Customization

You can customize the interface by modifying the functions in the `functions/` directory:

- **Icons**: Change the emoji icons used throughout the interface
- **Colors**: Modify fzf color schemes
- **Key bindings**: Add or modify keyboard shortcuts
- **Height**: Adjust window heights for different screen sizes

## Examples

### Basic Usage
```bash
# Launch the interface
passfzf

# Navigate to Email folder, then Personal subfolder
# Select gmail-personal entry to copy password
```

### Adding Passwords
```bash
# From main interface: Ctrl+N
# Select folder (e.g., Email/Personal/)
# Enter name: gmail-backup
# Edit password in your preferred editor
```

### Folder Structure Example
```
password-store/
├── Email/
│   ├── Personal/
│   │   ├── gmail-personal.gpg
│   │   ├── outlook-personal.gpg
│   │   └── yahoo-personal.gpg
│   └── Work/
│       ├── gmail-work.gpg
│       ├── office365.gpg
│       └── protonmail.gpg
├── Social/
│   ├── facebook.gpg
│   ├── twitter.gpg
│   └── Professional/
│       ├── linkedin.gpg
│       └── github.gpg
└── Banking/
    ├── primary-bank.gpg
    └── credit-cards.gpg
```

## Troubleshooting

### Common Issues

**"Command not found: passfzf"**
- Make sure the plugin is properly loaded in your `~/.zshrc`
- Restart your shell or run `source ~/.zshrc`

**"find: invalid predicate `-printf'"**
- You need GNU findutils. On macOS, install with `brew install findutils`
- The plugin requires the `-printf` option for performance

**Clipboard not working**
- Make sure `pass` is configured with a working GPG key
- Test with `pass show entry-name -c` manually

**No notifications**
- Install `libnotify` (Linux) or notification system for your OS
- Notifications are optional and won't affect core functionality

### Performance Tips

- For very large password stores (10000+ entries), the initial load may take few seconds. I have tested with 1000 plus entries and it loads instantly
- The interface caches results for faster subsequent operations
- Use search (start typing) to quickly filter large lists

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with your password store
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- [pass](https://www.passwordstore.org/) - The standard Unix password manager
- [fzf](https://github.com/junegunn/fzf) - Amazing fuzzy finder
- Zsh community for the plugin ecosystem
