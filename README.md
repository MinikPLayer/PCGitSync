# PCGitSync
Simple tray app to automate quirks when using *git* as a PC synchronization method.

<img src="https://github.com/MinikPLayer/PCGitSync/blob/main/Screenshot.png" alt="drawing" width="600"/>

# Git as a PC sync method
Shared directory set up as a git project. This allows to work on different project asynchronously with different machines, but there are some quirks. For example if there is a *.git* folder in one of subfolders, then it would be treated as a git submodule (which is not what we want). To avoid this *.git* folder should be renamed to something else (like *.git_disabled*) before sync, and after sync renamed back. This process can be easily automated with this tray app.

# Usage
Just download the latest release and unpack to any folder. Run **repos_synchronizer.exe**, which should spawn a new icon in your system tray. You can bring it to the screen by clicking the icon or by pressing a hotkey *CTRL+ALT+R*. Then select project directory from settings menu. Now app should automatically pick up you repository, and you can manipulate it using one of the provided buttons. Buttons will be greyed out when action is not available.

# Compatibility
App is tested on *Windows 10* (uses Aero effect) and *Windows 11* (uses Mica effect). Should also work on Linux after installing required packages (**ayatana-appindicator3-0.1** or **appindicator3-0.1** depending on distro version). App is **not** tested on macOS because i don't have any compatible device, but it *should* work.
