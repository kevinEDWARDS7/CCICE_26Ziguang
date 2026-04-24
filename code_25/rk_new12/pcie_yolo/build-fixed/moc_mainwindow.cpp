/****************************************************************************
** Meta object code from reading C++ file 'mainwindow.h'
**
** Created by: The Qt Meta Object Compiler version 67 (Qt 5.15.3)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include <memory>
#include "../mainwindow.h"
#include <QtCore/qbytearray.h>
#include <QtCore/qmetatype.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'mainwindow.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 67
#error "This file was generated using the moc from 5.15.3. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

QT_BEGIN_MOC_NAMESPACE
QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
struct qt_meta_stringdata_MainWindow_t {
    QByteArrayData data[22];
    char stringdata0[333];
};
#define QT_MOC_LITERAL(idx, ofs, len) \
    Q_STATIC_BYTE_ARRAY_DATA_HEADER_INITIALIZER_WITH_OFFSET(len, \
    qptrdiff(offsetof(qt_meta_stringdata_MainWindow_t, stringdata0) + ofs \
        - idx * sizeof(QByteArrayData)) \
    )
static const qt_meta_stringdata_MainWindow_t qt_meta_stringdata_MainWindow = {
    {
QT_MOC_LITERAL(0, 0, 10), // "MainWindow"
QT_MOC_LITERAL(1, 11, 14), // "newframe_ready"
QT_MOC_LITERAL(2, 26, 0), // ""
QT_MOC_LITERAL(3, 27, 5), // "index"
QT_MOC_LITERAL(4, 33, 16), // "dada_recv_to_dis"
QT_MOC_LITERAL(5, 50, 10), // "rate_cacul"
QT_MOC_LITERAL(6, 61, 16), // "display_newframe"
QT_MOC_LITERAL(7, 78, 15), // "on_Key1_clicked"
QT_MOC_LITERAL(8, 94, 10), // "timerEvent"
QT_MOC_LITERAL(9, 105, 12), // "QTimerEvent*"
QT_MOC_LITERAL(10, 118, 5), // "event"
QT_MOC_LITERAL(11, 124, 15), // "on_Gray_clicked"
QT_MOC_LITERAL(12, 140, 18), // "on_connect_clicked"
QT_MOC_LITERAL(13, 159, 15), // "on_save_clicked"
QT_MOC_LITERAL(14, 175, 21), // "on_save_video_clicked"
QT_MOC_LITERAL(15, 197, 15), // "on_cam1_clicked"
QT_MOC_LITERAL(16, 213, 15), // "on_cam2_clicked"
QT_MOC_LITERAL(17, 229, 20), // "on_dma_write_clicked"
QT_MOC_LITERAL(18, 250, 19), // "on_dma_read_clicked"
QT_MOC_LITERAL(19, 270, 12), // "recv_img_dis"
QT_MOC_LITERAL(20, 283, 21), // "on_pushButton_clicked"
QT_MOC_LITERAL(21, 305, 27) // "on_enable_detection_clicked"

    },
    "MainWindow\0newframe_ready\0\0index\0"
    "dada_recv_to_dis\0rate_cacul\0"
    "display_newframe\0on_Key1_clicked\0"
    "timerEvent\0QTimerEvent*\0event\0"
    "on_Gray_clicked\0on_connect_clicked\0"
    "on_save_clicked\0on_save_video_clicked\0"
    "on_cam1_clicked\0on_cam2_clicked\0"
    "on_dma_write_clicked\0on_dma_read_clicked\0"
    "recv_img_dis\0on_pushButton_clicked\0"
    "on_enable_detection_clicked"
};
#undef QT_MOC_LITERAL

static const uint qt_meta_data_MainWindow[] = {

 // content:
       8,       // revision
       0,       // classname
       0,    0, // classinfo
      17,   14, // methods
       0,    0, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
       1,       // signalCount

 // signals: name, argc, parameters, tag, flags
       1,    1,   99,    2, 0x06 /* Public */,

 // slots: name, argc, parameters, tag, flags
       4,    0,  102,    2, 0x0a /* Public */,
       5,    0,  103,    2, 0x0a /* Public */,
       6,    1,  104,    2, 0x0a /* Public */,
       7,    0,  107,    2, 0x08 /* Private */,
       8,    1,  108,    2, 0x08 /* Private */,
      11,    0,  111,    2, 0x08 /* Private */,
      12,    0,  112,    2, 0x08 /* Private */,
      13,    0,  113,    2, 0x08 /* Private */,
      14,    0,  114,    2, 0x08 /* Private */,
      15,    0,  115,    2, 0x08 /* Private */,
      16,    0,  116,    2, 0x08 /* Private */,
      17,    0,  117,    2, 0x08 /* Private */,
      18,    0,  118,    2, 0x08 /* Private */,
      19,    1,  119,    2, 0x08 /* Private */,
      20,    0,  122,    2, 0x08 /* Private */,
      21,    0,  123,    2, 0x08 /* Private */,

 // signals: parameters
    QMetaType::Void, QMetaType::Int,    3,

 // slots: parameters
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void, QMetaType::Int,    3,
    QMetaType::Void,
    QMetaType::Void, 0x80000000 | 9,   10,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void, QMetaType::Int,    3,
    QMetaType::Void,
    QMetaType::Void,

       0        // eod
};

