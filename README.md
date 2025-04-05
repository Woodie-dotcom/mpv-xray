# 🎬 MPV Annotations Scripts

**MPV Annotations Scripts** provides Lua scripts for the MPV media player that display time-based annotations during video playback. Annotations show the names of people present in specific time intervals, fetched from either **local JSON files** or a **backend API**.

## ✨ Included Scripts

This repository contains two scripts providing similar functionality with different data sources:

1.  **`annotations.lua` (JSON Mode - Currently Disabled)**
    * Reads annotation data from a local JSON file located in the same directory and sharing the same name as the video file (e.g., `MyVideo.mp4` and `MyVideo.json`).
    * Requires the `json.lua` library.

2.  **`annotations_api.lua` (API Mode - Currently Active)**
    * Fetches annotation data dynamically by querying a backend API service over HTTP.
    * Requires the backend API service to be running.
    * Requires the `lua-socket` system library, `json.lua`, and `ltn12.lua`.

## ✨ Features

-   📌 **Automatic annotation loading**: Reads annotations from a local JSON file OR fetches them from a backend API based on the video filename.
-   ⏳ **Real-time display**: Shows the names of individuals present in the scene based on the loaded annotations.
-   🎛️ **Toggle visibility**: Annotations can be disabled during playback by changing the OSD level (usually by pressing `o` or `O` in mpv).
-   ⚡ **Optimized processing**: Sorts and processes annotation data efficiently to minimize performance impact on MPV.

## 🛠️ Requirements

### Common
-   MPV media player installed.

### For `annotations.lua` (JSON Mode)
-   A Lua JSON library (`json.lua`) placed in the `libs` subdirectory. ([rxi/json.lua](https://github.com/rxi/json.lua) is a good option).

### For `annotations_api.lua` (API Mode)
-   The **Video Annotations Backend API** service running and accessible from the machine running mpv. (See [Backend Setup](#-backend-setup) below).
-   **`lua-socket` system library**: Needs to be installed system-wide as it requires native C components. On Debian/Ubuntu-based systems (like WSL2):
    ```bash
    sudo apt update && sudo apt install lua-socket
    ```
-   A Lua JSON library (`json.lua`) placed in the `libs` subdirectory. ([rxi/json.lua](https://github.com/rxi/json.lua) is recommended).
-   The `ltn12.lua` library placed in the `libs` subdirectory. (You can get this from the `lua-socket` source distribution if you cloned it earlier, usually in the `src` directory).

## 🚀 Installation & Setup

1.  **Clone this repository:**
    ```bash
    git clone [https://github.com/Woodie-dotcom/mpv-xray.git](https://github.com/Woodie-dotcom/mpv-xray.git)
    # Navigate into the script directory for mpv
    cd mpv-xray
    ```

2.  **Prepare Libraries:**
    * Create the `libs` subdirectory if it doesn't exist: `mkdir -p libs`
    * Download `json.lua` (e.g., from [rxi/json.lua](https://github.com/rxi/json.lua)) and place it inside the `libs` directory (`libs/json.lua`).
    * Download `ltn12.lua` (e.g., from the [lua-socket source](https://github.com/lunarmodules/luasocket/blob/master/src/ltn12.lua)) and place it inside the `libs` directory (`libs/ltn12.lua`).

3.  **Install System Dependencies (for API mode):**
    * If you plan to use `annotations_api.lua`, install the `lua-socket` library:
        ```bash
        sudo apt update && sudo apt install lua-socket
        ```

4.  **Copy Script(s) to MPV Folder:**
    * Ensure your mpv scripts directory exists: `mkdir -p ~/.config/mpv/scripts/`
    * Copy the entire `mpv-xray` folder (or its contents) into mpv's scripts directory. A common way is to place this whole cloned folder inside `scripts`:
        ```bash
        # Example: move the cloned folder into mpv scripts
        mv ../mpv-xray ~/.config/mpv/scripts/
        ```
        Alternatively, copy individual files:
        ```bash
        cp annotations_api.lua annotations.lua.disabled libs/ ~/.config/mpv/scripts/ -R
        # Ensure libs folder and its contents (json.lua, ltn12.lua) are copied
        ```

5.  **Activate ONE Script:**
    * MPV loads all `.lua` files in its script directories. To avoid conflicts, **only one** annotation script should be active at a time.
    * The repository currently has `annotations_api.lua` active and `annotations.lua.disabled` inactive.
    * **To switch:**
        * **Activate JSON mode:** Rename `annotations_api.lua` to `annotations_api.lua.disabled` AND rename `annotations.lua.disabled` to `annotations.lua`.
        * **Activate API mode:** Rename `annotations.lua` to `annotations.lua.disabled` AND rename `annotations_api.lua.disabled` to `annotations_api.lua`.

6.  **Configure (for API mode):**
    * If using `annotations_api.lua`, edit the script file.
    * Find the `config` table near the top.
    * Update the `api_base_url` value (e.g., `"http://localhost:8123"`) to point to the correct address and port where your backend API is running.

## ▶️ Usage

1.  Ensure the desired script (`annotations.lua` or `annotations_api.lua`) is active (has `.lua` extension) in your mpv scripts directory, and the other is disabled (e.g., has `.disabled` extension).
2.  If using API mode, ensure the backend Docker containers (DB and API) are running (`docker-compose up -d` in the backend project directory).
3.  Start MPV with a video file: `mpv YourVideoFile.mp4`
4.  **If using JSON mode:** Make sure a `YourVideoFile.json` file with the correct format exists in the same directory as the video.
5.  **If using API mode:** Make sure the backend API has annotation data for the `YourVideoFile.mp4` filename.
6.  Annotations should appear automatically in the top-left corner during the specified time intervals. You can toggle OSD visibility (usually with `o` or `O`).

## 📄 Data Formats

### JSON File Format (`annotations.lua`)

The script expects a JSON file with the same name as the video file (e.g., `MyVideo.json` for `MyVideo.mp4`).

**Example:**
```json
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

### API Response Format (`annotations_api.lua`)  
The script makes a **GET request** to `/api/v1/annotations?filename=<your_video_filename>` on the configured `api_base_url`.  

It expects the API to return a **JSON response** with the exact same structure as the JSON file example above.  

---

### ⚙️ Backend Setup (for API Mode)  
The `annotations_api.lua` script requires a separate backend service to provide the annotation data. The code and setup instructions for the compatible backend (using Docker, Python/FastAPI, PostgreSQL) can be found in the companion repository:  

➡️ [https://github.com/Woodie-dotcom/video-annotations-api](https://github.com/Woodie-dotcom/video-annotations-api) ⬅️  
