import QtQuick
import Quickshell.Io

Item {
  id: root
  required property list<string> command
  signal lineReceived(string line)
  signal disconnected()

  Process {
    id: process
    command: root.command
    running: true
    stdout: SplitParser {
      onRead: function(line) { root.lineReceived(line) }
    }
    onRunningChanged: {
      if (!running) {
        root.disconnected()
        retry.restart()
      }
    }
  }

  Timer {
    id: retry
    interval: 2000
    onTriggered: process.running = true
  }
}
