## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately - don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes - don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests - then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

### 7. Device Experimentation Log
- After ANY feature attempt, bug fix, or experiment that touches device-level behavior:
  record what was tried, what happened, and what was learned in `docs/DEVICE_NOTES.md`.
- Every entry MUST include the date in the heading: `## YYYY-MM-DD — Title`.
- Especially record: error codes, failed approaches, and why they failed.
- This applies even to reverted changes — the knowledge of what does NOT work is valuable.
- Before attempting changes to audio, media, or platform APIs: read `docs/DEVICE_NOTES.md`
  first to avoid repeating known failures.
- Symbian MMF is fragile — bad API calls can brick the audio device until phone restart.
  Always check device notes before touching audio/media code.

## Core Principles
- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.

## Project Overview
- Podcast client for Symbian Belle (Nokia C7), Qt 4.7+, QML 1.1
- Self-signed SIS deployment
- See `docs/PLAN.md` for full milestone tracking
- See `docs/DEVICE_NOTES.md` for device experimentation log

## Architecture
- C++ AudioEngine (src/AudioEngine.h/.cpp) wraps QMediaPlayer, exposed to QML via `setContextProperty("audioEngine", &audioEngine)`
- StorageManager handles SQLite with multi-candidate path fallback
- QML uses Symbian Components 1.1

## Critical Symbian Rules
- **NEVER write `position` property on QML Audio element** — causes KErrMMAudioDevice (-12014), bricks ALL audio until phone restart. Use C++ QMediaPlayer::setPosition() instead.
- **Data caging**: `/private/<UID>/` dirs are writable but invisible to `QDir::exists()`. Skip exists/mkpath checks and go straight to I/O test.
- **SQL driver**: Use QSYMSQL (not QSQLITE) on Symbian when available. Test with same driver that production code uses.
- **Path separators**: Use `QDir::toNativeSeparators()` for paths passed to SQL drivers on Symbian.

## QML 1.1 Compatibility Rules
- **No named function declarations inside non-root elements** — `function foo() {}` inside MouseArea/Rectangle/etc causes parse error. Define all functions at the Page/root level.
- **No negative anchor margins** — `anchors.topMargin: -8` may not work. Use a larger Item height for touch targets instead.
- **SVG icon sizing**: ToolButton `iconSource` renders SVGs at their intrinsic size with no way to control it. To use smaller icons, replace ToolButton with a custom Item containing `Image` + `MouseArea`, and set `sourceSize.width`/`sourceSize.height` on the Image to force the render size.
