#pragma once
#include <QString>

// Time and timecode helpers. All functions are pure so they can be unit tested.
namespace Timecode {

// Nominal integer frame rate used for timecode (29.97 -> 30, 23.976 -> 24, 59.94 -> 60).
int nominalFps(double fps);

// Frame index nearest to a time in seconds.
qint64 frameAt(double seconds, double fps);

// Seconds for the start of a frame.
double secondsAt(qint64 frame, double fps);

// SMPTE-style non-drop timecode "HH:MM:SS:FF". offsetFrames lets exports start at e.g. 01:00:00:00.
QString fromFrame(qint64 frame, double fps, qint64 offsetFrames = 0);
QString fromSeconds(double seconds, double fps, qint64 offsetFrames = 0);

// "M:SS" or "H:MM:SS", as YouTube chapters and general UI use.
QString clock(double seconds);

// Parse "HH:MM:SS:FF" back to a frame count; returns -1 on bad input.
qint64 parse(const QString &tc, double fps);

}
