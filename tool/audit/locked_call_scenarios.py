"""Emulator-only real-life scenarios for a call answered on a locked phone.

Drives tool/audit/locked_call_harness.dart, like locked_call_check.py, and adds
what that one never did: unlocking afterwards, the screen going off mid-call,
Home, the ear (proximity) and small screens. Sets the emulator's PIN to 2468
for the run and clears it at the end. Never point this at a real phone.

  flutter build apk --debug -t tool/audit/locked_call_harness.dart
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
  python3 tool/audit/locked_call_scenarios.py [scenario ...]

Scenarios: hangup_unlock, screen_off_end, home_return, ear, heads_up_accept,
small_screens.
No argument runs them all.
"""
import io
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

from PIL import Image

ADB = '/Users/murad/Library/Android/sdk/platform-tools/adb'
PKG = 'com.ababilx.app'
PIN = '2468'


def adb(*args):
    return subprocess.check_output([ADB, '-e', *args], text=True)


def shell(*args):
    return adb('shell', *args)


def nodes():
    shell('rm', '-f', '/sdcard/lock-test.xml')
    try:
        shell('uiautomator', 'dump', '/sdcard/lock-test.xml')
        return list(ET.fromstring(shell('cat', '/sdcard/lock-test.xml')).iter('node'))
    except (subprocess.CalledProcessError, ET.ParseError):
        return []


def screen_text():
    for _ in range(5):
        shell('input', 'keyevent', 'KEYCODE_WAKEUP')
        found = nodes()
        if found:
            return ' '.join(n.get('text', '') + ' ' + n.get('content-desc', '') for n in found)
        time.sleep(1.5)
    raise AssertionError('uiautomator could not read the screen')


def wait_for(label, seconds=30):
    text = ''
    deadline = time.time() + seconds
    while time.time() < deadline:
        text = screen_text()
        if label in text:
            return
        time.sleep(1)
    raise AssertionError('Never showed %r; screen: %s' % (label, text))


