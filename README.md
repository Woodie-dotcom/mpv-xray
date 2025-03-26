# 🎬 MPV Annotations Script

MPV Annotations Script** is a **Lua** script for the MPV media player that displays time-based annotations during video playback. It reads annotation data from a **JSON file** that shares the same name as the video file and shows the names of people present in specific time intervals.

## ✨ Features
- 📌 Automatic annotation loading**: Reads annotations from a JSON file located in the same directory as the video.
- ⏳ Real-time display**: Shows the names of individuals present in the scene at specific timestamps.
- 🎛️ **Toggle visibility**: Annotations can be disabled during playback by changing the OSD level.
- ⚡ Optimized processing**: Sorts and processes annotation data efficiently to minimize performance impact on MPV.


## 🛠️ Requirements
- MPV installed
- Lua
- json.lua 
## 🚀 Installation
1. Clone the repository:  
   bash
   git clone https://github.com/YOUR-USERNAME/mpv-annotations.git
2. Move the script to MPV's script folder:
   mkdir -p ~/.config/mpv/scripts
   cp annotations.lua json.lua ~/.config/mpv/scripts/
3. Run MPV with any video, and if a JSON file with annotations exists, names will be displayed automatically.
4. JSON Format Example (the script expects a JSON file with the same name as the video file.):
  ```
{
  "Mario Rossi": [
    ["00:00:10", "00:11:30"],
    ["00:12:23", "00:22:30"]
  ],
  "Anna Bianchi": [
    ["00:01:00", "00:09:45"],
    ["00:15:00", "00:16:30"]
  ]
} 
```
  

    

