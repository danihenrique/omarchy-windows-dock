.pragma library

var STRINGS = {
  en: {
    start: "Start",
    pin: "Pin to taskbar",
    unpin: "Unpin from taskbar",
    moveLeft: "Move left",
    moveRight: "Move right",
    close: "Close window",
    closeAll: "Close all windows",
    autoHide: "Automatically hide the taskbar",
    floating: "Floating dock",
    alignLeft: "Align icons to the left",
    showClock: "Show clock",
    showPreviews: "Show window previews",
    barHeight: "Taskbar height",
    iconSize: "Icon size",
    editConfig: "Open config file"
  },
  ru: {
    start: "Пуск",
    pin: "Закрепить на панели задач",
    unpin: "Открепить от панели задач",
    moveLeft: "Сдвинуть влево",
    moveRight: "Сдвинуть вправо",
    close: "Закрыть окно",
    closeAll: "Закрыть все окна",
    autoHide: "Автоматически скрывать панель задач",
    floating: "Плавающий док",
    alignLeft: "Значки по левому краю",
    showClock: "Показывать часы",
    showPreviews: "Показывать превью окон",
    barHeight: "Высота панели",
    iconSize: "Размер значков",
    editConfig: "Открыть файл настроек"
  }
}

function tr(key, localeName) {
  var lang = String(localeName || "en").slice(0, 2)
  var table = STRINGS[lang] || STRINGS.en
  return table[key] || STRINGS.en[key] || key
}
