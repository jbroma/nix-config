#!/bin/bash
# Decrement volume by 1%
osascript -e 'set volume output volume ((output volume of (get volume settings)) - 1)'
