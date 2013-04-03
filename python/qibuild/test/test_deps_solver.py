## Copyright (c) 2012, 2013 Aldebaran Robotics. All rights reserved.
## Use of this source code is governed by a BSD-style license that can be
## found in the COPYING file.
"""Testing DependenciesSolver class

"""



from qibuild.deps_solver import DepsSolver


def test_simple_deps(build_worktree):
    world = build_worktree.create_project("world")
    hello = build_worktree.create_project("hello", depends=["world"])

    deps_solver = DepsSolver(build_worktree)
    assert deps_solver.get_dep_projects([world], ["build"]) == [world]
    assert deps_solver.get_dep_projects([hello], ["build"]) == [world, hello]

def test_ignore_missing_deps(build_worktree):
    world = build_worktree.create_project("world")
    hello = build_worktree.create_project("hello", depends=["world", "foo"])

    deps_solver = DepsSolver(build_worktree)
    assert deps_solver.get_dep_projects([hello], ["build"]) == [world, hello]

def test_find_packages_in_toolchain(build_worktree, toolchains):
    foo_tc = toolchains.create("foo")
    world_package = toolchains.add_package("foo", "world")
    hello = build_worktree.create_project("hello", depends=["world"])
    build_worktree.set_active_config("foo")

    deps_solver = DepsSolver(build_worktree)
    assert deps_solver.get_dep_packages([hello], ["build"]) == [world_package]
