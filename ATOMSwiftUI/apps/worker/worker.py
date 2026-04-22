from __future__ import annotations

import time


def run_worker_loop() -> None:
    # Scaffold: replace with Celery/RQ/Arq in production rollout.
    while True:
        time.sleep(1)


if __name__ == "__main__":
    run_worker_loop()

