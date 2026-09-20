package main

import "core:os"

main :: proc() {
    os.exit(run_cli(os.args[1:]))
}
