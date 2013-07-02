## Copyright (c) 2012, 2013 Aldebaran Robotics. All rights reserved.
## Use of this source code is governed by a BSD-style license that can be
## found in the COPYING file.

""" Synchronize the given worktree with its manifests

 * Clone any missing project
 * Configure projects for code review

"""

import sys

from qisys import ui
import qisys.parsers
import qisrc.git
import qisrc.sync
import qisrc.parsers
import qibuild.parsers


def configure_parser(parser):
    """Configure parser for this action """
    qisys.parsers.worktree_parser(parser)
    qisys.parsers.project_parser(parser)
    qisrc.parsers.groups_parser(parser)

    group = parser.add_argument_group("qisrc sync options")
    group.add_argument("--rebase-devel", action="store_true",
                       help="Rebase development branches. Advanced users only")

def print_overview(total, skipped, failed):
    out = [ ui.green, "Success:", ui.white, total - skipped - failed ]
    if skipped:
        out.append(ui.yellow)
    else:
        out.append(ui.blue)
    out.extend(("Skipped:", ui.white, skipped))
    if failed:
        out.append(ui.red)
    else:
        out.append(ui.blue)
    out.extend(("Failed:", ui.white, failed))
    ui.info(*out)

@ui.timer("Synchronizing worktree")
def do(args):
    """Main entry point"""
    git_worktree = qisrc.parsers.get_git_worktree(args)
    sync_ok = git_worktree.sync()
    git_projects = qisrc.parsers.get_git_projects(git_worktree, args,
                                                  default_all=True,
                                                  use_build_deps=True)

    skipped = list()
    failed = list()
    ui.info(ui.green, ":: Syncing projects ...")
    max_src = max(len(x.src) for x in git_projects)
    for (i, git_project) in enumerate(git_projects):
        ui.info_count(i, len(git_projects),
                      ui.blue, git_project.src.ljust(max_src), end="\r")

        (status, out) = git_project.sync(rebase_devel=args.rebase_devel)
        if status is None:
            ui.info("\n", ui.brown, "  [skipped]")
            skipped.append((git_project.src, out))
        if status is False:
            ui.info("\n", ui.red, "  [failed]")
            failed.append((git_project.src, out))
        if out:
            print ui.indent(out, num=2)
    #clean the screen
    ui.info_count(i, len(git_projects), ui.blue, " ".ljust(max_src), end="\r")
    print_overview(len(git_projects), len(skipped), len(failed))
    if failed or not sync_ok:
        sys.exit(1)