def tap(label):
    for n in nodes():
        if label in n.get('text', '') + n.get('content-desc', ''):
            x1, y1, x2, y2 = map(int, re.findall(r'\d+', n.get('bounds')))
            shell('input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))
            return
    raise AssertionError('Not on screen: ' + label)


def activities():
    return shell('dumpsys', 'activity', 'activities')


def ringing_screen_up():
    top = re.search(r'topResumedActivity=ActivityRecord\{\S+ u0 (\S+)', activities())
    return bool(top) and 'CallkitIncomingActivity' in top.group(1)


def occluded():
    return 'mKeyguardOccluded=true' in shell('dumpsys', 'window', 'policy')


def keyguard_showing():
    return 'showing=true' in shell('dumpsys', 'window', 'policy')


def app_on_top():
    top = re.search(r'topResumedActivity=ActivityRecord\{\S+ u0 (\S+)', activities())
    return bool(top) and top.group(1) in (PKG + '/.Launcher', PKG + '/.MainActivity')


def screen_on():
    return 'mWakefulness=Awake' in shell('dumpsys', 'power')


def black_fraction():
    """Share of near-black pixels between the status and navigation bars."""
    png = subprocess.check_output([ADB, '-e', 'exec-out', 'screencap', '-p'])
    img = Image.open(io.BytesIO(png)).convert('L')
    w, h = img.size
    area = img.crop((0, int(h * 0.1), w, int(h * 0.9))).resize((100, 160))
    pixels = list(area.getdata())
    return sum(1 for p in pixels if p < 24) / len(pixels)


def set_pin():
    # A reinstall (connectedAndroidTest does one) drops runtime grants, and a
    # harness without notification access never rings.
    shell('pm', 'grant', PKG, 'android.permission.POST_NOTIFICATIONS')
    shell('pm', 'grant', PKG, 'android.permission.RECORD_AUDIO')
    clear_pin()
    shell('locksettings', 'set-pin', PIN)


def clear_pin():
    try:
        shell('locksettings', 'clear', '--old', PIN)
    except subprocess.CalledProcessError:
        pass


def unlock():
    wake()
    time.sleep(0.5)
    # The bouncer is slow to come up right after a density change; try again.
    for _ in range(3):
        if not keyguard_showing():
            return
        shell('wm', 'dismiss-keyguard')
        time.sleep(2)
        shell('input', 'text', PIN)
        shell('input', 'keyevent', '66')
        time.sleep(3)
        wake()
    assert not keyguard_showing(), 'PIN unlock did not take'


def answer_on_locked_phone():
    """Fresh app, ring, lock, press Answer on CallKit's lock-screen surface."""
    shell('input', 'keyevent', 'KEYCODE_WAKEUP')
    if keyguard_or_secure():
        unlock()
    shell('am', 'force-stop', PKG)
    shell('pm', 'grant', PKG, 'android.permission.RECORD_AUDIO')
    shell('monkey', '-p', PKG, '-c', 'android.intent.category.LAUNCHER', '1')
    wait_for('RING IN FIVE SECONDS')
    tap('RING IN FIVE SECONDS')
    shell('input', 'keyevent', 'KEYCODE_SLEEP')
    wait_ringing()
    for _ in range(3):
        box = ring_buttons_when_drawn()[0]['accept']
        shell('input', 'tap', str((box[0] + box[2]) // 2), str((box[1] + box[3]) // 2))
        time.sleep(2)
        if not ringing_screen_up():
            break
    else:
        raise AssertionError('The ringing screen ignored the tap')
    wait_for('CALL CONNECTED')
    assert occluded(), 'Answer did not run over the keyguard'


def keyguard_or_secure():
    return keyguard_showing()


def screenshot():
    png = subprocess.check_output([ADB, '-e', 'exec-out', 'screencap', '-p'])
    return png, Image.open(io.BytesIO(png)).convert('RGB')


def ring_buttons():
    """Bounding boxes of the green Accept and red Decline circles.

    Read off the pixels: the ringing screen's ripples never let uiautomator
    reach an idle state, so it cannot be dumped while it rings.
    """
    _, img = screenshot()
    w, h = img.size
    small = img.resize((w // 4, h // 4))
    boxes = {'accept': None, 'decline': None}
    px = small.load()
    for y in range(small.size[1] // 3, small.size[1]):
        for x in range(small.size[0]):
            r, g, b = px[x, y]
            key = 'accept' if (g > 150 and r < 120 and b < 120) else \
                'decline' if (r > 200 and g < 110 and b < 110) else None
            if key is None:
                continue
            box = boxes[key]
            boxes[key] = (x, y, x, y) if box is None else \
                (min(box[0], x), min(box[1], y), max(box[2], x), max(box[3], y))
    scaled = {}
    for key, box in boxes.items():
        assert box is not None, 'No %s button on the ringing screen' % key
        scaled[key] = tuple(v * 4 for v in box)
    return scaled, (w, h)


def wake():
    shell('input', 'keyevent', 'KEYCODE_WAKEUP')
    for _ in range(20):
        if screen_on():
            return
        time.sleep(0.25)


def wait_ringing(seconds=20):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if ringing_screen_up():
            time.sleep(1.5)  # past its enter animation, or the tap is lost
            wake()
            return
        time.sleep(1)
    raise AssertionError('The ringing screen never came up')


def ring_buttons_when_drawn(seconds=8):
    deadline = time.time() + seconds
    while True:
        try:
            return ring_buttons()
        except AssertionError:
            if time.time() > deadline:
                raise
            wake()
            time.sleep(0.5)


def assert_app_visible(when):
    # A debug build takes a moment to draw its first frame after a wake;
    # the bug is a black screen that STAYS.
    deadline = time.time() + 8
    black = 1.0
    while time.time() < deadline:
        wake()
        black = black_fraction()
        if black < 0.6:
            break
        time.sleep(0.5)
    assert black < 0.6, 'Black screen %s (%.0f%% black after 8 s)' % (when, black * 100)
    assert app_on_top(), 'App is not the top activity %s' % when
    assert 'PRIVATE CHAT CONTENT' in screen_text(), 'App content missing %s' % when


def assert_locked_and_hidden(when, seconds=6):
    deadline = time.time() + seconds
    while time.time() < deadline and (occluded() or app_on_top()):
        time.sleep(0.5)
    assert not occluded(), 'App still over the keyguard %s' % when
    assert not app_on_top(), 'App on top of the lock screen %s' % when
    assert keyguard_showing(), 'Keyguard gone %s' % when


def hangup_unlock():
    answer_on_locked_phone()
    tap('END CALL')
    time.sleep(2)
    assert_locked_and_hidden('after hang-up')
    unlock()
    assert_app_visible('after unlocking')
    print('PASS  hang up while locked, then unlock: app draws, no black screen')


def screen_off_end():
    answer_on_locked_phone()
    tap('END IN EIGHT SECONDS')
    shell('input', 'keyevent', 'KEYCODE_SLEEP')
    time.sleep(12)
    shell('input', 'keyevent', 'KEYCODE_WAKEUP')
    time.sleep(2)
    assert_locked_and_hidden('after the call ended with the screen off')
    unlock()
    assert_app_visible('after unlocking')
    print('PASS  call ends while the screen is off: lock screen back, unlock draws the app')


def home_return():
    answer_on_locked_phone()
    shell('input', 'keyevent', 'KEYCODE_HOME')
    time.sleep(2)
    assert_locked_and_hidden('after Home')
    assert 'Return to lock test' in shell('dumpsys', 'notification', '--noredact'), \
        'No ongoing-call entry after Home'
    # The ongoing entry is the first lock-screen card (Pixel_10); its
    # chronometer never lets uiautomator idle, so it is hit by position.
    wake()
    time.sleep(1)
    shell('input', 'tap', '538', '638')
    wait_for('CALL CONNECTED', 10)
    assert occluded(), 'Return did not come back over the keyguard'
    tap('END CALL')
    time.sleep(2)
    assert_locked_and_hidden('after hang-up')
    unlock()
    assert_app_visible('after unlocking')
    print('PASS  Home over the lock screen: keyguard back, return reopens the call, unlock draws')


def ear():
    answer_on_locked_phone()
    adb('emu', 'sensor', 'set', 'proximity', '0')
    time.sleep(1.5)
    # A cheek on the panel: every tap is dropped while the sensor says near.
    tap('END CALL')
    time.sleep(1)
    adb('emu', 'sensor', 'set', 'proximity', '5')
    time.sleep(1.5)
    wait_for('CALL CONNECTED', 5)
    tap('END CALL')
    time.sleep(2)
    assert_locked_and_hidden('after hang-up')
    unlock()
    assert_app_visible('after unlocking')
    print('PASS  at the ear: taps ignored while near, hang-up works after, unlock draws')


def small_screens():
    sizes = [('1080x2424', '480'), ('720x1280', '320'), ('1080x2424', '540'), ('480x854', '240')]
    try:
        for size, density in sizes:
            shell('wm', 'size', size)
            shell('wm', 'density', density)
            time.sleep(2)
            shell('input', 'keyevent', 'KEYCODE_WAKEUP')
            if keyguard_or_secure():
                unlock()
            shell('am', 'force-stop', PKG)
            shell('monkey', '-p', PKG, '-c', 'android.intent.category.LAUNCHER', '1')
            wait_for('RING IN FIVE SECONDS')
            tap('RING IN FIVE SECONDS')
            shell('input', 'keyevent', 'KEYCODE_SLEEP')
            wait_ringing()
            boxes, (width, height) = ring_buttons_when_drawn()
            a, d = boxes['accept'], boxes['decline']
            where = '%s@%s' % (size, density)
            for name, (x1, y1, x2, y2) in (('Accept', a), ('Decline', d)):
                assert 0 < x1 < x2 < width - 1 and 0 < y1 < y2 < height - 1, \
                    '%s touches the screen edge at %s: %s' % (name, where, (x1, y1, x2, y2))
                assert abs((x2 - x1) - (y2 - y1)) <= 12, \
                    '%s is cut, not round, at %s: %s' % (name, where, (x1, y1, x2, y2))
            assert abs((a[2] - a[0]) - (d[2] - d[0])) <= 12, 'Accept and Decline differ at ' + where
            assert d[2] < a[0], 'Decline overlaps Accept at ' + where
            dp = int(density) / 160
            assert (a[2] - a[0]) / dp >= 60, 'Accept under 64dp at ' + where
            png, _ = screenshot()
            name = '/tmp/ringing_%s_%s.png' % (size, density)
            open(name, 'wb').write(png)
            for _ in range(3):
                shell('input', 'tap', str((d[0] + d[2]) // 2), str((d[1] + d[3]) // 2))
                time.sleep(2)
                if not ringing_screen_up():
                    break
            assert not ringing_screen_up(), 'Decline did not close at ' + where
            print('PASS  ringing screen fits %s: Accept %dx%d px, both round, both on screen (%s)'
                  % (where, a[2] - a[0], a[3] - a[1], name))
    finally:
        shell('wm', 'size', 'reset')
        shell('wm', 'density', 'reset')


def app_instances():
    return len(re.findall(
        r'Hist\s+#\d+: ActivityRecord\{\S+ u0 %s/\.(?:Launcher|MainActivity) ' % PKG,
        activities(),
    ))


def heads_up_accept():
    """Screen on and unlocked, app in the background: Accept on the heads-up."""
    unlock()
    shell('am', 'force-stop', PKG)
    shell('monkey', '-p', PKG, '-c', 'android.intent.category.LAUNCHER', '1')
    wait_for('RING IN FIVE SECONDS')
    tap('RING IN FIVE SECONDS')
    shell('input', 'keyevent', 'KEYCODE_HOME')
    # The heads-up is Android's CallStyle: its green "Answer" pill carries
    # no text uiautomator can read, so it is found by colour in the top band.
    deadline = time.time() + 20
    while time.time() < deadline:
        _, img = screenshot()
        w, h = img.size
        band = img.crop((0, 0, w, h // 4)).resize((w // 4, h // 16))
        px = band.load()
        greens = [(x, y) for y in range(band.size[1]) for x in range(band.size[0])
                  if px[x, y][1] > 120 and px[x, y][0] < 80 and px[x, y][2] < 110]
        if len(greens) > 40:
            x = sum(p[0] for p in greens) * 4 // len(greens)
            y = sum(p[1] for p in greens) * 4 // len(greens)
            shell('input', 'tap', str(x), str(y))
            break
        time.sleep(1)
    else:
        raise AssertionError('No heads-up Answer')
    wait_for('CALL CONNECTED', 15)
    assert app_on_top(), 'Accept did not bring the app forward'
    assert app_instances() == 1, 'Accept started a second MainActivity'
    assert not ringing_screen_up(), 'A ringing screen is still up after Accept'
    tap('END CALL')
    time.sleep(2)
    assert_app_visible('after hang-up')
    print('PASS  heads-up Accept with the app in the background: one Accept, one app')


SCENARIOS = {
    'heads_up_accept': heads_up_accept,
    'hangup_unlock': hangup_unlock,
    'screen_off_end': screen_off_end,
    'home_return': home_return,
    'ear': ear,
    'small_screens': small_screens,
}

if __name__ == '__main__':
    chosen = sys.argv[1:] or list(SCENARIOS)
    set_pin()
    failed = []
    try:
        for name in chosen:
            try:
                SCENARIOS[name]()
            except AssertionError as error:
                failed.append(name)
                print('FAIL  %s: %s' % (name, error))
    finally:
        try:
            shell('am', 'force-stop', PKG)
            unlock()
        finally:
            clear_pin()
    sys.exit(1 if failed else 0)
