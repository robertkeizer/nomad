#!/usr/bin/env -S deno run --allow-net

// basic TCP "echo" server, from https://deno.land/manual@v1.26.1/examples/tcp_echo

import { copy } from 'https://deno.land/std/streams/copy.ts'
const listener = Deno.listen({ port: 32123 })

for await (const conn of listener) copy(conn, conn).finally(() => conn.close())
