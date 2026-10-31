#pragma once
#include <QStringList>

// Builds the play queue from the folder of the opened file, in natural order
// ("part 2" before "part 10"), so Next/Previous walk through a shoot folder.
namespace FolderQueue {

bool isMediaFile(const QString &path);
QStringList naturalSorted(QStringList names);
QStringList mediaFilesIn(const QString &folder);

}
