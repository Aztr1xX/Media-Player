#include "timecode.h"
#include <QStringList>
#include <cmath>

namespace Timecode {

int nominalFps(double fps)
{
    if (!(fps > 0) || !std::isfinite(fps))
        return 30;
    return qMax(1, int(std::lround(fps)));
}

qint64 frameAt(double seconds, double fps)
{
    if (!(fps > 0) || !std::isfinite(seconds) || seconds < 0)
        return 0;
    // Small epsilon so 1.0/30*30 lands on frame 30, not 29.
    return qint64(std::floor(seconds * fps + 1e-6));
}

double secondsAt(qint64 frame, double fps)
{
    if (!(fps > 0) || frame < 0)
        return 0.0;
    return double(frame) / fps;
}

QString fromFrame(qint64 frame, double fps, qint64 offsetFrames)
{
    const int n = nominalFps(fps);
    qint64 f = qMax<qint64>(0, frame) + qMax<qint64>(0, offsetFrames);
    const qint64 ff = f % n;
    qint64 totalSec = f / n;
    const qint64 ss = totalSec % 60;
    const qint64 mm = (totalSec / 60) % 60;
    const qint64 hh = totalSec / 3600;
    return QStringLiteral("%1:%2:%3:%4")
        .arg(hh, 2, 10, QLatin1Char('0'))
        .arg(mm, 2, 10, QLatin1Char('0'))
        .arg(ss, 2, 10, QLatin1Char('0'))
        .arg(ff, 2, 10, QLatin1Char('0'));
}

QString fromSeconds(double seconds, double fps, qint64 offsetFrames)
{
    // Timecode counts nominal frames, so convert through the nominal rate.
    return fromFrame(frameAt(seconds, nominalFps(fps)), fps, offsetFrames);
}

QString clock(double seconds)
{
    if (!std::isfinite(seconds) || seconds < 0)
        seconds = 0;
    const qint64 s = qint64(std::floor(seconds));
    const qint64 h = s / 3600, m = (s / 60) % 60, sec = s % 60;
    if (h > 0)
        return QStringLiteral("%1:%2:%3").arg(h).arg(m, 2, 10, QLatin1Char('0')).arg(sec, 2, 10, QLatin1Char('0'));
    return QStringLiteral("%1:%2").arg(m).arg(sec, 2, 10, QLatin1Char('0'));
}

qint64 parse(const QString &tc, double fps)
{
    const QStringList p = tc.trimmed().split(QLatin1Char(':'));
    if (p.size() != 4)
        return -1;
    bool ok[4];
    const qint64 h = p[0].toLongLong(&ok[0]), m = p[1].toLongLong(&ok[1]),
                 s = p[2].toLongLong(&ok[2]), f = p[3].toLongLong(&ok[3]);
    const int n = nominalFps(fps);
    if (!(ok[0] && ok[1] && ok[2] && ok[3]) || m > 59 || s > 59 || f >= n || h < 0 || m < 0 || s < 0 || f < 0)
        return -1;
    return ((h * 60 + m) * 60 + s) * n + f;
}

}
