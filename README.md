# Autoenv

> Until recently, the default file name used by this plugin was `.env`, but now it is `.in`. This is done in order not to conflict with `.env` files from numerous projects.

#### Autoenv automatically sources (known/whitelisted) `.in` and `.out` files.

This plugin adds support for enter and leave events. By default `.in` files are used when entering a directory, and `.out` files when leaving a directory. And you can set variable `CLICOLOR=1` for enabling colored output.

The environment variables `$AUTOENV_IN_FILE` & `$AUTOENV_OUT_FILE` can be used
to override the default values for the file names of `.in` & `.out` respectively.

![](term.png)

## Example of use

- If you are in the directory `/home/user/dir1` and execute `cd /var/www/myproject` this plugin will source the following files if they exist

```
/home/user/dir1/.out
/home/user/.out
/home/.out
/var/.in
/var/www/.in
/var/www/myproject/.in
```

- If you are in the directory `/` and execute `cd /home/user/dir1` this plugin will source the following files if they exist

```
/home/.in
/home/user/.in
/home/user/dir1/.in
```

- If you are in the directory `/home/user/dir1` and execute `cd /` this plugin will source the following files if they exist

```
/home/user/dir1/.out
/home/user/.out
/home/.out
```

## Examples of `.in` and `.out` files

Please, don't use `pwd` or `$PWD`, instead of this use `$(dirname $0)`. Additionally, the path of the directory being entered or exited is passed as the first argument to both `.in` and `.out` scripts, should using a symlink be preferred.

### For node.js developing:

### .in

```sh
nvm use node
OLDPATH=$PATH
export PATH="$(dirname $0)/node_modules/.bin":$PATH
```

### .out

```sh
nvm use system
export PATH=$OLDPATH
```

### For projects with `.env` or/and `.env.local`

```sh
source $(dirname $0)/.env*
```

## Prerequisites

#### This plugin depends on [zsh-colors](https://github.com/zpm-zsh/colors).

If you don't use [zpm](https://github.com/zpm-zsh/zpm), install it manually and activate it before this plugin. 
If you use zpm you don’t need to do anything


## Installation

### Using [zpm](https://github.com/zpm-zsh/zpm)

Add `zpm load zpm-zsh/autoenv` into `.zshrc`

### Using [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)

Execute `git clone https://github.com/zpm-zsh/autoenv ~/.oh-my-zsh/custom/plugins/autoenv`. Add `autoenv` into plugins array in `.zshrc`

### Using [Fig](https://fig.io)

Fig adds apps, shortcuts, and autocomplete to your existing terminal.

Install `autoenv` in just one click.

<a href="https://fig.io/plugins/other/autoenv_zpm-zsh" target="_blank"><img src="https://fig.io/badges/install-with-fig.svg" /></a>

### Using [antigen](https://github.com/zsh-users/antigen)

Add `antigen bundle zpm-zsh/autoenv` into `.zshrc`

### Using [zgen](https://github.com/tarjoilija/zgen)

Add `zgen load zpm-zsh/autoenv` into `.zshrc`
