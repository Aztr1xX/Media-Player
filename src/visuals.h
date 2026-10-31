#pragma once
#include <QColor>
#include <QImage>
#include <QPointer>
#include <QQuickPaintedItem>
#include <QTimer>
#include <QtQml/qqml.h>

class MpvObject;

// Draws the current file's audio waveform (from Media) for a time window.
// Peaks are drawn light, RMS strong, mirrored around the centre line.
class WaveformItem : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(double viewStart READ viewStart WRITE setViewStart NOTIFY viewChanged)
    Q_PROPERTY(double viewEnd READ viewEnd WRITE setViewEnd NOTIFY viewChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY styleChanged)
    Q_PROPERTY(QColor peakColor READ peakColor WRITE setPeakColor NOTIFY styleChanged)
    Q_PROPERTY(bool normalize READ normalize WRITE setNormalize NOTIFY styleChanged)
    Q_PROPERTY(bool hasData READ hasData NOTIFY dataChanged)

public:
    explicit WaveformItem(QQuickItem *parent = nullptr);
    void paint(QPainter *p) override;

    double viewStart() const { return m_start; }
    double viewEnd() const { return m_end; }
    QColor color() const { return m_color; }
    QColor peakColor() const { return m_peakColor; }
    bool normalize() const { return m_normalize; }
    bool hasData() const;
    void setViewStart(double v) { if (v != m_start) { m_start = v; emit viewChanged(); update(); } }
    void setViewEnd(double v) { if (v != m_end) { m_end = v; emit viewChanged(); update(); } }
    void setColor(const QColor &c) { m_color = c; emit styleChanged(); update(); }
    void setPeakColor(const QColor &c) { m_peakColor = c; emit styleChanged(); update(); }
    void setNormalize(bool n) { m_normalize = n; emit styleChanged(); update(); }

signals:
    void viewChanged();
    void styleChanged();
    void dataChanged();

private:
    double m_start = 0, m_end = 0;
    QColor m_color = QColor(0x9aa3b2), m_peakColor = QColor(0x4a505a);
    bool m_normalize = true;
};

// Video scopes computed from a downscaled copy of the current frame:
// 0 luma waveform, 1 RGB parade, 2 histogram, 3 vectorscope.
class ScopeItem : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(MpvObject *source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(int mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)

public:
    explicit ScopeItem(QQuickItem *parent = nullptr);
    void paint(QPainter *p) override;

    MpvObject *source() const { return m_source; }
    int mode() const { return m_mode; }
    bool active() const { return m_active; }
    void setSource(MpvObject *s);
    void setMode(int m);
    void setActive(bool a);

    // Exposed for tests.
    static QImage render(const QImage &frame, int mode, const QSize &size);

signals:
    void sourceChanged();
    void modeChanged();
    void activeChanged();

private:
    void refresh();

    QPointer<MpvObject> m_source;
    int m_mode = 0;
    bool m_active = false;
    QTimer m_timer;
    QImage m_frame, m_scope;
    double m_lastPos = -1;
};
