#include "visuals.h"
#include "media.h"
#include "mpvobject.h"

#include <QPainter>
#include <QPointer>
#include <QGuiApplication>
#include <QPainterPath>
#include <QtMath>
#include <algorithm>
#include <cmath>
#include <vector>

// ---------------------------------------------------------------------------
// WaveformItem
// ---------------------------------------------------------------------------
WaveformItem::WaveformItem(QQuickItem *parent) : QQuickPaintedItem(parent)
{
    setAntialiasing(false);
    connect(Media::instance(), &Media::waveformChanged, this, [this] { emit dataChanged(); update(); });
}

bool WaveformItem::hasData() const { return !Media::instance()->peaks().isEmpty(); }

void WaveformItem::paint(QPainter *p)
{
    const QVector<float> &pk = Media::instance()->peaks();
    const QVector<float> &rms = Media::instance()->rms();
    const int w = int(width()), h = int(height());
    if (pk.isEmpty() || w <= 0 || h <= 0)
        return;
    const double bps = Media::kBinsPerSecond;
    const double start = qMax(0.0, m_start);
    const double end = m_end > start ? m_end : pk.size() / bps;
    const double binsPerPx = (end - start) * bps / w;

    float gain = 1.f;
    if (m_normalize) {
        float mx = 0.f;
        for (float v : pk) mx = qMax(mx, v);
        if (mx > 0.02f) gain = 0.95f / mx;
    }
    const double mid = h / 2.0;
    for (int x = 0; x < w; ++x) {
        const int b0 = int(std::floor((start * bps) + x * binsPerPx));
        const int b1 = qMax(b0 + 1, int(std::floor((start * bps) + (x + 1) * binsPerPx)));
        if (b0 >= pk.size()) break;
        float mp = 0.f, mr = 0.f;
        for (int b = qMax(0, b0); b < qMin(b1, int(pk.size())); ++b) {
            mp = qMax(mp, pk[b]);
            mr = qMax(mr, rms[b]);
        }
        const double ph = qMin(1.f, mp * gain) * mid, rh = qMin(1.f, mr * gain * 1.15f) * mid;
        p->fillRect(QRectF(x, mid - ph, 1, qMax(1.0, ph * 2)), m_peakColor);
        p->fillRect(QRectF(x, mid - rh, 1, qMax(1.0, rh * 2)), m_color);
    }
}

// ---------------------------------------------------------------------------
// ScopeItem
// ---------------------------------------------------------------------------
ScopeItem::ScopeItem(QQuickItem *parent) : QQuickPaintedItem(parent)
{
    m_timer.setInterval(200);
    m_pool.setMaxThreadCount(1);
    connect(&m_timer, &QTimer::timeout, this, &ScopeItem::refresh);
    connect(this, &QQuickItem::widthChanged, this, [this] { m_lastPos = -1; });
}

void ScopeItem::setSource(MpvObject *s)
{
    if (s == m_source) return;
    m_source = s;
    m_lastPos = -1;
    emit sourceChanged();
}

void ScopeItem::setMode(int m)
{
    if (m == m_mode) return;
    m_mode = m;
    if (!m_frame.isNull())
        m_scope = render(m_frame, m_mode, QSize(int(width()), int(height())));
    update();
    emit modeChanged();
}

void ScopeItem::setActive(bool a)
{
    if (a == m_active) return;
    m_active = a;
    m_lastPos = -1;
    if (a) { m_timer.start(); refresh(); } else m_timer.stop();
    emit activeChanged();
}

