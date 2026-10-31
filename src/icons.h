#pragma once
#include <QQuickImageProvider>

// "image://icon/<name>?<color>" renders one of Slate's line icons (24 px grid, drawn for
// this app) at the exact requested size, so icons stay sharp at any display scaling.
class IconProvider : public QQuickImageProvider
{
public:
    IconProvider();
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
    static QByteArray svgFor(const QString &name, const QString &color);
    static QStringList names();
};
