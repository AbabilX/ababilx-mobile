"""Emulator-only check of a call answered on a secure-locked phone.

Drives tool/audit/locked_call_harness.dart on an emulator whose temporary test
PIN is 2468. Never point this at a real phone.

  flutter build apk --debug -t tool/audit/locked_call_harness.dart
  adb install -r build/app/outputs/flutter-apk/app-debug.apk
  python3 tool/audit/locked_call_check.py            answer, minimise, return, hang up
  python3 tool/audit/locked_call_check.py --decline  decline
"""
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

ADB = '/Users/murad/Library/Android/sdk/platform-tools/adb'
PKG = 'com.ababilx.app'


def shell(*args):
    return subprocess.check_output([ADB, '-e', 'shell', *args], text=True)


def nodes():
    # A dump that fails leaves the previous file behind; never read that.
    shell('rm', '-f', '/sdcard/lock-test.xml')
    shell('uiautomator', 'dump', '/sdcard/lock-test.xml')
    try:
        return list(ET.fromstring(shell('cat', '/sdcard/lock-test.xml')).iter('node'))
    except (subprocess.CalledProcessError, ET.ParseError):
        return []


def screen_text():
    for _ in range(5):
        # The lock screen sleeps within seconds and uiautomator cannot read a
        # sleeping display. Waking it does not unlock anything.
        shell('input', 'keyevent', 'KEYCODE_WAKEUP')
        found = nodes()
        if found:
            return ' '.join(n.get('text', '') + ' ' + n.get('content-desc', '') for n in found)
        time.sleep(1.5)
    raise AssertionError('uiautomator could not read the screen')


def activities():
    return shell('dumpsys', 'activity', 'activities')


def ringing_screen_up():
    return 'CallkitIncomingActivity' in activities()


def app_on_top():
    top = re.search(r'topResumedActivity=ActivityRecord\{\S+ u0 (\S+)', activities())
    return bool(top) and top.group(1) in (PKG + '/.Launcher', PKG + '/.MainActivity')


def tap(label):
    for n in nodes():
        if label in n.get('text', '') + n.get('content-desc', ''):
            x1, y1, x2, y2 = map(int, re.findall(r'\d+', n.get('bounds')))
            shell('input', 'tap', str((x1 + x2) // 2), str((y1 + y2) // 2))
            return
    raise AssertionError('Not on screen: ' + label)


def occluded():
    return 'mKeyguardOccluded=true' in shell('dumpsys', 'window', 'policy')


def wait_for(label, seconds=30):
    text = ''
    deadline = time.time() + seconds
    while time.time() < deadline:
        text = screen_text()
        if label in text:
            return
        time.sleep(1)
    raise AssertionError('Never showed %r; screen: %s' % (label, text))


def app_instances():
    out = activities()
    return len(re.findall(r'Hist\s+#\d+: ActivityRecord\{\S+ u0 %s/\.(?:Launcher|MainActivity) ' % PKG, out))


def private_hidden(when):
    assert 'PRIVATE CHAT CONTENT' not in screen_text(), 'App content exposed ' + when


def launch_then_lock_and_ring(button_x):
    shell('input', 'keyevent', 'KEYCODE_WAKEUP')
    shell('wm', 'dismiss-keyguard')
    time.sleep(1)
    shell('input', 'text', '2468')
    shell('input', 'keyevent', '66')
    time.sleep(1)
    shell('am', 'force-stop', PKG)
    shell('pm', 'grant', PKG, 'android.permission.RECORD_AUDIO')
    shell('monkey', '-p', PKG, '-c', 'android.intent.category.LAUNCHER', '1')
    wait_for('RING IN FIVE SECONDS')
    tap('RING IN FIVE SECONDS')
    shell('input', 'keyevent', 'KEYCODE_SLEEP')
    wait_for('Accept', 20)
    # Past the ringing screen's enter animation, or the first tap is lost.
    time.sleep(1.5)
    # Its buttons are hit by position (Pixel_10: Decline 197, Answer 884),
    # and pressed again until the screen is really gone.
    for _ in range(3):
        shell('input', 'tap', button_x, '1975')
        time.sleep(2)
        if not ringing_screen_up():
            return
    raise AssertionError('The ringing screen ignored the tap')


if '--decline' in sys.argv:
    launch_then_lock_and_ring('197')
    time.sleep(2)
    assert 'Lock test' not in screen_text(), 'Decline left the ringing screen up'
    private_hidden('after Decline')
    assert not occluded(), 'Decline left the app over the keyguard'
    print('PASS  Decline: back to the lock screen, nothing exposed')
    sys.exit(0)

launch_then_lock_and_ring('884')
private_hidden('during the Accept handoff')
wait_for('CALL CONNECTED')
assert app_on_top(), 'The call screen is not the top activity'
policy = shell('dumpsys', 'window', 'policy')
assert 'mKeyguardOccluded=true' in policy and 'secure=true' in policy, 'Not over a secure keyguard'
assert app_instances() == 1, 'Accept started a second MainActivity'
print('PASS  Answer: call over the secure keyguard, one MainActivity')

tap('MINIMIZE')
time.sleep(2)
shell('input', 'keyevent', 'KEYCODE_WAKEUP')
time.sleep(1)
# uiautomator never idles on this lock screen — the ongoing entry's
# chronometer ticks every second — so this step reads window state instead.
assert not occluded(), 'Minimising left the app over the keyguard'
assert not app_on_top(), 'The app is still on top of the lock screen'
assert 'Return to lock test' in shell('dumpsys', 'notification', '--noredact'), 'No ongoing-call entry'
print('PASS  Minimise: keyguard back, nothing exposed, ongoing entry on the lock screen')

# Straight off the lock screen, no unlock: the entry is the first card (Pixel_10).
shell('input', 'tap', '538', '638')
wait_for('CALL CONNECTED', 10)
assert app_on_top(), 'The call screen is not the top activity after the return tap'
assert occluded(), 'Return tap unlocked the phone instead of covering the keyguard'
assert 'PIN' not in screen_text(), 'Return tap asked for the PIN'
print('PASS  Return: lock-screen notification reopens the call, no PIN')

tap('END CALL')
time.sleep(2)
private_hidden('after hang-up')
assert not occluded(), 'Hang-up left the app over the keyguard'
print('PASS  Hang up: keyguard back, nothing exposed')
