import sys
import serial
import csv
from datetime import datetime
from collections import deque
import pyqtgraph as pg
from pyqtgraph.Qt import QtCore, QtGui

PORT_UART = 'COM5'
BAUD_RATE = 230414

try:
    ser = serial.Serial(PORT_UART, BAUD_RATE, timeout=0)
    ser.reset_input_buffer()
except Exception as e:
    print(f"Błąd portu szeregowego: {e}")
    sys.exit(1)

UPDATE_INTERVAL_MS = 90
BUFFER_SIZE = 200

is_paused = False
byte_buffer = bytearray()

SYNC_WORD = b'\xaa\x55'

app = pg.mkQApp("Wykres UART")
win = pg.GraphicsLayoutWidget(show=True, title="Wykres: Faza i Sinus")
win.resize(1000, 600)

plot = win.addPlot(title="Odbiór na żywo (Spacja = Pauza | 'S' = Zapis CSV)")
plot.showGrid(x=True, y=True)
plot.addLegend()

plot.disableAutoRange()

plot.setXRange(0, BUFFER_SIZE, padding=0)

plot.setYRange(-1.2, 1.2, padding=0)
plot.setMouseEnabled(x=True, y=True)

curve_faza = plot.plot(pen=pg.mkPen('y', width=2), name='Faza (32-bit)')
curve_sinus = plot.plot(pen=pg.mkPen('c', width=2), name='Sinus (16-bit)')

data_faza = deque([0.0] * BUFFER_SIZE, maxlen=BUFFER_SIZE)
data_sinus = deque([0.0] * BUFFER_SIZE, maxlen=BUFFER_SIZE)

def save_to_csv():
    filename = datetime.now().strftime("dane_pll_%Y%m%d_%H%M%S.csv")
    try:
        with open(filename, mode='w', newline='') as file:
            writer = csv.writer(file)
            writer.writerow(["Probka", "Faza", "Sinus"])
            f_list = list(data_faza)
            s_list = list(data_sinus)
            for i in range(len(f_list)):
                writer.writerow([i, f_list[i], s_list[i]])
        print(f"Zapisano {len(f_list)} próbek do pliku: {filename}")
        plot.setTitle(f"Zapisano plik: {filename}")
    except Exception as e:
        print(f"Błąd zapisu CSV: {e}")

class KeyPressFilter(QtCore.QObject):
    def eventFilter(self, obj, event):
        global is_paused
        if event.type() == QtCore.QEvent.Type.KeyPress:
            if event.key() == QtCore.Qt.Key.Key_Space:
                is_paused = not is_paused
                status = "ZATRZYMANO" if is_paused else "URUCHOMIONO"
                plot.setTitle(f"Odbiór na żywo [{status}] (Spacja=Pauza, S=Zapis)")
                return True
            elif event.key() == QtCore.Qt.Key.Key_S:
                save_to_csv()
                return True
        return False

key_filter = KeyPressFilter()
win.installEventFilter(key_filter)

def update():
    global byte_buffer

    try:
        if ser.in_waiting > 0:
            byte_buffer += ser.read(ser.in_waiting)
    except:
        return

    has_new_data = False

    while True:
        sync_idx = byte_buffer.find(SYNC_WORD)

        if sync_idx == -1:
            if len(byte_buffer) > 4096:
                byte_buffer.clear()
            break
        
        if len(byte_buffer) >= sync_idx + 8:
            
            raw_sinus = byte_buffer[sync_idx+2 : sync_idx+4]
            raw_faza  = byte_buffer[sync_idx+4 : sync_idx+8]

            byte_buffer = byte_buffer[sync_idx + 8 :]

            val_sinus = int.from_bytes(raw_sinus, byteorder='little', signed=True)
            val_faza  = int.from_bytes(raw_faza, byteorder='little', signed=False)

            val_faza_scaled = (val_faza / 2147483648.0)
            val_sinus_scaled = val_sinus / 32768.0

            if not is_paused:
                data_faza.append(val_faza_scaled)
                data_sinus.append(val_sinus_scaled)
                has_new_data = True
        else:
            break

    if has_new_data and not is_paused:
        curve_faza.setData(list(data_faza))
        curve_sinus.setData(list(data_sinus))

timer = QtCore.QTimer()
timer.timeout.connect(update)
timer.start(UPDATE_INTERVAL_MS)

if __name__ == '__main__':
    try:
        if hasattr(app, 'exec'):
            app.exec()
        else:
            app.exec_()
    except KeyboardInterrupt:
        pass
    finally:
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("Port zamknięty.")