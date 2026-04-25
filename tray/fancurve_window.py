#!/usr/bin/env python3
"""Fan Curve Editor Window — standalone window for 10-point fan curve editing."""

import sys
from pathlib import Path
from PyQt6.QtWidgets import (QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel,
                           QLineEdit, QPushButton, QScrollArea, QMessageBox)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QIcon

# Add tray path
sys.path.insert(0, str(Path(__file__).parent))

try:
    from legion_gui import (C_BG, C_CARD, C_TEXT, C_TEXT2, C_ACCENT, C_BORDER,
                          make_card, _mk_lbl, rdsys, wrsys, read_fancurve_from_hw,
                          write_fancurve_to_hw, parse_fancurve, send_notif)
    HAS_GUI = True
except ImportError:
    HAS_GUI = False
    C_BG = "#1a1a1a"
    C_CARD = "#2a2a2a"
    C_TEXT = "#e0e0e0"
    C_TEXT2 = "#888888"
    C_ACCENT = "#4a9eff"
    C_BORDER = "#444444"


class FanCurveWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("🎛️ Fan Curve Editor — 10 Points")
        self.setGeometry(100, 100, 600, 700)
        self.setStyleSheet(f"background:{C_BG};")
        self._build()

    def _build(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(16, 16, 16, 16)
        root.setSpacing(12)

        # Title
        title = QLabel("🎛️ Custom Fan Curve Editor")
        title.setStyleSheet(f"color:{C_TEXT};font-size:18px;font-weight:bold;background:transparent;")
        root.addWidget(title)

        # Instructions
        instr = _mk_lbl(
            "Edit 10 points: CPU Temp (°C), Fan1 PWM, Fan2 PWM, Accel, Decel\n"
            "PWM = fan speed (0-255). Save and Apply to write to hardware.",
            C_TEXT2, size=11)
        root.addWidget(instr)

        # Read current curve
        curve_text = ""
        try:
            with open("/sys/kernel/debug/legion/fancurve") as f:
                curve_text = f.read()
        except:
            pass

        current_points = parse_fancurve(curve_text) if curve_text else []

        # Create scroll area for table
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet(f"background:{C_CARD};border:1px solid {C_BORDER};border-radius:6px;")

        inner = QWidget()
        layout = QVBoxLayout(inner)
        layout.setSpacing(8)

        # Headers
        hdr = QLabel("Pt | CPU Temp | Fan1 PWM | Fan2 PWM | Accel | Decel")
        hdr.setStyleSheet(f"color:{C_ACCENT};font-weight:bold;font-size:11px;background:transparent;")
        layout.addWidget(hdr)

        # 10 input rows
        self._inputs = []
        for i in range(10):
            row = QHBoxLayout()
            row.setSpacing(8)

            pt_lbl = QLabel(f"{i+1}")
            pt_lbl.setStyleSheet(f"color:{C_TEXT};font-size:12px;width:30px;background:transparent;")
            row.addWidget(pt_lbl)

            defaults = current_points[i] if i < len(current_points) else {}

            for field in ["cpu_temp", "fan1_pwm", "fan2_pwm", "accel", "decel"]:
                inp = QLineEdit()
                inp.setPlaceholderText(field.replace("_", " "))
                inp.setText(str(defaults.get(field, "")))
                inp.setStyleSheet(
                    f"background:{C_BG};color:{C_TEXT};border:1px solid {C_BORDER};"
                    f"border-radius:4px;padding:4px;font-size:11px;"
                )
                row.addWidget(inp)
                self._inputs.append((inp, field))

            layout.addLayout(row)

        scroll.setWidget(inner)
        root.addWidget(scroll, 1)

        # Buttons
        btn_row = QHBoxLayout()
        btn_row.setSpacing(12)

        self._apply_btn = QPushButton("💾 Apply to Hardware")
        self._apply_btn.setFixedHeight(40)
        self._apply_btn.setStyleSheet(
            f"background:{C_ACCENT};color:{C_BG};border-radius:6px;font-weight:bold;"
        )
        self._apply_btn.clicked.connect(self._apply)
        btn_row.addWidget(self._apply_btn)

        save_btn = QPushButton("💾 Save to File")
        save_btn.setFixedHeight(40)
        save_btn.setStyleSheet(
            f"background:{C_CARD};color:{C_TEXT};border:1px solid {C_BORDER};border-radius:6px;"
        )
        save_btn.clicked.connect(self._save)
        btn_row.addWidget(save_btn)

        root.addLayout(btn_row)

        # Status
        self._status = QLabel("")
        self._status.setStyleSheet(f"color:{C_TEXT2};font-size:11px;background:transparent;")
        root.addWidget(self._status)

    def _get_points(self):
        points = []
        idx = 0
        for i in range(10):
            pt = {}
            for field in ["cpu_temp", "fan1_pwm", "fan2_pwm", "accel", "decel"]:
                inp, f = self._inputs[idx]
                try:
                    pt[field] = int(inp.text()) if inp.text() else 0
                except ValueError:
                    pt[field] = 0
                idx += 1
            points.append(pt)
        return points

    def _apply(self):
        points = self._get_points()
        if HAS_GUI:
            ok, msg = write_fancurve_to_hw(points)
            self._status.setText(msg)
            if ok:
                send_notif("Fan Curve", msg, "fan")
        else:
            self._status.setText("GUI functions not available in standalone mode")

    def _save(self):
        points = self._get_points()
        import json
        from pathlib import Path
        cfg = Path.home() / ".config" / "legion-linux-toolkit"
        cfg.mkdir(parents=True, exist_ok=True)
        fancurve_file = cfg / "fancurve_custom.json"
        with open(fancurve_file, "w") as f:
            json.dump(points, f, indent=2)
        self._status.setText(f"Saved to {fancurve_file}")


def show_fancurve_window():
    win = FanCurveWindow()
    win.show()
    return win


def main():
    app = QApplication(sys.argv)
    win = FanCurveWindow()
    win.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()