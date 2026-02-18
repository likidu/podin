Symbian Belle Device Notes
==========================

Hardware: Nokia C7 (Belle FP2)

## 2026-02-17 — Audio Seeking — KErrMMAudioDevice (-12014)

### Problem
Forward/back (skip) buttons do nothing on the device. The root cause is that
QtMultimediaKit 1.1's `Audio` QML element has **no `seek()` method**. The
Qt Mobility 1.1 docs confirm that seeking is done by writing the `position`
property directly (`audio.position = newMs`).

The current code calls `_impl.seek(positionMs)` which silently does nothing
because the guard `if (_impl && _impl.seek)` evaluates to false — `_impl.seek`
is `undefined`.

### Failed Attempt: Writing `_impl.position` from QML
Replacing `_impl.seek(positionMs)` with `_impl.position = positionMs` causes
**KErrMMAudioDevice (-12014)**: "Cannot open audio device, or lost control of
audio device."

This happens because writing `position` on the Symbian MMF backend during
media status transitions (loading, buffering, loaded) causes the backend to
lose control of the audio device entirely. The error persists even with guards
that only write position during `playingState` or `pausedState`. The device
requires a full restart to recover from this error.

Key observations:
- The error code -12014 is a Symbian MMF error, not a Qt error.
- Once triggered, the audio device stays broken until phone restart.
- Even guarding the position write to only `playingState`/`pausedState` did
  not prevent the error — suggesting the QML property binding mechanism itself
  may trigger writes at unexpected times, or the MMF state machine transitions
  are not fully reflected in the QML-visible `state` property.
- The `onStatusChanged` handler in PlaybackController calls `audio.seek()`
  during status transitions for resume-position — when seek was a no-op this
  was harmless, but with a real position write it became destructive.

### Why a phone restart is required after the error
KErrMMAudioDevice (-12014) corrupts the Symbian MMF audio device state at the
OS level. MMF is a shared system service — once the audio device handle is
invalidated, no app can reclaim it. Symbian has no graceful recovery path;
the MMF service only reinitializes on boot. This means any bad audio API call
bricks ALL audio on the phone until restart.

### Resolution: C++ AudioEngine (src/AudioEngine.h/.cpp)
Replaced the QML AudioFacade with a C++ class wrapping QMediaPlayer directly.
Seeking uses `QMediaPlayer::setPosition()` from C++ with state guards:
- Only seeks when player state is PlayingState or PausedState (audio device acquired)
- Defers seek to m_pendingSeek if not ready, applied on state transition
- This avoids the KErrMMAudioDevice crash entirely
- Forward/back buttons now work correctly on device

### References
- Qt Mobility 1.1 Audio docs: https://qt.developpez.com/doc/qtmobility-1.1/qml-audio
  (position is read-write, no seek() method exists)
- Symbian error codes: KErrMMAudioDevice = -12014
  (https://www.cnblogs.com/jason-jiang/archive/2006/11/01/547041.html)
