# Copyright 2024 Canonical Ltd.
# See LICENSE file for licensing details.
#
#

import pytest
import random
import string
import subprocess
from charmed_kubeflow_chisme.rock import CheckRock


@pytest.mark.abort_on_fail
def test_rock(rock_test_env):
    """Test rock."""
    temp_dir, container_name = rock_test_env
    check_rock = CheckRock("rockcraft.yaml")
    rock_image = check_rock.get_name()
    rock_version = check_rock.get_version()
    LOCAL_ROCK_IMAGE = f"{rock_image}:{rock_version}"

    subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            LOCAL_ROCK_IMAGE,
            "exec",
            "ls",
            "-la",
            "/otelcol",
        ],
        check=True,
    )

    subprocess.run(
        [
            "docker",
            "run",
            "--rm",
            LOCAL_ROCK_IMAGE,
            "exec",
            "ls",
            "-la",
            "/config.yaml",
        ],
        check=True,
    )
