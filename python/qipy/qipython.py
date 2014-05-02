#!/usr/bin/python

import argparse
import os
import sys

import qisys.command
import qibuild.parsers
import qipy.parsers


def main():
    parser = argparse.ArgumentParser()
    qisys.parsers.worktree_parser(parser)
    parser.add_argument("-c", "--config")
    parser.set_defaults(config="system")
    parser.add_argument("py_args", nargs="+")
    args = parser.parse_args()
    config = args.config
    py_args = args.py_args
    python_worktree = qipy.parsers.get_python_worktree(args)
    venv_path = python_worktree.venv_path
    if not os.path.exists(venv_path):
        sys.exit("Virtualenv for %s not found" % config)
    if py_args == ["activate"]:
        activate = python_worktree.bin_path("activate")
        print activate
        sys.exit(0)

    python_exe = python_worktree.python
    cmd = [python_exe] + py_args
    qisys.command.call(cmd)

if __name__ == "__main__":
    main()