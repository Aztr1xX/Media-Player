#include "folderqueue.h"
#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <algorithm>

namespace FolderQueue {

static const QSet<QString> &extensions()
{
    static const QSet<QString> ext = {
        // video
        "mp4", "m4v", "mov", "mkv", "webm", "avi", "wmv", "flv", "mpg", "mpeg", "m2ts", "mts", "ts",
        "3gp", "ogv", "mxf", "vob", "divx", "rm", "rmvb", "asf", "f4v", "hevc", "264", "265",
        // audio
        "mp3", "wav", "flac", "aac", "m4a", "ogg", "opus", "wma", "aiff", "aif", "alac", "ape", "wv", "mka", "ac3", "dts"
    };
    return ext;
}

bool isMediaFile(const QString &path)
{
    return extensions().contains(QFileInfo(path).suffix().toLower());
}

// Own natural compare (digits by value) so behaviour is identical on every platform;
// QCollator's numeric mode depends on how Qt was built.
static int naturalCompare(const QString &a, const QString &b)
{
    int i = 0, j = 0;
    while (i < a.size() && j < b.size()) {
        if (a[i].isDigit() && b[j].isDigit()) {
            int si = i, sj = j;
            while (si < a.size() && a[si] == QLatin1Char('0')) ++si;  // skip leading zeros
            while (sj < b.size() && b[sj] == QLatin1Char('0')) ++sj;
            int ei = si, ej = sj;
            while (ei < a.size() && a[ei].isDigit()) ++ei;
            while (ej < b.size() && b[ej].isDigit()) ++ej;
            const int li = ei - si, lj = ej - sj;
            if (li != lj) return li < lj ? -1 : 1;                  // more digits = bigger number
            const int c = QStringView(a).mid(si, li).compare(QStringView(b).mid(sj, lj));
            if (c != 0) return c;
            i = ei; j = ej;
        } else {
            const int c = QString(a[i]).compare(QString(b[j]), Qt::CaseInsensitive);
            if (c != 0) return c;
            ++i; ++j;
        }
    }
    return (a.size() - i) - (b.size() - j);
}

QStringList naturalSorted(QStringList names)
{
    std::sort(names.begin(), names.end(), [](const QString &a, const QString &b) {
        const int r = naturalCompare(a, b);
        return r != 0 ? r < 0 : a < b; // deterministic tiebreak
    });
    return names;
}

QStringList mediaFilesIn(const QString &folder)
{
    QDir dir(folder);
    QStringList names;
    const QStringList all = dir.entryList(QDir::Files | QDir::Readable);
    for (const QString &n : all)
        if (isMediaFile(n))
            names << n;
    QStringList out;
    for (const QString &n : naturalSorted(names))
        out << dir.absoluteFilePath(n);
    return out;
}

}
