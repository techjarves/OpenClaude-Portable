#!/usr/bin/env bash
exec bash "$(cd "$(dirname "$0")" && pwd)/start.sh" resume "$@"
