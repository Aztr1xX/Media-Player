#include "markermodel.h"
#include "timecode.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <algorithm>
#include <cmath>

MarkerModel::MarkerModel(QObject *parent) : QAbstractListModel(parent) {}

int MarkerModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant MarkerModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};
    const Marker &m = m_items.at(index.row());
    switch (role) {
    case TimeRole: return m.time;
    case NoteRole: case Qt::DisplayRole: return m.note;
    case KindRole: return m.kind;
    case IdRole: return m.id;
    }
    return {};
}

QHash<int, QByteArray> MarkerModel::roleNames() const
{
    return { { TimeRole, "time" }, { NoteRole, "note" }, { KindRole, "kind" }, { IdRole, "markerId" } };
}

int MarkerModel::add(double time, int kind, const QString &note)
{
    if (!std::isfinite(time) || time < 0)
        time = 0;
    Marker m;
    m.id = m_nextId++;
    m.time = time;
    m.kind = qBound(0, kind, 2);
    m.note = note.isEmpty() ? QStringLiteral("Marker") : note;
    // Insert in sorted position so rows stay stable for the view.
    int row = int(std::upper_bound(m_items.begin(), m_items.end(), time,
                                   [](double t, const Marker &x) { return t < x.time; }) - m_items.begin());
    beginInsertRows({}, row, row);
    m_items.insert(row, m);
    endInsertRows();
    emit countChanged();
    save();
    return row;
}

void MarkerModel::remove(int row)
{
    if (row < 0 || row >= m_items.size())
        return;
    beginRemoveRows({}, row, row);
    m_items.removeAt(row);
    endRemoveRows();
    emit countChanged();
    save();
}

void MarkerModel::setNote(int row, const QString &note)
{
    if (row < 0 || row >= m_items.size())
        return;
    const QString t = note.trimmed();
    if (t.isEmpty() || t == m_items[row].note)
        return;
    m_items[row].note = t;
    emit dataChanged(index(row), index(row), { NoteRole });
    save();
}

void MarkerModel::cycleKind(int row)
{
    if (row < 0 || row >= m_items.size())
        return;
    m_items[row].kind = (m_items[row].kind + 1) % 3;
    emit dataChanged(index(row), index(row), { KindRole });
    save();
}

double MarkerModel::timeAt(int row) const
{
    return (row >= 0 && row < m_items.size()) ? m_items.at(row).time : -1;
}

int MarkerModel::rowNear(double time, double tolerance) const
{
    for (int i = 0; i < m_items.size(); ++i)
        if (std::fabs(m_items[i].time - time) <= tolerance)
            return i;
    return -1;
}

double MarkerModel::nextAfter(double time) const
{
    for (const Marker &m : m_items)
        if (m.time > time + 1e-3)
            return m.time;
    return -1;
}

double MarkerModel::prevBefore(double time) const
{
    for (int i = m_items.size() - 1; i >= 0; --i)
        if (m_items[i].time < time - 1e-3)
            return m_items[i].time;
    return -1;
}

void MarkerModel::clear()
{
    beginResetModel();
    m_items.clear();
    endResetModel();
    emit countChanged();
}

void MarkerModel::sortAndReset()
{
    beginResetModel();
    std::stable_sort(m_items.begin(), m_items.end(), [](const Marker &a, const Marker &b) { return a.time < b.time; });
    endResetModel();
    emit countChanged();
}

QString MarkerModel::storageFileFor(const QString &mediaPath) const
{
    QString dir = m_storageDir.isEmpty()
        ? QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/markers")
        : m_storageDir;
    const QByteArray key = QCryptographicHash::hash(QFileInfo(mediaPath).absoluteFilePath().toUtf8(), QCryptographicHash::Sha1).toHex();
    return dir + QLatin1Char('/') + QString::fromLatin1(key.left(20)) + QStringLiteral(".json");
}

void MarkerModel::loadFor(const QString &mediaPath)
{
    m_mediaPath = mediaPath;
    beginResetModel();
    m_items.clear();
    m_nextId = 1;
    QFile f(storageFileFor(mediaPath));
    if (!mediaPath.isEmpty() && f.open(QIODevice::ReadOnly)) {
        const QJsonArray arr = QJsonDocument::fromJson(f.readAll()).object().value(QStringLiteral("markers")).toArray();
        for (const QJsonValue &v : arr) {
            const QJsonObject o = v.toObject();
            Marker m;
            m.id = m_nextId++;
            m.time = o.value(QStringLiteral("time")).toDouble();
            m.note = o.value(QStringLiteral("note")).toString(QStringLiteral("Marker"));
            m.kind = qBound(0, o.value(QStringLiteral("kind")).toInt(), 2);
            m_items.push_back(m);
        }
    }
    endResetModel();
    sortAndReset();
}