void MainWindow::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    if (_c == QMetaObject::InvokeMetaMethod) {
        auto *_t = static_cast<MainWindow *>(_o);
        (void)_t;
        switch (_id) {
        case 0: _t->newframe_ready((*reinterpret_cast< int(*)>(_a[1]))); break;
        case 1: _t->dada_recv_to_dis(); break;
        case 2: _t->rate_cacul(); break;
        case 3: _t->display_newframe((*reinterpret_cast< int(*)>(_a[1]))); break;
        case 4: _t->on_Key1_clicked(); break;
        case 5: _t->timerEvent((*reinterpret_cast< QTimerEvent*(*)>(_a[1]))); break;
        case 6: _t->on_Gray_clicked(); break;
        case 7: _t->on_connect_clicked(); break;
        case 8: _t->on_save_clicked(); break;
        case 9: _t->on_save_video_clicked(); break;
        case 10: _t->on_cam1_clicked(); break;
        case 11: _t->on_cam2_clicked(); break;
        case 12: _t->on_dma_write_clicked(); break;
        case 13: _t->on_dma_read_clicked(); break;
        case 14: _t->recv_img_dis((*reinterpret_cast< int(*)>(_a[1]))); break;
        case 15: _t->on_pushButton_clicked(); break;
        case 16: _t->on_enable_detection_clicked(); break;
        default: ;
        }
    } else if (_c == QMetaObject::IndexOfMethod) {
        int *result = reinterpret_cast<int *>(_a[0]);
        {
            using _t = void (MainWindow::*)(int );
            if (*reinterpret_cast<_t *>(_a[1]) == static_cast<_t>(&MainWindow::newframe_ready)) {
                *result = 0;
                return;
            }
        }
    }
}

QT_INIT_METAOBJECT const QMetaObject MainWindow::staticMetaObject = { {
    QMetaObject::SuperData::link<QMainWindow::staticMetaObject>(),
    qt_meta_stringdata_MainWindow.data,
    qt_meta_data_MainWindow,
    qt_static_metacall,
    nullptr,
    nullptr
} };


const QMetaObject *MainWindow::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *MainWindow::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_meta_stringdata_MainWindow.stringdata0))
        return static_cast<void*>(this);
    return QMainWindow::qt_metacast(_clname);
}

int MainWindow::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QMainWindow::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 17)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 17;
    } else if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 17)
            *reinterpret_cast<int*>(_a[0]) = -1;
        _id -= 17;
    }
    return _id;
}

// SIGNAL 0
void MainWindow::newframe_ready(int _t1)
{
    void *_a[] = { nullptr, const_cast<void*>(reinterpret_cast<const void*>(std::addressof(_t1))) };
    QMetaObject::activate(this, &staticMetaObject, 0, _a);
}
struct qt_meta_stringdata_SaveImageThread_t {
    QByteArrayData data[1];
    char stringdata0[16];
};
#define QT_MOC_LITERAL(idx, ofs, len) \
    Q_STATIC_BYTE_ARRAY_DATA_HEADER_INITIALIZER_WITH_OFFSET(len, \
    qptrdiff(offsetof(qt_meta_stringdata_SaveImageThread_t, stringdata0) + ofs \
        - idx * sizeof(QByteArrayData)) \
    )
static const qt_meta_stringdata_SaveImageThread_t qt_meta_stringdata_SaveImageThread = {
    {
QT_MOC_LITERAL(0, 0, 15) // "SaveImageThread"

    },
    "SaveImageThread"
};
#undef QT_MOC_LITERAL

static const uint qt_meta_data_SaveImageThread[] = {

 // content:
       8,       // revision
       0,       // classname
       0,    0, // classinfo
       0,    0, // methods
       0,    0, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
       0,       // signalCount

       0        // eod
};

void SaveImageThread::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    (void)_o;
    (void)_id;
    (void)_c;
    (void)_a;
}

QT_INIT_METAOBJECT const QMetaObject SaveImageThread::staticMetaObject = { {
    QMetaObject::SuperData::link<QThread::staticMetaObject>(),
    qt_meta_stringdata_SaveImageThread.data,
    qt_meta_data_SaveImageThread,
    qt_static_metacall,
    nullptr,
    nullptr
} };


const QMetaObject *SaveImageThread::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *SaveImageThread::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_meta_stringdata_SaveImageThread.stringdata0))
        return static_cast<void*>(this);
    return QThread::qt_metacast(_clname);
}

int SaveImageThread::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QThread::qt_metacall(_c, _id, _a);
    return _id;
}
QT_WARNING_POP
QT_END_MOC_NAMESPACE
