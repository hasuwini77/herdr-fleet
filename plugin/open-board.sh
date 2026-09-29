#!/usr/bin/env bash
# Opens the board popup from the action menu.
exec "${HERDR_BIN_PATH:-herdr}" plugin pane open --plugin "${HERDR_PLUGIN_ID:-hasuwini77.fleet}" --entrypoint board
