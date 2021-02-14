# cs.vim
* Vim plugin to query cheat sheet from [cheat.sh](https://cheat.sh/). This plugin is an alternative to [cheat.sh-vim](https://github.com/dbeniamine/cheat.sh-vim).
* Do not forget to view ```cheat.sh``` [intro page](https://cheat.sh/:intro) to learn more about it.
* This plugin make use of ```curl``` application to query information directly from vim. Makesure curl is executable by vim.
* Execute this command in vim to check:
  ```vim
  :echo executable('curl')
  ```

## Installation
* Installation using [Vundle.vim](https://github.com/VundleVim/Vundle.vim).
  ```vim
  Plugin 'farhanmustar/cs.vim'
  ```

* Installation using [vim-plug](https://github.com/junegunn/vim-plug).
  ```vim
  Plug 'farhanmustar/cs.vim'
  ```

## Features
* Add ```:CS``` command to query cheat sheet.
  ```vim
  :CS python
  ```
* ```:CS``` also have autocomplete that utilize ```:list``` command from cheat.sh.
* Inside the result buffer there are ```>``` and ```<``` keyboard shortcut to move to next or previous answer.
* ```<leader>cs```key binding :-
  * ```normal mode``` - automatically add query for the word under the curso and put you in command mode.
  * ```visual mode``` - automatically add query for the word highlighted and put you in command mode.
* space in query is automatically converted to ```+``` as per cheat.sh specification.

## Demo
![Demo gif](https://github.com/farhanmustar/cs.vim/wiki/demo.gif)
