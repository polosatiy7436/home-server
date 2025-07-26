#!/bin/sh
pg_isready -U "$(cat /run/secrets/MEALIE_POSTGRES_USER)"