bool MarkerModel::save() const
{
    if (m_mediaPath.isEmpty())
        return false;
    const QString file = storageFileFor(m_mediaPath);
    QDir().mkpath(QFileInfo(file).absolutePath());
    if (m_items.isEmpty()) {
        QFile::remove(file);
        return true;
    }
    QJsonArray arr;
    for (const Marker &m : m_items)
        arr.append(QJsonObject{ { "time", m.time }, { "note", m.note }, { "kind", m.kind } });
    QJsonObject root{ { "media", QFileInfo(m_mediaPath).absoluteFilePath() }, { "markers", arr } };
    QSaveFile f(file); // atomic write: never leaves a half-written file
    if (!f.open(QIODevice::WriteOnly))
        return false;
    f.write(QJsonDocument(root).toJson());
    return f.commit();
}

static QString cleanNote(QString s)
{
    s.replace(QLatin1Char('|'), QLatin1Char('/'));
    s.replace(QLatin1Char('\n'), QLatin1Char(' '));
    s.replace(QLatin1Char('\r'), QLatin1Char(' '));
    return s.trimmed();
}

QString MarkerModel::toEdl(const QVector<Marker> &items, double fps, const QString &title, qint64 startOffsetFrames)
{
    // CMX3600-style marker EDL in the layout DaVinci Resolve writes and reads
    // (Timelines > Import > Timeline Markers from EDL).
    static const char *colours[] = { "ResolveColorBlue", "ResolveColorGreen", "ResolveColorRed" };
    QString out;
    out += QStringLiteral("TITLE: %1\nFCM: NON-DROP FRAME\n\n").arg(cleanNote(title));
    int n = 1;
    for (const Marker &m : items) {
        const qint64 f = Timecode::frameAt(m.time, Timecode::nominalFps(fps));
        const QString in = Timecode::fromFrame(f, fps, startOffsetFrames);
        const QString outTc = Timecode::fromFrame(f + 1, fps, startOffsetFrames);
        out += QStringLiteral("%1  001      V     C        %2 %3 %2 %3  \n")
                   .arg(n++, 3, 10, QLatin1Char('0')).arg(in, outTc);
        out += QStringLiteral(" |C:%1 |M:%2 |D:1\n\n").arg(QLatin1String(colours[qBound(0, m.kind, 2)]), cleanNote(m.note));
    }
    return out;
}

QString MarkerModel::toCsv(const QVector<Marker> &items, double fps)
{
    static const char *kinds[] = { "note", "good", "mistake" };
    auto q = [](QString s) { s.replace(QLatin1Char('"'), QStringLiteral("\"\"")); return QLatin1Char('"') + s + QLatin1Char('"'); };
    QString out = QStringLiteral("timecode,seconds,kind,note\n");
    for (const Marker &m : items)
        out += QStringLiteral("%1,%2,%3,%4\n").arg(Timecode::fromSeconds(m.time, fps), QString::number(m.time, 'f', 3),
                                                   QLatin1String(kinds[qBound(0, m.kind, 2)]), q(m.note));
    return out;
}

MarkerModel::Chapters MarkerModel::toYouTubeChapters(const QVector<Marker> &items, double duration)
{
    // YouTube rules: first timestamp 0:00, at least three, each chapter at least 10 seconds.
    Chapters c;
    struct Ch { double t; QString title; };
    QVector<Ch> out;
    QString firstTitle = QStringLiteral("Intro");
    for (const Marker &m : items)
        if (m.time < 1.0) { firstTitle = cleanNote(m.note); break; }
    out.push_back({ 0.0, firstTitle });
    for (const Marker &m : items) {
        if (m.time < 1.0)
            continue;
        const bool longEnoughBefore = m.time - out.last().t >= 10.0;
        const bool longEnoughAfter = duration <= 0 || duration - m.time >= 10.0;
        if (longEnoughBefore && longEnoughAfter)
            out.push_back({ m.time, cleanNote(m.note) });
        else
            ++c.skipped;
    }
    c.count = out.size();
    if (c.count < 3) {
        c.error = QStringLiteral("YouTube needs at least 3 chapters, each 10 seconds or longer. Add more markers.");
        return c;
    }
    QStringList lines;
    for (const Ch &ch : out)
        lines << Timecode::clock(ch.t) + QLatin1Char(' ') + ch.title;
    c.text = lines.join(QLatin1Char('\n'));
    return c;
}
