#include "icons.h"

#include <QHash>
#include <QPainter>
#include <QSvgRenderer>

namespace {
// Stroke icons on a 24 x 24 grid. "F:" marks shapes that are filled instead of stroked.
const QHash<QString, QString> &icons()
{
    static const QHash<QString, QString> m = {
        { QStringLiteral("play"), QStringLiteral("F:<path d='M6.9 5.2v13.6c0 .8.9 1.3 1.6.8l10.4-6.8c.6-.4.6-1.2 0-1.6L8.5 4.4C7.8 3.9 6.9 4.4 6.9 5.2z'/>") },
        { QStringLiteral("pause"), QStringLiteral("F:<rect x='6.5' y='5' width='3.8' height='14' rx='1'/><rect x='13.7' y='5' width='3.8' height='14' rx='1'/>") },
        { QStringLiteral("frame-back"), QStringLiteral("<path d='M6 6v12'/><path d='M18 6.5v11a.5.5 0 0 1-.8.4l-7.4-5.5a.5.5 0 0 1 0-.8l7.4-5.5a.5.5 0 0 1 .8.4z'/>") },
        { QStringLiteral("frame-fwd"), QStringLiteral("<path d='M18 6v12'/><path d='M6 6.5v11a.5.5 0 0 0 .8.4l7.4-5.5a.5.5 0 0 0 0-.8L6.8 6.1a.5.5 0 0 0-.8.4z'/>") },
        { QStringLiteral("prev"), QStringLiteral("<path d='M5 5v14'/><path d='M19 6.5v11l-9-5.5z'/>") },
        { QStringLiteral("next"), QStringLiteral("<path d='M19 5v14'/><path d='M5 6.5v11l9-5.5z'/>") },
        { QStringLiteral("loop"), QStringLiteral("<path d='M17 2.5l3 3-3 3'/><path d='M4 11.5V10a4.5 4.5 0 0 1 4.5-4.5H20'/><path d='M7 21.5l-3-3 3-3'/><path d='M20 12.5V14a4.5 4.5 0 0 1-4.5 4.5H4'/>") },
        { QStringLiteral("in"), QStringLiteral("<path d='M10 4H6v16h4'/><path d='M14 12h6'/><path d='M17 9l3 3-3 3'/>") },
        { QStringLiteral("out"), QStringLiteral("<path d='M14 4h4v16h-4'/><path d='M4 12h6'/><path d='M7 9l3 3-3 3'/>") },
        { QStringLiteral("marker"), QStringLiteral("<path d='M6 21V4.5'/><path d='M6 4.5h10.5l-2.5 4 2.5 4H6'/>") },
        { QStringLiteral("volume"), QStringLiteral("<path d='M4 9.5v5h3.5L12 19V5L7.5 9.5z'/><path d='M15.5 9a4 4 0 0 1 0 6'/><path d='M18 6.5a7.5 7.5 0 0 1 0 11'/>") },
        { QStringLiteral("volume-low"), QStringLiteral("<path d='M4 9.5v5h3.5L12 19V5L7.5 9.5z'/><path d='M15.5 9a4 4 0 0 1 0 6'/>") },
        { QStringLiteral("mute"), QStringLiteral("<path d='M4 9.5v5h3.5L12 19V5L7.5 9.5z'/><path d='M16 9.5l5 5'/><path d='M21 9.5l-5 5'/>") },
        { QStringLiteral("fullscreen"), QStringLiteral("<path d='M4 9V4h5'/><path d='M20 9V4h-5'/><path d='M4 15v5h5'/><path d='M20 15v5h-5'/>") },
        { QStringLiteral("fullscreen-exit"), QStringLiteral("<path d='M9 4v5H4'/><path d='M15 4v5h5'/><path d='M9 20v-5H4'/><path d='M15 20v-5h5'/>") },
        { QStringLiteral("sidebar"), QStringLiteral("<rect x='3' y='4.5' width='18' height='15' rx='2'/><path d='M15 4.5v15'/>") },
        { QStringLiteral("search"), QStringLiteral("<circle cx='11' cy='11' r='6.5'/><path d='M20 20l-4.2-4.2'/>") },
        { QStringLiteral("settings"), QStringLiteral("<path d='M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z'/><circle cx='12' cy='12' r='3'/>") },
        { QStringLiteral("open"), QStringLiteral("<path d='M3.5 18.5V6a1.5 1.5 0 0 1 1.5-1.5h4l2 2h6.5A1.5 1.5 0 0 1 19 8v2'/><path d='M3.5 18.5l2.6-7a1.5 1.5 0 0 1 1.4-1h12.8a1 1 0 0 1 .9 1.4l-2.6 6.6H3.5z'/>") },
        { QStringLiteral("file"), QStringLiteral("<path d='M14 3.5H7A1.5 1.5 0 0 0 5.5 5v14A1.5 1.5 0 0 0 7 20.5h10a1.5 1.5 0 0 0 1.5-1.5V8z'/><path d='M14 3.5V8h4.5'/>") },
        { QStringLiteral("film"), QStringLiteral("<rect x='3.5' y='4.5' width='17' height='15' rx='2'/><path d='M7.5 4.5v15M16.5 4.5v15M3.5 9.5h4M3.5 14.5h4M16.5 9.5h4M16.5 14.5h4'/>") },
        { QStringLiteral("music"), QStringLiteral("<path d='M9 18V5.5l11-2V16'/><circle cx='6.5' cy='18' r='2.5'/><circle cx='17.5' cy='16' r='2.5'/>") },
        { QStringLiteral("close"), QStringLiteral("<path d='M6 6l12 12M18 6L6 18'/>") },
        { QStringLiteral("more"), QStringLiteral("F:<circle cx='5.5' cy='12' r='1.6'/><circle cx='12' cy='12' r='1.6'/><circle cx='18.5' cy='12' r='1.6'/>") },
        { QStringLiteral("subtitles"), QStringLiteral("<rect x='3' y='5' width='18' height='14' rx='2'/><path d='M7 12h3M13 12h4M7 15.5h6M15.5 15.5H17'/>") },
        { QStringLiteral("audio-track"), QStringLiteral("<path d='M4 10v4M8 7v10M12 4v16M16 8v8M20 10.5v3'/>") },
        { QStringLiteral("scissors"), QStringLiteral("<circle cx='6' cy='6.5' r='2.5'/><circle cx='6' cy='17.5' r='2.5'/><path d='M8 8l12 9.5M8 16L20 6.5'/>") },
        { QStringLiteral("download"), QStringLiteral("<path d='M12 3.5v11'/><path d='M8 11l4 3.5 4-3.5'/><path d='M5 15v3.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V15'/>") },
        { QStringLiteral("export"), QStringLiteral("<path d='M12 14.5V3.5'/><path d='M8 7l4-3.5L16 7'/><path d='M5 12v6.5A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5V12'/>") },
        { QStringLiteral("camera"), QStringLiteral("<path d='M4.5 7.5h3l1.5-2.5h6l1.5 2.5h3A1.5 1.5 0 0 1 21 9v9a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18V9a1.5 1.5 0 0 1 1.5-1.5z'/><circle cx='12' cy='13' r='3.5'/>") },
        { QStringLiteral("list"), QStringLiteral("<path d='M9 6h11M9 12h11M9 18h11'/><path d='M4.5 6h.01M4.5 12h.01M4.5 18h.01' stroke-width='2.6'/>") },
        { QStringLiteral("info"), QStringLiteral("<circle cx='12' cy='12' r='8.5'/><path d='M12 11v5.5'/><path d='M12 7.8h.01' stroke-width='2.4'/>") },
        { QStringLiteral("transcript"), QStringLiteral("<path d='M4 6h16M4 10.5h16M4 15h10M4 19.5h7'/>") },
        { QStringLiteral("scope"), QStringLiteral("<rect x='3' y='4' width='18' height='16' rx='2'/><path d='M6.5 15.5l3-4.5 3 2.5 4.5-6'/>") },
        { QStringLiteral("compare"), QStringLiteral("<rect x='3' y='5' width='18' height='14' rx='2'/><path d='M12 3v18'/>") },
        { QStringLiteral("star"), QStringLiteral("<path d='M12 3.8l2.5 5.1 5.6.8-4.1 4 1 5.6-5-2.7-5 2.7 1-5.6-4.1-4 5.6-.8z'/>") },
        { QStringLiteral("star-filled"), QStringLiteral("F:<path d='M12 3.8l2.5 5.1 5.6.8-4.1 4 1 5.6-5-2.7-5 2.7 1-5.6-4.1-4 5.6-.8z'/>") },
        { QStringLiteral("trash"), QStringLiteral("<path d='M4.5 7h15'/><path d='M9.5 7V4.5h5V7'/><path d='M6.5 7l1 12.5a1.5 1.5 0 0 0 1.5 1.4h6a1.5 1.5 0 0 0 1.5-1.4l1-12.5'/>") },
        { QStringLiteral("check"), QStringLiteral("<path d='M5 12.5l4.5 4.5L19 7.5'/>") },
        { QStringLiteral("chevron-down"), QStringLiteral("<path d='M6.5 9.5l5.5 5.5 5.5-5.5'/>") },
        { QStringLiteral("chevron-right"), QStringLiteral("<path d='M9.5 6.5l5.5 5.5-5.5 5.5'/>") },
        { QStringLiteral("keyboard"), QStringLiteral("<rect x='2.5' y='6' width='19' height='12' rx='2'/><path d='M6 9.5h.01M9.3 9.5h.01M12.6 9.5h.01M15.9 9.5h.01M18 9.5h.01M7.5 14.5h9' stroke-width='2'/>") },
        { QStringLiteral("waveform"), QStringLiteral("<path d='M2.5 12h2l2-5 3 10 3-14 3 14 2.5-8 1.5 3h2'/>") },
        { QStringLiteral("plus"), QStringLiteral("<path d='M12 5v14M5 12h14'/>") },
        { QStringLiteral("copy"), QStringLiteral("<rect x='8.5' y='8.5' width='12' height='12' rx='1.5'/><path d='M15.5 8.5V5A1.5 1.5 0 0 0 14 3.5H5A1.5 1.5 0 0 0 3.5 5v9A1.5 1.5 0 0 0 5 15.5h3.5'/>") },
        { QStringLiteral("speed"), QStringLiteral("<path d='M4.5 17a8.5 8.5 0 1 1 15 0'/><path d='M12 13l4-4.5'/>") },
        { QStringLiteral("skip-silence"), QStringLiteral("<path d='M3 12h3M18 12h3'/><path d='M8 8v8M11 6v12'/><path d='M14.5 9l3 3-3 3'/>") },
        { QStringLiteral("drop"), QStringLiteral("<path d='M12 4v11'/><path d='M7.5 10.5L12 15l4.5-4.5'/><path d='M4.5 15.5v2.5A2 2 0 0 0 6.5 20h11a2 2 0 0 0 2-2v-2.5'/>") },
        { QStringLiteral("sort"), QStringLiteral("<path d='M7 4v16M4 7l3-3 3 3M17 20V4M14 17l3 3 3-3'/>") },
        { QStringLiteral("filter"), QStringLiteral("<path d='M4 5.5h16l-6 7.5v5.5l-4 1.5v-7z'/>") },
        { QStringLiteral("external"), QStringLiteral("<path d='M14 4h6v6'/><path d='M20 4l-9 9'/><path d='M18 14v4.5a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 4 18.5v-11A1.5 1.5 0 0 1 5.5 6H10'/>") },
    };
    return m;
}
} // namespace

