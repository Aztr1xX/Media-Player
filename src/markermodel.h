#pragma once
#include <QAbstractListModel>
#include <QString>
#include <QVector>

// Markers for the open file: time, note and kind (note / good slate / mistake).
// Kept sorted by time. Saved as JSON per media file in the app data folder.
class MarkerModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Kind { Note = 0, Good = 1, Mistake = 2 };
    Q_ENUM(Kind)
    enum Roles { TimeRole = Qt::UserRole + 1, NoteRole, KindRole, IdRole };

    struct Marker {
        int id = 0;
        double time = 0;
        QString note;
        int kind = Note;
    };

    explicit MarkerModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int count() const { return m_items.size(); }

    Q_INVOKABLE int add(double time, int kind = Note, const QString &note = QString());
    Q_INVOKABLE void remove(int row);
    Q_INVOKABLE void setNote(int row, const QString &note);
    Q_INVOKABLE void cycleKind(int row);
    Q_INVOKABLE double timeAt(int row) const;
    Q_INVOKABLE int rowNear(double time, double tolerance) const;
    // Time of the next / previous marker, or -1 when there is none.
    Q_INVOKABLE double nextAfter(double time) const;
    Q_INVOKABLE double prevBefore(double time) const;
    void clear();

    const QVector<Marker> &items() const { return m_items; }

    // Persistence. storageDir empty = standard app data location.
    void setStorageDir(const QString &dir) { m_storageDir = dir; }
    void loadFor(const QString &mediaPath);
    bool save() const;
    QString storageFileFor(const QString &mediaPath) const;

    // Exports (pure, testable).
    static QString toEdl(const QVector<Marker> &items, double fps, const QString &title, qint64 startOffsetFrames);
    static QString toCsv(const QVector<Marker> &items, double fps);
    struct Chapters { QString text; int count = 0; int skipped = 0; QString error; };
    static Chapters toYouTubeChapters(const QVector<Marker> &items, double duration);

signals:
    void countChanged();

private:
    void sortAndReset();
    QVector<Marker> m_items;
    QString m_mediaPath;
    QString m_storageDir;
    int m_nextId = 1;
};
