#include "folderqueue.h"
#include "markermodel.h"
#include "timecode.h"

#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

class TestCore : public QObject
{
    Q_OBJECT
private slots:
    void timecodeBasics()
    {
        QCOMPARE(Timecode::fromFrame(0, 30), QStringLiteral("00:00:00:00"));
        QCOMPARE(Timecode::fromFrame(29, 30), QStringLiteral("00:00:00:29"));
        QCOMPARE(Timecode::fromFrame(30, 30), QStringLiteral("00:00:01:00"));
        QCOMPARE(Timecode::fromFrame(30 * 3661 + 5, 30), QStringLiteral("01:01:01:05"));
        QCOMPARE(Timecode::fromFrame(0, 25, 25 * 3600), QStringLiteral("01:00:00:00"));
    }
    void timecodeNominalRates()
    {
        QCOMPARE(Timecode::nominalFps(29.97), 30);
        QCOMPARE(Timecode::nominalFps(23.976), 24);
        QCOMPARE(Timecode::nominalFps(59.94), 60);
        QCOMPARE(Timecode::nominalFps(0), 30);
        QCOMPARE(Timecode::nominalFps(qQNaN()), 30);
    }
    void frameAtEdges()
    {
        QCOMPARE(Timecode::frameAt(1.0, 30), qint64(30));      // no off-by-one from float error
        QCOMPARE(Timecode::frameAt(1.0 / 30 * 7, 30), qint64(7));
        QCOMPARE(Timecode::frameAt(-1, 30), qint64(0));
        QCOMPARE(Timecode::fromSeconds(2.5, 24), QStringLiteral("00:00:02:12"));
    }
    void parseRoundTrip()
    {
        for (qint64 f : { 0LL, 1LL, 29LL, 30LL, 107999LL }) {
            QCOMPARE(Timecode::parse(Timecode::fromFrame(f, 30), 30), f);
        }
        QCOMPARE(Timecode::parse(QStringLiteral("00:00:00:30"), 30), qint64(-1));
        QCOMPARE(Timecode::parse(QStringLiteral("bad"), 30), qint64(-1));
    }
    void clockFormat()
    {
        QCOMPARE(Timecode::clock(0), QStringLiteral("0:00"));
        QCOMPARE(Timecode::clock(75.9), QStringLiteral("1:15"));
        QCOMPARE(Timecode::clock(3725), QStringLiteral("1:02:05"));
    }
    void naturalSort()
    {
        const QStringList in{ "part 10.mp4", "part 2.mp4", "Part 1.mp4", "clip_003.mov", "clip_01.mov" };
        const QStringList out = FolderQueue::naturalSorted(in);
        QCOMPARE(out, (QStringList{ "clip_01.mov", "clip_003.mov", "Part 1.mp4", "part 2.mp4", "part 10.mp4" }));
        QVERIFY(FolderQueue::isMediaFile("A.MKV"));
        QVERIFY(!FolderQueue::isMediaFile("notes.txt"));
    }
    void markerSortingAndPersistence()
    {
        QTemporaryDir dir;
        MarkerModel m;
        m.setStorageDir(dir.path());
        m.loadFor(dir.path() + "/clip.mp4");
        QSignalSpy spy(&m, &MarkerModel::countChanged);
        m.add(20, MarkerModel::Good, "b");
        m.add(5, MarkerModel::Note, "a");
        m.add(30, MarkerModel::Mistake, "c");
        QCOMPARE(m.count(), 3);
        QCOMPARE(spy.count(), 3);
        QCOMPARE(m.timeAt(0), 5.0);
        QCOMPARE(m.timeAt(2), 30.0);
        QCOMPARE(m.nextAfter(5), 20.0);
        QCOMPARE(m.prevBefore(20), 5.0);
        QCOMPARE(m.nextAfter(30), -1.0);
        m.setNote(1, "  edited  ");
        m.cycleKind(0);

        MarkerModel m2;
        m2.setStorageDir(dir.path());
        m2.loadFor(dir.path() + "/clip.mp4");
        QCOMPARE(m2.count(), 3);
        QCOMPARE(m2.items()[1].note, QStringLiteral("edited"));
        QCOMPARE(m2.items()[0].kind, int(MarkerModel::Good));
        m2.remove(0); m2.remove(0); m2.remove(0);
        QVERIFY(!QFile::exists(m2.storageFileFor(dir.path() + "/clip.mp4"))); // empty list removes the file
    }
    void edlExport()
    {
        QVector<MarkerModel::Marker> items{ { 1, 12.0, "Good | take", 1 }, { 2, 27.5, "Line\nbreak", 0 } };
        const QString edl = MarkerModel::toEdl(items, 30, "clip.mp4", 30 * 3600);
        QVERIFY(edl.startsWith("TITLE: clip.mp4\nFCM: NON-DROP FRAME\n\n"));
        QVERIFY(edl.contains("001  001      V     C        01:00:12:00 01:00:12:01 01:00:12:00 01:00:12:01"));
        QVERIFY(edl.contains(" |C:ResolveColorGreen |M:Good / take |D:1"));
        QVERIFY(edl.contains("002  001      V     C        01:00:27:15"));
        QVERIFY(edl.contains("|M:Line break |D:1"));
    }
    void csvExport()
    {
        QVector<MarkerModel::Marker> items{ { 1, 1.5, "Say \"hi\", then go", 2 } };
        const QString csv = MarkerModel::toCsv(items, 25);
        QCOMPARE(csv, QStringLiteral("timecode,seconds,kind,note\n00:00:01:12,1.500,mistake,\"Say \"\"hi\"\", then go\"\n"));
    }
    void youtubeChapters()
    {
        using M = MarkerModel::Marker;
        // too few
        auto c = MarkerModel::toYouTubeChapters({ M{ 1, 30, "Only one", 0 } }, 300);
        QVERIFY(!c.error.isEmpty());
        // valid: adds 0:00 Intro, skips one under 10 s apart and one in the last 10 s
        c = MarkerModel::toYouTubeChapters({ M{ 1, 15, "Setup", 0 }, M{ 2, 20, "Too close", 0 }, M{ 3, 75, "Desk tour", 0 }, M{ 4, 295, "End", 0 } }, 300);
        QVERIFY(c.error.isEmpty());
        QCOMPARE(c.text, QStringLiteral("0:00 Intro\n0:15 Setup\n1:15 Desk tour"));
        QCOMPARE(c.skipped, 2);
        // a marker at the very start names the first chapter
        c = MarkerModel::toYouTubeChapters({ M{ 1, 0, "Cold open", 0 }, M{ 2, 12, "A", 0 }, M{ 3, 40, "B", 0 } }, 100);
        QCOMPARE(c.text.section('\n', 0, 0), QStringLiteral("0:00 Cold open"));
        QCOMPARE(c.count, 3);
    }
};

QTEST_GUILESS_MAIN(TestCore)
#include "tst_core.moc"