void ScopeItem::refresh()
{
    if (!m_active || !m_source || !m_source->loaded() || !m_source->hasVideo() || width() < 8 || height() < 8)
        return;
    // Paused on the same frame: nothing new to measure.
    if (m_source->paused() && qAbs(m_source->position() - m_lastPos) < 1e-6)
        return;
    // While playing, twice a second is plenty and keeps playback smooth.
    if (!m_source->paused() && (++m_tick % 3) != 0)
        return;
    if (m_busy) return;
    auto grab = m_source->frameGrabber();
    if (!grab) return;
    m_busy = true;
    m_lastPos = m_source->position();
    const int mode = m_mode;
    const QSize size{ int(width()), int(height()) };
    QPointer<ScopeItem> self(this);
    // Grabbing and measuring a frame is the expensive part: do it off the UI thread.
    m_pool.start([self, grab, mode, size] {
        const QImage f = grab(360);
        const QImage scope = f.isNull() ? QImage() : ScopeItem::render(f, mode, size);
        QMetaObject::invokeMethod(qApp, [self, f, scope, mode] {
            if (!self) return;
            self->m_busy = false;
            if (f.isNull()) return;
            self->m_frame = f;
            self->m_scope = mode == self->m_mode ? scope : ScopeItem::render(f, self->m_mode, QSize(int(self->width()), int(self->height())));
            self->update();
        }, Qt::QueuedConnection);
    });
}

ScopeItem::~ScopeItem()
{
    m_pool.waitForDone();
}

void ScopeItem::paint(QPainter *p)
{
    p->fillRect(boundingRect(), QColor(0x0d0e10));
    if (!m_scope.isNull())
        p->drawImage(boundingRect(), m_scope);
}

