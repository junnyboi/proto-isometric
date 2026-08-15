# Cardinal runtime sheet contract

Only approved transparent runtime sheets belong in this directory. The review contact sheet is not a runtime asset.

Expected files:

- `cardinal_walk_n.png`, `cardinal_walk_ne.png`, `cardinal_walk_e.png`, `cardinal_walk_se.png`
- `cardinal_walk_s.png`, `cardinal_walk_sw.png`, `cardinal_walk_w.png`, `cardinal_walk_nw.png`
- Optional attack family using the same suffixes: `cardinal_attack_<direction>.png`

Each sheet is a horizontal strip of same-sized square RGBA cells. Every delivered Cardinal sheet must use one shared cell size; the adapter derives that size from the sheet height and scales it to a 148-pixel runtime presentation height. It discovers direction families automatically, uses 12 FPS for walk and 15 FPS for attack, and falls back to the procedural Cardinal proxy when a requested sheet is absent.
