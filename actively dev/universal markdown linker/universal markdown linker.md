
## Features

-   Works on all major operating systems (MacOS, Linux, and Windows)
-   Supports Markdown editors, note-taking apps, and knowledge management apps.
-   Correctly links your markdown files from supported apps to GitHub without the struggle of manually linking the files path manually.
-   CLI support is planned for the future, with MacOS being the priority, Linux as secondary, and Windows as last.
-   The script is open source and actively maintained by [Angel Haro](https://github.com/aharo24)

## Supported apps

-   Obsidian
-   Evernote
-   OneNote
-   Notion
-   Typora
-   Turtl
-   ZimWiki
-   Standard Notes
-   Joplin
-   Boostnote
-   Simplenote
-   Laverna
-   Joplin
-   Bear
-   Turtl
-   Joplin
-   Simplenote
-   Standard Notes
-   Zim
-   JotterPad
-   nvAlt
-   Roam Research
-   Simplenote
-   Standard Notes

## Installation

Copy code

`python linker.py`

## Requirements

-   Python 3

## Progressively working on

-   Error handling to handle cases where the input files are not found or are not in the expected format.
-   A command line argument parser to make it easy for the user to specify the input and output directories.
-   An option to backup the original files before modifying them.
-   A progress bar to show the user the progress of the script.
-   An option to recursively search for files only in specific subdirectories.
-   An option to only search for specific file types other than .md
-   An option to search for a different pattern other than `![](../z/file_name.png)`
-   An option to specify the new_path in the replacement, instead of calculating it in the script.
-   An option to dry run the script without making any changes to the files.
-   An option to check the number of changes made to the files.
-   Adding CLI support


