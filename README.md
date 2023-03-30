# steam-first-time-reset
Small Utility that shows which games have first-time-setups and allows to reset their status

![pwsh_BemJeoaQcD](https://user-images.githubusercontent.com/118403/228699188-38183b8f-4991-417f-8472-c2323e3eb8c9.png)

## Usage

1. Clone or [Download](https://github.com/Gordin/steam-first-time-reset/archive/refs/heads/main.zip) and extract this repository
2. start steam-reset.vbs (If you want console output, run the .bat or .ps1 file from a terminal instead)
4. The tools will show a list of all installed steam games, their install scripts, and their entry in the Windows registry. (If it does not show anything in the hasRunKey column, then there is nothing to reset, the script for that game will run every time you start it)
5. Select a game and Press OK. The tool will delete the registry key that steam checks to see if the script was already run.

## vcredist/dotNet/Directx stuff

This tool does not handle dependency chains between games (yet).
If you want to reset the state of Visual Studio redistributables, Directx, or dotNet, you can select the game "Steam Common Redistributables".
This will reset ALL of those though, so you might want to just look at the local files for "Steam Common Redistributable" and run the setup you want yourself.

## Disclaimer

I made this tool using ChatGPT with the GPT-4 model, I have never actually written anything in PowerShell before this, you have been warned...

I wanted to test how well using ChatGPT works when I use a language I have never used (PowerShell) and because I wanted to see how well it does when writing a program that doesn't exist yet.
(At least I didn't find another program that resets Steam first time setups, just reddit posts)
