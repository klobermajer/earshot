import argparse
import signal

import gi

gi.require_version('Gio', '2.0')
gi.require_version('GLibUnix', '2.0')
from gi.repository import Gio, GLib, GLibUnix

NOTIFICATIONS = ('org.freedesktop.Notifications', '/org/freedesktop/Notifications', 'org.freedesktop.Notifications')
DISMISSED_BY_USER = 2

parser = argparse.ArgumentParser()
for option in ('--icon', '--title', '--message', '--group', '--actions', '--dropdown-label'):
    parser.add_argument(option, default='')
parser.add_argument('--timeout', type=int, default=120)
arguments = parser.parse_args()

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
loop = GLib.MainLoop()
result = {'id': None, 'choice': None}


def call(method, params, reply_type=None):
    return bus.call_sync(*NOTIFICATIONS, method, params, reply_type and GLib.VariantType(reply_type),
                         Gio.DBusCallFlags.NONE, -1, None)


def finish(choice):
    if result['choice'] is None:
        result['choice'] = choice
        loop.quit()


def close(choice):
    call('CloseNotification', GLib.Variant('(u)', (result['id'],)))
    finish(choice)


def on_signal(connection, sender, path, interface, name, params):
    if params[0] != result['id']:
        return
    if name == 'ActionInvoked':
        finish(params[1])
    else:
        finish('@CLOSED' if params[1] == DISMISSED_BY_USER else '@TIMEOUT')


for name in ('ActionInvoked', 'NotificationClosed'):
    bus.signal_subscribe(None, NOTIFICATIONS[2], name, NOTIFICATIONS[1], None, Gio.DBusSignalFlags.NONE, on_signal)

actions = [part for action in arguments.actions.split(',') if action for part in (action, action)]
body = GLib.markup_escape_text(arguments.message)
result['id'] = call('Notify', GLib.Variant('(susssasa{sv}i)', ('Earshot', 0, arguments.icon, arguments.title, body, actions, {}, -1)), '(u)')[0]
GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, close, None)
GLib.timeout_add_seconds(arguments.timeout, close, '@TIMEOUT')
loop.run()
if result['choice']:
    print(result['choice'])
