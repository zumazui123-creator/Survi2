# Web Accessibility TODOs

## Completed Refactoring (Networking Removal)
- [x] **Remove Multiplayer Nodes**: Deleted all `MultiplayerSynchronizer` and `MultiplayerSpawner` nodes from all scenes.
- [x] **Convert RPCs**: Refactored all `@rpc` decorated functions and `.rpc()` calls into standard function calls.
- [x] **UI Cleanup**: Modified `mainMenu.tscn` to remove IP input fields and "Join Game" functionality; renamed "Start Server" to "Start Game".
- [x] **Logic Adaptation**: Removed `multiplayer.is_server()` and `multiplayer.get_unique_id()` checks to ensure the game runs locally.
- [x] **Inventory/Combat Sync**: Updated all autoloads and component scripts to handle player data locally without network synchronization.

## Remaining Web-Specific Tasks
- [ ] **Export Configuration**:
    - [ ] Create an HTML5 Export Preset in Godot.
    - [ ] Ensure "VRAM Compression" is set correctly for web (usually ETC2 for mobile/web).
    - [ ] Set up the Progressive Web App (PWA) options if needed for offline play.
- [ ] **Filesystem Compatibility**:
    - [ ] Verify that `FileAccess` calls (like the one in `player.gd`) work within the browser sandbox (LocalStorage/IndexedDB).
    - [ ] Ensure no blocking synchronous file I/O is used during gameplay that could stall the main thread.
- [ ] **Optimization**:
    - [ ] Optimize texture sizes for faster initial download.
    - [ ] Convert high-bitrate audio to compressed formats (ogg/mp3) if not already done.
- [ ] **Deployment & Testing**:
    - [ ] Test the exported build on a local web server (e.g., `python -m http.server`).
    - [ ] Check for memory leaks in the browser console during long sessions.
   