QImage ScopeItem::render(const QImage &src, int mode, const QSize &size)
{
    if (src.isNull() || size.isEmpty()) return {};
    const QImage f = src.convertToFormat(QImage::Format_RGB32);
    const int fw = f.width(), fh = f.height();
    QImage out(size, QImage::Format_RGB32);
    out.fill(QColor(0x0d0e10));
    QPainter p(&out);
    p.setRenderHint(QPainter::Antialiasing);
    const QColor grid(255, 255, 255, 26), label(255, 255, 255, 90);
    QFont fnt = p.font();
    fnt.setPixelSize(9);
    p.setFont(fnt);
    const int W = size.width(), H = size.height();

    auto intensity = [](int count, double norm) { return qMin(255, int(std::sqrt(count * norm) * 255)); };

    if (mode == 0 || mode == 1) {
        // Waveform: x follows the picture, y is level (0-100%).
        const int cols = mode == 0 ? fw : fw * 3;
        std::vector<int> grid0(size_t(cols) * 256, 0);
        for (int y = 0; y < fh; ++y) {
            const QRgb *line = reinterpret_cast<const QRgb *>(f.constScanLine(y));
            for (int x = 0; x < fw; ++x) {
                const int r = qRed(line[x]), g = qGreen(line[x]), b = qBlue(line[x]);
                if (mode == 0) {
                    const int Y = qBound(0, int(0.2126 * r + 0.7152 * g + 0.0722 * b + 0.5), 255);
                    ++grid0[size_t(Y) * cols + x];
                } else {
                    ++grid0[size_t(r) * cols + x];
                    ++grid0[size_t(g) * cols + fw + x];
                    ++grid0[size_t(b) * cols + 2 * fw + x];
                }
            }
        }
        QImage img(cols, 256, QImage::Format_RGB32);
        const double norm = 3.0 / qMax(1, fh);
        for (int v = 0; v < 256; ++v) {
            QRgb *line = reinterpret_cast<QRgb *>(img.scanLine(255 - v));
            for (int x = 0; x < cols; ++x) {
                const int c = intensity(grid0[size_t(v) * cols + x], norm);
                if (mode == 0) line[x] = qRgb(c * 7 / 10, c, c * 8 / 10);
                else {
                    const int ch = x / fw;
                    line[x] = qRgb(ch == 0 ? c : c / 5, ch == 1 ? c : c / 5, ch == 2 ? c : c / 5);
                }
            }
        }
        const QRect area(24, 6, W - 30, H - 12);
        p.drawImage(area, img);
        for (int pct = 0; pct <= 100; pct += 25) {
            const double y = area.bottom() - area.height() * pct / 100.0;
            p.setPen(grid);
            p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
            p.setPen(label);
            p.drawText(QRectF(0, y - 6, 21, 12), Qt::AlignRight | Qt::AlignVCenter, QString::number(pct));
        }
        if (mode == 1) {
            p.setPen(grid);
            for (int i = 1; i < 3; ++i) {
                const double x = area.left() + area.width() * i / 3.0;
                p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
            }
        }
    } else if (mode == 2) {
        // Histogram: R, G, B and luma.
        std::vector<int> h[4] = { std::vector<int>(256), std::vector<int>(256), std::vector<int>(256), std::vector<int>(256) };
        for (int y = 0; y < fh; ++y) {
            const QRgb *line = reinterpret_cast<const QRgb *>(f.constScanLine(y));
            for (int x = 0; x < fw; ++x) {
                const int r = qRed(line[x]), g = qGreen(line[x]), b = qBlue(line[x]);
                ++h[0][r]; ++h[1][g]; ++h[2][b];
                ++h[3][qBound(0, int(0.2126 * r + 0.7152 * g + 0.0722 * b + 0.5), 255)];
            }
        }
        int mx = 1;
        for (int c = 0; c < 4; ++c)
            for (int i = 1; i < 255; ++i) mx = qMax(mx, h[c][i]); // ignore clipped ends when scaling
        const QRectF area(6, 6, W - 12, H - 12);
        p.setPen(grid);
        for (int i = 1; i < 4; ++i) {
            const double x = area.left() + area.width() * i / 4.0;
            p.drawLine(QPointF(x, area.top()), QPointF(x, area.bottom()));
        }
        const QColor cols[4] = { QColor(255, 80, 80, 110), QColor(80, 220, 120, 110), QColor(90, 140, 255, 110), QColor(230, 230, 230, 60) };
        p.setCompositionMode(QPainter::CompositionMode_Plus);
        for (int c = 0; c < 4; ++c) {
            QPainterPath path(QPointF(area.left(), area.bottom()));
            for (int i = 0; i < 256; ++i) {
                const double x = area.left() + area.width() * i / 255.0;
                const double v = qMin(1.0, double(h[c][i]) / mx);
                path.lineTo(x, area.bottom() - v * area.height());
            }
            path.lineTo(area.right(), area.bottom());
            path.closeSubpath();
            p.fillPath(path, cols[c]);
        }
        p.setCompositionMode(QPainter::CompositionMode_SourceOver);
    } else {
        // Vectorscope (BT.709 Cb/Cr).
        const int S = 256;
        std::vector<int> g(size_t(S) * S, 0);
        for (int y = 0; y < fh; ++y) {
            const QRgb *line = reinterpret_cast<const QRgb *>(f.constScanLine(y));
            for (int x = 0; x < fw; ++x) {
                const double r = qRed(line[x]), gg = qGreen(line[x]), b = qBlue(line[x]);
                const int cb = qBound(0, int(128 + (-0.1146 * r - 0.3854 * gg + 0.5 * b)), 255);
                const int cr = qBound(0, int(128 + (0.5 * r - 0.4542 * gg - 0.0458 * b)), 255);
                ++g[size_t(255 - cr) * S + cb];
            }
        }
        QImage img(S, S, QImage::Format_RGB32);
        const double norm = 40.0 / qMax(1, fw * fh / 64);
        for (int y = 0; y < S; ++y) {
            QRgb *line = reinterpret_cast<QRgb *>(img.scanLine(y));
            for (int x = 0; x < S; ++x) {
                const int c = intensity(g[size_t(y) * S + x], norm);
                line[x] = qRgb(c * 8 / 10, c, c * 8 / 10);
            }
        }
        const int side = qMin(W, H) - 12;
        const QRectF area((W - side) / 2.0, (H - side) / 2.0, side, side);
        p.drawImage(area, img);
        p.setPen(grid);
        p.drawEllipse(area);
        p.drawEllipse(area.adjusted(side * 0.25, side * 0.25, -side * 0.25, -side * 0.25));
        p.drawLine(QPointF(area.center().x(), area.top()), QPointF(area.center().x(), area.bottom()));
        p.drawLine(QPointF(area.left(), area.center().y()), QPointF(area.right(), area.center().y()));
        // Skin tone line, about 123 degrees from the +Cb axis.
        p.setPen(QColor(255, 180, 120, 70));
        const double a = qDegreesToRadians(123.0);
        p.drawLine(area.center(), area.center() + QPointF(std::cos(a) * side / 2, -std::sin(a) * side / 2));
    }
    return out;
}
