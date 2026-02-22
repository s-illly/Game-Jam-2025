# Resume Bullet Points — Game Jam 2025

The following bullet points are ready to drop into a resume under a **Projects** section.
Feel free to pick the ones that best match the role you're applying for.

---

## 🎮 Game Jam 2025 — *First-Person 3D Horror Game* | Godot 4.5 · GDScript · Python · OpenCV · MediaPipe

- **Engineered a real-time computer-vision control scheme** using Python, OpenCV, and MediaPipe to track hand-landmark positions via webcam, translating normalized finger-tip coordinates into in-game camera rotation — replacing traditional mouse input with gesture-based control.

- **Implemented a cross-process IPC pipeline** between a Python hand-tracking subprocess and Godot 4.5 using a TCP socket server, enabling sub-frame latency data transfer and clean lifecycle management (spawn on launch, kill on exit).

- **Designed and coded a dynamic enemy AI state machine** in GDScript featuring configurable grace periods, adaptive spawn positioning (front/back based on player look-back history), line-of-sight detection via dot-product math, and automatic despawn conditions — creating emergent, skill-responsive difficulty.

- **Built an infinite procedural hallway system** using a fixed-pool segment recycler: segments behind the player are repositioned ahead, with lights re-randomized on each recycle to maintain variety without increasing memory usage.

- **Crafted an immersive 3D spatial audio system** with randomized ambient SFX scheduling (probability-weighted intervals), dynamic volume fade-in/fade-out on all audio players via lerp, procedurally varied footstep playback (randomized pitch, pan, and stream seek position), and per-player original-volume bookkeeping for correct restoration.

- **Developed a flashlight-driven tension mechanic** where sustained darkness (low flashlight energy) triggers an AI spawn countdown, and restoring light cancels it — coupling the visual and gameplay systems to reinforce horror atmosphere.

- **Authored clean, export-variable–driven GDScript** across all systems (AI, player, hallway manager, audio), making every tunable parameter inspector-editable for fast iteration without code changes.

- **Delivered a complete game loop** — main menu, rules screen, full-screen 3D gameplay scene, and graceful exit — within a game-jam time constraint using Godot 4.5's scene/node architecture.