IconProvider::IconProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

QStringList IconProvider::names() { return icons().keys(); }

QByteArray IconProvider::svgFor(const QString &name, const QString &color)
{
    QString body = icons().value(name, icons().value(QStringLiteral("file")));
    QString attrs;
    if (body.startsWith(QLatin1String("F:"))) {
        body = body.mid(2);
        attrs = QStringLiteral("fill='%1' stroke='none'").arg(color);
    } else {
        attrs = QStringLiteral("fill='none' stroke='%1' stroke-width='1.7' stroke-linecap='round' stroke-linejoin='round'").arg(color);
    }
    return QStringLiteral("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' %1>%2</svg>").arg(attrs, body).toUtf8();
}

QImage IconProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const int q = id.indexOf(QLatin1Char('?'));
    const QString name = q < 0 ? id : id.left(q);
    QString color = q < 0 ? QStringLiteral("#e6e8eb") : id.mid(q + 1);
    if (color.size() == 9 && color.startsWith(QLatin1Char('#'))) // QML #AARRGGBB -> SVG #RRGGBB + opacity
        color = QLatin1Char('#') + color.mid(3);
    const QSize s = requestedSize.isValid() && !requestedSize.isEmpty() ? requestedSize : QSize(24, 24);
    QImage img(s, QImage::Format_ARGB32_Premultiplied);
    img.fill(Qt::transparent);
    QSvgRenderer r(svgFor(name, color));
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing);
    r.render(&p, QRectF(0, 0, s.width(), s.height()));
    if (size) *size = s;
    return img;
}
