{ config, inputs, pkgs, username, ... }:

let
  wallpaper = ./assets/wallpaper.png;
  ricePython = pkgs.python3.withPackages (pythonPackages: [
    pythonPackages.pyside6
  ]);
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  home.packages = [ ricePython pkgs.playerctl ];

  home.file.".local/bin/yoga-rice-overlay.py" = {
    executable = true;
    text = builtins.replaceStrings [ "\n      " ] [ "\n" ] ''#!/usr/bin/env python3
      import glob
      import os
      import shlex
      import subprocess
      import sys
      from datetime import datetime

      from PySide6.QtCore import QPoint, QRect, QRectF, QSize, Qt, QTimer
      from PySide6.QtGui import QColor, QIcon, QPainter, QPainterPath, QPen, QPixmap
      from PySide6.QtWidgets import (
          QApplication,
          QFrame,
          QHBoxLayout,
          QLabel,
          QLineEdit,
          QPushButton,
          QVBoxLayout,
          QWidget,
      )


      WALLPAPER_PATH = "${wallpaper}"


      def launch(command):
          subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


      def read_first_existing(paths):
          for path in paths:
              try:
                  with open(path, "r", encoding="utf-8") as handle:
                      value = handle.read().strip()
                  if value:
                      return value
              except OSError:
                  pass
          return ""


      def battery_text():
          capacity = read_first_existing([
              "/sys/class/power_supply/qcom-battmgr-bat/capacity",
              "/sys/class/power_supply/BAT0/capacity",
              "/sys/class/power_supply/BAT1/capacity",
          ])
          if capacity.isdigit():
              return f"{capacity}%"

          energy_now = read_first_existing([
              "/sys/class/power_supply/qcom-battmgr-bat/energy_now",
              "/sys/class/power_supply/BAT0/energy_now",
              "/sys/class/power_supply/BAT1/energy_now",
          ])
          energy_full = read_first_existing([
              "/sys/class/power_supply/qcom-battmgr-bat/energy_full",
              "/sys/class/power_supply/BAT0/energy_full",
              "/sys/class/power_supply/BAT1/energy_full",
          ])
          if energy_now.isdigit() and energy_full.isdigit() and int(energy_full) > 0:
              return f"{round(int(energy_now) * 100 / int(energy_full))}%"

          return "--%"


      def clean_exec(command):
          parts = []
          try:
              tokens = shlex.split(command)
          except ValueError:
              tokens = command.split()

          for token in tokens:
              if token.startswith("%"):
                  continue
              parts.append(token)
          return parts


      def parse_desktop_file(path):
          name = ""
          comment = ""
          icon = "application-x-executable"
          exec_command = []
          terminal = False
          no_display = False
          app_type = "Application"

          try:
              with open(path, "r", encoding="utf-8", errors="replace") as handle:
                  for raw_line in handle:
                      line = raw_line.strip()
                      if not line or line.startswith("#"):
                          continue
                      key, sep, value = line.partition("=")
                      if not sep:
                          continue
                      if key == "Name" and not name:
                          name = value
                      elif key == "Comment" and not comment:
                          comment = value
                      elif key == "Icon" and value:
                          icon = value
                      elif key == "Exec" and value:
                          exec_command = clean_exec(value)
                      elif key == "Terminal":
                          terminal = value.lower() == "true"
                      elif key in ("NoDisplay", "Hidden"):
                          no_display = value.lower() == "true"
                      elif key == "Type":
                          app_type = value
          except OSError:
              return None

          if app_type != "Application" or no_display or terminal or not name or not exec_command:
              return None
          return {
              "name": name,
              "description": comment or "Application",
              "icon": icon,
              "command": exec_command,
          }


      def desktop_app_catalog():
          directories = [
              "/run/current-system/sw/share/applications",
              "/etc/profiles/per-user/${username}/share/applications",
              "/home/${username}/.nix-profile/share/applications",
              "/home/${username}/.local/share/applications",
          ]
          apps = {}
          for directory in directories:
              for path in sorted(glob.glob(os.path.join(directory, "*.desktop"))):
                  app = parse_desktop_file(path)
                  if app is None:
                      continue
                  key = app["name"].casefold()
                  apps.setdefault(key, app)
          return sorted(apps.values(), key=lambda item: item["name"].casefold())


      def pick_app(catalog, name, fallback_description, fallback_icon, fallback_command):
          wanted = name.casefold()
          for app in catalog:
              if app["name"].casefold() == wanted:
                  return {
                      **app,
                      "favorite": True,
                      "description": app["description"] if app["description"] != "Application" else fallback_description,
                  }
          return {
              "name": name,
              "description": fallback_description,
              "icon": fallback_icon,
              "command": fallback_command,
              "favorite": True,
          }


      class GlassFrame(QFrame):
          def __init__(self, radius=22, border_alpha=120, fill_alpha=150):
              super().__init__()
              self.radius = radius
              self.border_alpha = border_alpha
              self.fill_alpha = fill_alpha
              self.setAttribute(Qt.WA_TranslucentBackground)
              self.setStyleSheet("""
                  QLabel, QLineEdit, QPushButton {
                      background: transparent;
                      border: 0;
                  }
              """)

          def paintEvent(self, event):
              painter = QPainter(self)
              painter.setRenderHint(QPainter.Antialiasing)

              path = QPainterPath()
              path.addRoundedRect(QRectF(self.rect()).adjusted(0.5, 0.5, -0.5, -0.5), self.radius, self.radius)

              root = self.window()
              background = getattr(root, "background", QPixmap())
              if not background.isNull():
                  top_left = self.mapTo(root, QPoint(0, 0))
                  source = QRect(top_left, self.size()).intersected(background.rect())
                  if source.isValid():
                      blurred = background.copy(source)
                      # Downsample/upsample the already scaled wallpaper to approximate the frosted blur
                      # missing from plain Qt stylesheets on Wayland.
                      small = blurred.scaled(
                          max(1, blurred.width() // 16),
                          max(1, blurred.height() // 16),
                          Qt.IgnoreAspectRatio,
                          Qt.SmoothTransformation,
                      )
                      blurred = small.scaled(
                          self.size(),
                          Qt.IgnoreAspectRatio,
                          Qt.SmoothTransformation,
                      )
                      painter.save()
                      painter.setClipPath(path)
                      painter.drawPixmap(self.rect(), blurred)
                      painter.restore()

              painter.fillPath(path, QColor(16, 19, 26, self.fill_alpha))
              painter.setPen(QPen(QColor(214, 220, 232, self.border_alpha), 1))
              painter.drawPath(path)


      def glass_frame(radius=22, border_alpha=120, fill_alpha=150):
          return GlassFrame(radius=radius, border_alpha=border_alpha, fill_alpha=fill_alpha)


      class DesktopOverlay(QWidget):
          def __init__(self, screen_geometry):
              super().__init__()
              self.setWindowFlags(Qt.FramelessWindowHint | Qt.Tool | Qt.WindowStaysOnTopHint)
              self.setGeometry(screen_geometry)
              self.wallpaper = QPixmap(WALLPAPER_PATH)
              self.background = self.build_background(screen_geometry)
              launcher = Launcher(screen_geometry, self)
              TopBar(screen_geometry, launcher, self)
              launcher.search.setFocus()
              Dock(screen_geometry, self)

          def build_background(self, screen_geometry):
              background = QPixmap(screen_geometry.size())
              background.fill(Qt.black)
              if self.wallpaper.isNull():
                  return background

              painter = QPainter(background)
              target = background.rect()
              source = self.wallpaper.rect()
              target_ratio = target.width() / target.height()
              source_ratio = source.width() / source.height()

              if source_ratio > target_ratio:
                  cropped_width = int(source.height() * target_ratio)
                  source.setX(0)
                  source.setWidth(cropped_width)
              else:
                  cropped_height = int(source.width() / target_ratio)
                  source.setY((source.height() - cropped_height) // 2)
                  source.setHeight(cropped_height)

              painter.drawPixmap(target, self.wallpaper, source)
              painter.end()
              return background

          def paintEvent(self, event):
              painter = QPainter(self)
              if self.background.isNull():
                  painter.fillRect(self.rect(), Qt.black)
                  return
              painter.drawPixmap(self.rect(), self.background)


      class TopMenuButton(QPushButton):
          def __init__(self, text, command=None, action=None, strong=False):
              super().__init__(text)
              self.command = command
              self.action = action
              self.setCursor(Qt.PointingHandCursor)
              weight = 700 if strong else 400
              alpha = 255 if strong else 205
              self.setStyleSheet(f"""
                  QPushButton {{
                      color: rgba(255,255,255,{alpha});
                      font: {weight} 17px Inter;
                      background: transparent;
                      border: 0;
                      padding: 0;
                      text-align: left;
                  }}
                  QPushButton:hover {{
                      color: white;
                  }}
              """)

          def mousePressEvent(self, event):
              if event.button() == Qt.LeftButton:
                  if self.action is not None:
                      self.action()
                  elif self.command is not None:
                      launch(self.command)
              super().mousePressEvent(event)


      class TopBar(QWidget):
          def __init__(self, screen_geometry, launcher, parent):
              super().__init__(parent)
              self.setAttribute(Qt.WA_TranslucentBackground)
              self.setGeometry(0, 0, screen_geometry.width(), 38)

              root = QHBoxLayout(self)
              root.setContentsMargins(24, 0, 24, 0)
              root.setSpacing(22)

              title = TopMenuButton("Helium", ["helium"], strong=True)
              menu_items = [
                  ("File", ["dolphin"]),
                  ("Edit", ["kate"]),
                  ("View", ["systemsettings"]),
                  ("History", ["helium"]),
                  ("Tools", ["ghostty"]),
                  ("Profiles", ["systemsettings"]),
                  ("Help", ["xdg-open", "https://search.nixos.org/packages"]),
                  ("Search", None),
              ]

              center = QWidget()
              center_layout = QHBoxLayout(center)
              center_layout.setContentsMargins(0, 0, 0, 0)
              center_layout.setSpacing(24)
              self.artist_label = QLabel("")
              self.artist_label.setStyleSheet("color: white; font: 700 17px Inter;")
              self.track_label = QLabel("")
              self.track_label.setStyleSheet("color: rgba(255,255,255,190); font: 17px Inter;")
              center_layout.addWidget(self.artist_label)
              center_layout.addWidget(self.track_label)

              self.clock = QLabel()
              self.clock.setStyleSheet("color: white; font: 17px Inter;")

              root.addWidget(title)
              for label, command in menu_items:
                  action = launcher.focus_search if label == "Search" else None
                  root.addWidget(TopMenuButton(label, command, action))
              root.addStretch(1)
              root.addWidget(center)
              root.addStretch(1)
              root.addWidget(self.clock)

              self.timer = QTimer(self)
              self.timer.timeout.connect(self.update_clock)
              self.timer.start(1000)
              self.update_clock()

              self.media_timer = QTimer(self)
              self.media_timer.timeout.connect(self.update_media)
              self.media_timer.start(5000)
              self.update_media()

          def update_clock(self):
              now = datetime.now()
              self.clock.setText(f"{battery_text()}    {now:%d.%m.%Y}    <b>{now:%H:%M}</b>")

          def update_media(self):
              try:
                  output = subprocess.check_output(
                      ["playerctl", "metadata", "--format", "{{artist}}|{{title}}"],
                      stderr=subprocess.DEVNULL,
                      text=True,
                      timeout=0.5,
                  ).strip()
              except Exception:
                  output = ""

              artist, _, title = output.partition("|")
              self.artist_label.setText(artist)
              self.track_label.setText(title)
              has_media = bool(artist or title)
              self.artist_label.setVisible(has_media)
              self.track_label.setVisible(has_media)


      class FavoriteRow(QFrame):
          def __init__(self, name, description, icon_name, command, favorite=True):
              super().__init__()
              self.name = name
              self.description = description
              self.command = command
              self.favorite = favorite
              self.setCursor(Qt.PointingHandCursor)
              self.setObjectName("favoriteRow")
              self.setFixedHeight(76)
              self.setStyleSheet("""
                  QFrame#favoriteRow {
                      background: transparent;
                      border: 0;
                      padding: 0;
                  }
              """)

              layout = QHBoxLayout(self)
              layout.setContentsMargins(12, 6, 22, 6)
              layout.setSpacing(20)

              icon = QLabel()
              icon.setFixedSize(48, 48)
              icon.setPixmap(QIcon.fromTheme(icon_name).pixmap(QSize(48, 48)))
              icon.setStyleSheet("background: transparent;")
              layout.addWidget(icon)

              text_column = QVBoxLayout()
              text_column.setContentsMargins(0, 0, 0, 0)
              text_column.setSpacing(1)

              title = QLabel(name)
              title.setStyleSheet("color: white; background: transparent; font: 20px Inter;")
              subtitle = QLabel(description)
              subtitle.setStyleSheet("color: rgba(255,255,255,210); background: transparent; font: 16px Inter;")
              text_column.addStretch(1)
              text_column.addWidget(title)
              text_column.addWidget(subtitle)
              text_column.addStretch(1)

              layout.addLayout(text_column, 1)

          def mousePressEvent(self, event):
              if event.button() == Qt.LeftButton:
                  launch(self.command)
              super().mousePressEvent(event)


      class Launcher(QWidget):
          def __init__(self, screen_geometry, parent):
              super().__init__(parent)
              self.setAttribute(Qt.WA_TranslucentBackground)

              width = int(screen_geometry.width() * 0.400)
              height = int(screen_geometry.height() * 0.350)
              x = int(screen_geometry.x() + (screen_geometry.width() - width) / 2)
              y = int(screen_geometry.y() + screen_geometry.height() * 0.300)
              self.setGeometry(x, y, width, height)

              root = QVBoxLayout(self)
              root.setContentsMargins(0, 0, 0, 0)
              root.setSpacing(12)

              search_frame = glass_frame(radius=20, border_alpha=150, fill_alpha=182)
              search_layout = QVBoxLayout(search_frame)
              search_layout.setContentsMargins(48, 14, 34, 14)
              self.search = QLineEdit()
              self.search.setPlaceholderText("Start typing...")
              self.search.setStyleSheet("""
                  QLineEdit {
                      color: white;
                      background: transparent;
                      border: 0;
                      font: 33px Inter;
                      selection-background-color: rgba(255,255,255,55);
                  }
                  QLineEdit::placeholder {
                      color: rgba(255,255,255,90);
                  }
              """)
              search_layout.addWidget(self.search)

              apps_frame = glass_frame(radius=20, border_alpha=150, fill_alpha=170)
              apps_layout = QVBoxLayout(apps_frame)
              apps_layout.setContentsMargins(38, 24, 34, 22)
              apps_layout.setSpacing(2)
              self.header = QLabel("★ Favorite apps")
              self.header.setStyleSheet("color: white; background: transparent; border: 0; font: 700 17px Inter;")
              apps_layout.addWidget(self.header)
              apps_layout.addSpacing(12)

              catalog = desktop_app_catalog()
              favorites = [
                  pick_app(catalog, "Helium", "Access the Internet", "helium", ["helium"]),
                  pick_app(catalog, "Ghostty", "A terminal emulator", "com.mitchellh.ghostty", ["ghostty"]),
                  pick_app(catalog, "Kate", "A fast text editor", "org.kde.kate", ["kate"]),
                  pick_app(catalog, "Dolphin", "Manage your files", "system-file-manager", ["dolphin"]),
              ]
              favorite_names = {app["name"].casefold() for app in favorites}
              apps = favorites + [
                  {**app, "favorite": False}
                  for app in catalog
                  if app["name"].casefold() not in favorite_names
              ]
              self.rows = []
              for app in apps:
                  row = FavoriteRow(
                      app["name"],
                      app["description"],
                      app["icon"],
                      app["command"],
                      app["favorite"],
                  )
                  self.rows.append(row)
                  apps_layout.addWidget(row)
              apps_layout.addStretch(1)

              root.addWidget(search_frame)
              root.addWidget(apps_frame, 1)
              self.search.textChanged.connect(self.filter_apps)
              self.search.returnPressed.connect(self.launch_first_match)
              self.filter_apps("")

          def focus_search(self):
              self.search.setFocus()
              self.search.selectAll()

          def filter_apps(self, text):
              query = text.strip().lower()
              self.header.setText("Search results" if query else "★ Favorite apps")
              visible_count = 0
              for row in self.rows:
                  haystack = f"{row.name} {row.description}".lower()
                  visible = (row.favorite if not query else query in haystack and visible_count < 6)
                  row.setVisible(visible)
                  visible_count += 1 if visible else 0

              if query and visible_count == 0:
                  self.header.setText("No matching apps")

          def launch_first_match(self):
              for row in self.rows:
                  if row.isVisible():
                      launch(row.command)
                      return


      class DockTooltip(QWidget):
          def __init__(self, screen_geometry, parent):
              super().__init__(parent)
              self.setAttribute(Qt.WA_TranslucentBackground)

              width = int(screen_geometry.width() * 0.122)
              height = int(screen_geometry.height() * 0.060)
              self.screen_geometry = screen_geometry
              self.setFixedSize(width, height)

              shell = glass_frame(radius=7, border_alpha=112, fill_alpha=172)
              shell.setParent(self)
              shell.setGeometry(0, 0, width, height)

              layout = QVBoxLayout(shell)
              layout.setContentsMargins(20, 10, 20, 10)
              layout.setSpacing(3)

              self.title = QLabel("Helium")
              self.title.setStyleSheet("color: white; font: 17px Inter;")
              self.subtitle = QLabel("Access the Internet")
              self.subtitle.setStyleSheet("color: rgba(255,255,255,200); font: 15px Inter;")
              layout.addStretch(1)
              layout.addWidget(self.title)
              layout.addWidget(self.subtitle)
              layout.addStretch(1)
              self.hide()

          def show_for(self, button):
              self.title.setText(button.label)
              self.subtitle.setText(button.description)
              top_left = button.mapTo(self.parent(), QPoint(0, 0))
              x = int(top_left.x() + (button.width() - self.width()) / 2)
              y = int(top_left.y() - self.height() - 10)
              x = max(12, min(x, self.screen_geometry.width() - self.width() - 12))
              self.move(x, y)
              self.show()


      class DockButton(QPushButton):
          def __init__(self, label, description, icon_name, command, tooltip=None):
              super().__init__()
              self.label = label
              self.description = description
              self.command = command
              self.tooltip = tooltip
              self.setToolTip(label)
              self.setCursor(Qt.PointingHandCursor)
              self.setIcon(QIcon.fromTheme(icon_name))
              self.setIconSize(QSize(52, 52))
              self.setFixedSize(66, 66)
              self.setStyleSheet("""
                  QPushButton {
                      background-color: rgba(255,255,255,20);
                      border: 1px solid rgba(255,255,255,18);
                      border-radius: 18px;
                  }
                  QPushButton:hover {
                      background-color: rgba(255,255,255,48);
                  }
              """)
              self.clicked.connect(lambda: launch(command))

          def enterEvent(self, event):
              if self.tooltip is not None:
                  self.tooltip.show_for(self)
              super().enterEvent(event)

          def leaveEvent(self, event):
              if self.tooltip is not None:
                  self.tooltip.hide()
              super().leaveEvent(event)


      class Dock(QWidget):
          def __init__(self, screen_geometry, parent):
              super().__init__(parent)
              self.setAttribute(Qt.WA_TranslucentBackground)

              width = int(screen_geometry.width() * 0.142)
              height = int(screen_geometry.height() * 0.078)
              x = int(screen_geometry.x() + (screen_geometry.width() - width) / 2)
              y = int(screen_geometry.y() + screen_geometry.height() * 0.855)
              self.setGeometry(x, y, width, height)

              shell = glass_frame(radius=22, border_alpha=132, fill_alpha=148)
              shell.setParent(self)
              shell.setGeometry(0, 0, width, height)
              tooltip = DockTooltip(screen_geometry, parent)

              layout = QHBoxLayout(shell)
              layout.setContentsMargins(24, 18, 24, 18)
              layout.setSpacing(14)

              apps = [
                  ("Helium", "Access the Internet", "helium", ["helium"]),
                  ("Kate", "A fast text editor", "org.kde.kate", ["kate"]),
                  ("Ghostty", "A terminal emulator", "com.mitchellh.ghostty", ["ghostty"]),
                  ("Vesktop", "Discord client", "vesktop", ["vesktop"]),
              ]
              for label, description, icon_name, command in apps:
                  button = DockButton(label, description, icon_name, command, tooltip)
                  layout.addWidget(button)


      os.environ.setdefault("QT_QPA_PLATFORM", "wayland")
      os.environ.setdefault("QT_SCALE_FACTOR", "1")
      os.environ.setdefault("QT_AUTO_SCREEN_SCALE_FACTOR", "0")
      runtime_dir = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
      if "XAUTHORITY" not in os.environ:
          matches = sorted(glob.glob(f"{runtime_dir}/xauth_*"))
          if matches:
              os.environ["XAUTHORITY"] = matches[-1]

      if "--self-test" in sys.argv:
          catalog = desktop_app_catalog()
          print(f"desktop_apps={len(catalog)}")
          for app in catalog[:12]:
              print(f"{app['name']} -> {' '.join(app['command'])}")
          sys.exit(0)

      app = QApplication(sys.argv)
      app.setQuitOnLastWindowClosed(False)
      QIcon.setThemeName("Papirus-Dark")

      screen = app.primaryScreen().geometry()
      window = DesktopOverlay(screen)
      window.showFullScreen()

      sys.exit(app.exec())
    '';
  };

  systemd.user.services.yoga-rice-overlay = {
    Unit = {
      Description = "Yoga rice overlay";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${ricePython}/bin/python3 ${config.home.homeDirectory}/.local/bin/yoga-rice-overlay.py";
      Restart = "on-failure";
      RestartSec = 2;
      Environment = [
        "QT_QPA_PLATFORM=wayland"
        "QT_SCALE_FACTOR=1"
        "QT_AUTO_SCREEN_SCALE_FACTOR=0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=%t/bus"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  gtk = {
    enable = true;
    theme = {
      name = "Breeze-Dark";
      package = pkgs.kdePackages.breeze-gtk;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Inter";
      size = 10;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    gtk4.theme = config.gtk.theme;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "helium.desktop";
      "x-scheme-handler/http" = "helium.desktop";
      "x-scheme-handler/https" = "helium.desktop";
    };
  };

  programs.plasma = {
    enable = true;

    workspace = {
      lookAndFeel = "org.kde.breezedark.desktop";
      theme = "breeze-dark";
      colorScheme = "BreezeDark";
      widgetStyle = "breeze";
      iconTheme = "Papirus-Dark";
      wallpaper = wallpaper;
      wallpaperFillMode = "preserveAspectCrop";
    };

    fonts = {
      general = {
        family = "Inter";
        pointSize = 10;
      };
      menu = {
        family = "Inter";
        pointSize = 10;
      };
      toolbar = {
        family = "Inter";
        pointSize = 10;
      };
      small = {
        family = "Inter";
        pointSize = 8;
      };
      windowTitle = {
        family = "Inter";
        pointSize = 10;
      };
      fixedWidth = {
        family = "JetBrains Mono";
        pointSize = 10;
      };
    };

    kwin = {
      virtualDesktops = {
        rows = 1;
        names = [
          "Main"
          "Secondary"
        ];
      };

      effects = {
        blur = {
          enable = true;
          strength = 8;
          noiseStrength = 0;
        };
        translucency.enable = true;
        desktopSwitching.animation = "fade";
        windowOpenClose.animation = "fade";
      };
    };

    krunner = {
      position = "center";
      activateWhenTypingOnDesktop = false;
      historyBehavior = "enableSuggestions";
      shortcuts.launch = "Alt+Space";
    };

    configFile = {
      kscreenlockerrc = {
        Daemon = {
          Autolock.value = false;
          LockOnResume.value = false;
          Timeout.value = 0;
        };
      };
      powerdevilprofilesrc = {
        "AC][DPMSControl".idleTime.value = 0;
        "AC][SuspendSession".idleTime.value = 0;
        "Battery][DPMSControl".idleTime.value = 3600;
        "Battery][SuspendSession".idleTime.value = 5400;
        "LowBattery][DPMSControl".idleTime.value = 1800;
        "LowBattery][SuspendSession".idleTime.value = 3600;
      };
    };

    panels = [ ];
  };
}
